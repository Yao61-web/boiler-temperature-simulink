function run_cloud_validation
% Build and run actual Simulink models; compare solver step bounds.
here = fileparts(mfilename('fullpath'));
cd(here);
dest=fullfile(here,'validation'); mkdir(dest);
diary(fullfile(dest,'cloud_validation_log.txt'));
fprintf('MATLAB release %s\n',version('-release'));
fprintf('Commit %s\n',getenv('GITHUB_SHA'));
fprintf('Workflow run %s\n',getenv('GITHUB_RUN_ID'));
disp(ver('Simulink'));
diary off;
build_models;
coarse=run_simulink_tests(0.02);
fine=run_simulink_tests(0.01);
A=readtable(fullfile(coarse,'metrics.csv'));
B=readtable(fullfile(fine,'metrics.csv'));
assert(isequal(A.model,B.model) && isequal(A.test,B.test));
numeric=4:width(A);
da=table2array(A(:,numeric)); db=table2array(B(:,numeric));
assert(isequal(isnan(da),isnan(db)),'Metric applicability changed.');
delta=abs(da-db);
D=A(:,1:3);
for i=1:numel(numeric)
    D.(['delta_' A.Properties.VariableNames{numeric(i)}])=delta(:,i);
end
writetable(D,fullfile(dest,'precision_metrics.csv'));
models={'boiler_single','boiler_cascade'};
tests={'tracking','load','fuel','combined','robustness'};
rows={};
for j=1:2
    mdl=models{j};
    load_system(fullfile(here,'generated_slx',[mdl '.slx']));
    set_param(mdl,'SimulationCommand','update');
    % Save MDL with the official serializer as a secondary source format.
    save_system(mdl,fullfile(here,'generated_slx',[mdl '.mdl']));
    close_system(mdl,0);
    load_system(fullfile(here,'generated_slx',[mdl '.mdl']));
    set_param(mdl,'SimulationCommand','update');
    close_system(mdl,0);
    for k=1:5
        name=[mdl '_' tests{k} '.csv'];
        x=readtable(fullfile(coarse,name));
        y=readtable(fullfile(fine,name));
        yi=interp1(y.time_s,y.y,x.time_s,'linear');
        err=max(abs(x.y-yi));
        rows(end+1,:)={mdl,tests{k},err}; %#ok<AGROW>
        assert(err<1e-3,'Output precision difference is too large.');
    end
end
writetable(cell2table(rows,'VariableNames',{'model','test','max_abs_y_difference'}), ...
    fullfile(dest,'precision_curves.csv'));
assert(all(abs(A.target_pass-B.target_pass)<eps | isnan(A.target_pass)), ...
    'Acceptance outcomes changed when halving maximum step.');
% Validate the inner loop independently with a unit flow-reference step.
mdl='fuel_inner_validation'; new_system(mdl);
add_block('simulink/Sources/Step',[mdl '/Reference'],'Time','1','After','1');
add_block('simulink/Math Operations/Sum',[mdl '/Error'],'Inputs','+-');
add_block('simulink/Continuous/Transfer Fcn',[mdl '/PI'], ...
    'Numerator','[1.3333333333333333 0.6666666666666666]','Denominator','[1 0]');
add_block('simulink/Continuous/Transfer Fcn',[mdl '/Fuel'], ...
    'Numerator','[3]','Denominator','[2 1]');
add_block('simulink/Sinks/To Workspace',[mdl '/Record'], ...
    'VariableName','innerdata','SaveFormat','Structure With Time','MaxDataPoints','inf');
add_line(mdl,'Reference/1','Error/1'); add_line(mdl,'Error/1','PI/1');
add_line(mdl,'PI/1','Fuel/1'); add_line(mdl,'Fuel/1','Error/2');
add_line(mdl,'Fuel/1','Record/1');
set_param(mdl,'StopTime','8','Solver','ode45','MaxStep','0.01', ...
    'RelTol','1e-6','AbsTol','1e-8','ReturnWorkspaceOutputs','on');
out=sim(mdl); data=out.innerdata;
t=data.time(:); q=data.signals.values;
expected=zeros(size(t)); ii=t>=1; expected(ii)=1-exp(-(t(ii)-1)/0.5);
inner_error=max(abs(q-expected));
assert(inner_error<1e-4,'Inner loop differs from analytic first-order prediction.');
writetable(table(t,q,expected),'validation/inner_loop.csv');
save_system(mdl,fullfile(dest,[mdl '.slx'])); close_system(mdl,0);
f=fopen(fullfile(dest,'validation_summary.txt'),'w');
fprintf(f,'MATLAB %s\n',version);
fprintf(f,'Commit: %s\nRun: %s\n',getenv('GITHUB_SHA'),getenv('GITHUB_RUN_ID'));
fprintf(f,'Coarse data: %s\nFine data: %s\n',coarse,fine);
fprintf(f,'14 runs at each step bound, 28 closed-loop simulations total.\n');
fprintf(f,'SLX and official MDL load/update checks passed.\n');
fprintf(f,'All 10 output curve comparisons differ by less than 0.001.\n');
fprintf(f,'Inner-loop Simulink vs analytic maximum difference: %.17g\n',inner_error);
fprintf(f,'Inner-loop validation adds one actual Simulink simulation.\n');
fclose(f);
end
