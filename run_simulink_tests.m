function result_dir = run_simulink_tests
% All dynamics run in Simulink via sim; this file only configures and exports.
% Requires MATLAB + Simulink. No Control System Toolbox is required.
here = fileparts(mfilename('fullpath'));
assert(license('test','Simulink') == 1, 'A valid Simulink license is required.');
result_dir = fullfile(here,['results_' datestr(now,'yyyymmdd_HHMMSS')]);
assert(~exist(result_dir,'dir'),'Result directory already exists. Retry later.');
mkdir(result_dir);
diary(fullfile(result_dir,'execution_log.txt'));
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Run time: %s\n', datestr(now,31));
disp(ver('MATLAB')); disp(ver('Simulink'));
models = {'boiler_single','boiler_cascade'};
case_names = {'tracking','load','fuel','combined','robustness'};
% Columns: r amplitude/time, load amplitude/time, fuel amplitude/time,
%          temperature time constant, pure delay.
cases = [1 10 0 60 0 110 10 3; ...
         0 10 .2 60 0 110 10 3; ...
         0 10 0 60 .2 60 10 3; ...
         1 10 .2 60 .2 110 10 3; ...
         1 10 .2 60 .2 110 12 3.6];
rows = {}; raw = cell(2,5); paths = cell(1,2);
for j = 1:2
    mdl = models{j};
    assert(~bdIsLoaded(mdl),'Close %s before running; unsaved work is protected.',mdl);
    path_slx = fullfile(here,'generated_slx',[mdl '.slx']);
    if exist(path_slx,'file'), source=path_slx; else, source=fullfile(here,[mdl '.mdl']); end
    paths{j}=source;
    fprintf('Model source: %s\n',source);
    load_system(source);
    close_guard = onCleanup(@() close_system(mdl,0));
    set_param(mdl,'SimulationCommand','update');
    try
        print(['-s' mdl],'-dpng','-r180',fullfile(result_dir,[mdl '_diagram.png']));
    catch err
        warning('Diagram export failed: %s',err.message);
    end
    for k = 1:5
        out = sim(configure(mdl,cases(k,:),1));
        data = out.simdata;
        [t,x] = unpack(data);
        assert(t(1)==0 && t(end)>=199.99 && all(diff(t)>0),'Incomplete time history.');
        assert(all(isfinite(x(:))),'Simulation has nonfinite values.');
        assert(max(abs(x(:,2)))<10,'Response exceeds the normalized safety envelope.');
        raw{j,k} = data;
        tab = array2table([t x],'VariableNames', ...
            {'time_s','r','y','e','u','q','qsp','dload','dfuel'});
        stem = [mdl '_' case_names{k}];
        writetable(tab,fullfile(result_dir,[stem '.csv']));
        save(fullfile(result_dir,[stem '.mat']),'data');
        m = metrics(t,x,k);
        rows(end+1,:) = [{mdl,case_names{k},1},num2cell(m)]; %#ok<AGROW>
    end
    % Tune only against Simulink responses; compare 0.75, 1, 1.25 times PI.
    for factor = [.75 1.25]
        out = sim(configure(mdl,cases(1,:),factor));
        data=out.simdata; [t,x] = unpack(data);
        assert(all(isfinite(x(:))),'Nonfinite values in tuning run.');
        m = metrics(t,x,1);
        rows(end+1,:) = [{mdl,'tracking_tuning',factor},num2cell(m)]; %#ok<AGROW>
        stem=sprintf('%s_tuning_%.2f',mdl,factor);
        save(fullfile(result_dir,[stem '.mat']),'data');
        writetable(array2table([t x],'VariableNames', ...
            {'time_s','r','y','e','u','q','qsp','dload','dfuel'}),fullfile(result_dir,[stem '.csv']));
    end
    clear close_guard;
end
summary = cell2table(rows,'VariableNames',{'model','test','PI_scale', ...
    'overshoot_pct','rise_time_s','settling_time_s','peak_deviation', ...
    'recovery_time_s','steady_error','IAE','peak_u','total_variation_u','target_pass'});
writetable(summary,fullfile(result_dir,'metrics.csv')); disp(summary);
for k=1:5
    f=figure('Visible','off','Color','w','Position',[50 50 1100 700]);
    for p=1:3
        subplot(3,1,p); hold on;
        for j=1:2
            [t,x]=unpack(raw{j,k});
            col=[2 5 4]; plot(t,x(:,col(p)),'LineWidth',1.3);
        end
        if p==1
            [t,x]=unpack(raw{1,k}); plot(t,x(:,1),'k--');
            legend('Single loop','Cascade','Reference','Location','best'); ylabel('Temperature deviation');
        elseif p==2, ylabel('Fuel flow deviation');
        else, ylabel('Actuator deviation'); xlabel('Time (s)'); end
        title(case_names{k},'Interpreter','none'); grid on;
    end
    print(f,fullfile(result_dir,[case_names{k} '_comparison.png']),'-dpng','-r180'); close(f);
end
f=fopen(fullfile(result_dir,'validation_status.txt'),'w');
fprintf(f,'Simulink simulation and data export completed.\n');
fprintf(f,'This does not certify physical boiler safety or real equipment performance.\n');
fprintf(f,'Check metrics.csv target_pass and all response plots before accepting PI settings.\n');
fprintf(f,'NaN means not applicable or not settled within the observation window.\n');
fclose(f);
fprintf('Results saved to: %s\n', result_dir);
end

function in = configure(mdl,c,factor)
in = Simulink.SimulationInput(mdl);
in = in.setModelParameter('StopTime','200','Solver','ode45','SolverType','Variable-step', ...
    'RelTol','1e-6','AbsTol','1e-8','MaxStep','0.02','ReturnWorkspaceOutputs','on');
names={'Reference','LoadDisturbance','FuelDisturbance'};
for n=1:3
    in=in.setBlockParameter([mdl '/' names{n}], ...
        'Before','0','After',num2str(c(2*n-1),17),'Time',num2str(c(2*n),17));
end
in=in.setBlockParameter([mdl '/TemperatureDynamics'],'Denominator',sprintf('[%.17g 1]',c(7)));
in=in.setBlockParameter([mdl '/PureDelay'],'DelayTime',num2str(c(8),17));
if strcmp(mdl,'boiler_single'), pi=[.35 .035]; else, pi=[1.05 .105]; end
in=in.setBlockParameter([mdl '/TemperaturePI'],'Numerator',mat2str(pi*factor,17));
end

function [t,x]=unpack(data)
t=data.time(:); x=data.signals.values;
% Retain the last logged value at duplicate solver event times.
[~,ii]=unique(t,'last'); ii=sort(ii); t=t(ii); x=x(ii,:);
assert(size(x,1)==numel(t) && size(x,2)==8,'Unexpected Mux/To Workspace signal dimensions.');
end

function m=metrics(t,x,k)
mp=NaN; tr=NaN; ts=NaN; recovery=NaN; pass=NaN;
if k==1, event=10; else, event=60; end
idx=t>=event; tt=t(idx); yy=x(idx,2); err=x(idx,3);
peak=max(abs(yy));
ss=mean(err(tt>=max(tt(end)-10,event)));
iae=trapz(tt,abs(err));
if k==1
    mp=max(0,(max(yy)-1)*100);
    a=find(yy>=.1,1); b=find(yy>=.9,1);
    if ~isempty(a) && ~isempty(b), tr=tt(b)-tt(a); end
    ts=settle(tt,yy-1,.02,event);
    pass=double(mp<=10 && isfinite(ts) && ts<=80 && abs(ss)<=.01);
elseif k==2 || k==3
    % Threshold is 2% of the corresponding open-loop static deviation.
    if k==2, band=.02*(1.5*.2); else, band=.02*(3*.2); end
    recovery=settle(tt,yy,band,event);
    pass=double(isfinite(recovery) && recovery<=80 && abs(ss)<=band);
end
m=[mp tr ts peak recovery ss iae max(abs(x(:,4))) sum(abs(diff(x(:,4)))) pass];
end

function dt=settle(t,e,band,event)
last=find(abs(e)>band,1,'last');
if isempty(last), dt=0;
elseif last==numel(t), dt=NaN;
else, dt=t(last+1)-event;
end
end
