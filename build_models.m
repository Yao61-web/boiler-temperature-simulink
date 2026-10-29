function build_models
% Create SLX block diagrams. No MATLAB plant simulation is performed.
% Existing source MDL files are never overwritten.
here = fileparts(mfilename('fullpath'));
dest = fullfile(here, 'generated_slx');
if ~exist(dest, 'dir'), mkdir(dest); end
load_system('simulink');
mdl = 'boiler_single';
if bdIsLoaded(mdl), error('Close the model before building: %s', mdl); end
new_system(mdl);
set_param(mdl, 'StartTime','0','StopTime','200','SolverType','Variable-step', ...
    'Solver','ode45','RelTol','1e-6','AbsTol','1e-8','MaxStep','0.02', ...
    'ReturnWorkspaceOutputs','on','SaveTime','on','TimeSaveName','tout','SaveOutput','off');
add_block('simulink/Sources/Step', [mdl '/Reference'], 'Position', [30 100 70 130], 'Time', '10', 'Before', '0', 'After', '1', 'SampleTime', '0');
add_block('simulink/Math Operations/Sum', [mdl '/TemperatureError'], 'Position', [115 98 140 133], 'Inputs', '+-', 'IconShape', 'round');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/TemperaturePI'], 'Position', [180 95 290 140], 'Numerator', '[0.35 0.035]', 'Denominator', '[1 0]');
add_block('simulink/Sources/Step', [mdl '/FuelDisturbance'], 'Position', [475 220 515 250], 'Time', '110', 'Before', '0', 'After', '0.2', 'SampleTime', '0');
add_block('simulink/Math Operations/Sum', [mdl '/FuelInput'], 'Position', [565 98 590 133], 'Inputs', '++', 'IconShape', 'round');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/FuelDynamics'], 'Position', [630 95 740 140], 'Numerator', '[3]', 'Denominator', '[2 1]');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/TemperatureDynamics'], 'Position', [800 95 910 140], 'Numerator', '[1]', 'Denominator', '[10 1]');
add_block('simulink/Continuous/Transport Delay', [mdl '/PureDelay'], 'Position', [960 95 1040 140], 'DelayTime', '3', 'InitialOutput', '0');
add_block('simulink/Sources/Step', [mdl '/LoadDisturbance'], 'Position', [805 220 845 250], 'Time', '60', 'Before', '0', 'After', '0.2', 'SampleTime', '0');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/LoadDynamics'], 'Position', [895 215 1005 260], 'Numerator', '[1.5]', 'Denominator', '[5 1]');
add_block('simulink/Math Operations/Sum', [mdl '/TemperatureOutput'], 'Position', [1110 98 1135 133], 'Inputs', '++', 'IconShape', 'round');
add_block('simulink/Sources/Constant', [mdl '/NoFlowReference'], 'Position', [330 215 400 245], 'Value', '0');
add_block('simulink/Signal Routing/Mux', [mdl '/RecordedSignals'], 'Position', [1190 320 1195 560], 'Inputs', '8');
add_block('simulink/Sinks/Scope', [mdl '/Scope'], 'Position', [1270 350 1320 390]);
add_block('simulink/Sinks/To Workspace', [mdl '/Record'], 'Position', [1240 480 1350 520], 'VariableName', 'simdata', 'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf', 'Decimation', '1', 'SampleTime', '-1');
add_line(mdl, 'Reference/1', 'TemperatureError/1', 'autorouting','on');
add_line(mdl, 'TemperatureError/1', 'TemperaturePI/1', 'autorouting','on');
add_line(mdl, 'TemperaturePI/1', 'FuelInput/1', 'autorouting','on');
add_line(mdl, 'FuelDisturbance/1', 'FuelInput/2', 'autorouting','on');
add_line(mdl, 'FuelInput/1', 'FuelDynamics/1', 'autorouting','on');
add_line(mdl, 'FuelDynamics/1', 'TemperatureDynamics/1', 'autorouting','on');
add_line(mdl, 'TemperatureDynamics/1', 'PureDelay/1', 'autorouting','on');
add_line(mdl, 'PureDelay/1', 'TemperatureOutput/1', 'autorouting','on');
add_line(mdl, 'LoadDisturbance/1', 'LoadDynamics/1', 'autorouting','on');
add_line(mdl, 'LoadDynamics/1', 'TemperatureOutput/2', 'autorouting','on');
add_line(mdl, 'TemperatureOutput/1', 'TemperatureError/2', 'autorouting','on');
add_line(mdl, 'Reference/1', 'RecordedSignals/1', 'autorouting','on');
add_line(mdl, 'TemperatureOutput/1', 'RecordedSignals/2', 'autorouting','on');
add_line(mdl, 'TemperatureError/1', 'RecordedSignals/3', 'autorouting','on');
add_line(mdl, 'TemperaturePI/1', 'RecordedSignals/4', 'autorouting','on');
add_line(mdl, 'FuelDynamics/1', 'RecordedSignals/5', 'autorouting','on');
add_line(mdl, 'NoFlowReference/1', 'RecordedSignals/6', 'autorouting','on');
add_line(mdl, 'LoadDisturbance/1', 'RecordedSignals/7', 'autorouting','on');
add_line(mdl, 'FuelDisturbance/1', 'RecordedSignals/8', 'autorouting','on');
add_line(mdl, 'RecordedSignals/1', 'Scope/1', 'autorouting','on');
add_line(mdl, 'RecordedSignals/1', 'Record/1', 'autorouting','on');
set_param(mdl,'SimulationCommand','update');
target = fullfile(dest,[mdl '.slx']);
if exist(target,'file'), error('Will not overwrite %s; move it first.',target); end
save_system(mdl,target);
close_system(mdl,0);
mdl = 'boiler_cascade';
if bdIsLoaded(mdl), error('Close the model before building: %s', mdl); end
new_system(mdl);
set_param(mdl, 'StartTime','0','StopTime','200','SolverType','Variable-step', ...
    'Solver','ode45','RelTol','1e-6','AbsTol','1e-8','MaxStep','0.02', ...
    'ReturnWorkspaceOutputs','on','SaveTime','on','TimeSaveName','tout','SaveOutput','off');
add_block('simulink/Sources/Step', [mdl '/Reference'], 'Position', [30 100 70 130], 'Time', '10', 'Before', '0', 'After', '1', 'SampleTime', '0');
add_block('simulink/Math Operations/Sum', [mdl '/TemperatureError'], 'Position', [115 98 140 133], 'Inputs', '+-', 'IconShape', 'round');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/TemperaturePI'], 'Position', [180 95 290 140], 'Numerator', '[1.05 0.105]', 'Denominator', '[1 0]');
add_block('simulink/Math Operations/Sum', [mdl '/FlowError'], 'Position', [340 98 365 133], 'Inputs', '+-', 'IconShape', 'round');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/FlowPI'], 'Position', [405 95 515 140], 'Numerator', '[1.3333333333333333 0.6666666666666666]', 'Denominator', '[1 0]');
add_block('simulink/Sources/Step', [mdl '/FuelDisturbance'], 'Position', [475 220 515 250], 'Time', '110', 'Before', '0', 'After', '0.2', 'SampleTime', '0');
add_block('simulink/Math Operations/Sum', [mdl '/FuelInput'], 'Position', [565 98 590 133], 'Inputs', '++', 'IconShape', 'round');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/FuelDynamics'], 'Position', [630 95 740 140], 'Numerator', '[3]', 'Denominator', '[2 1]');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/TemperatureDynamics'], 'Position', [800 95 910 140], 'Numerator', '[1]', 'Denominator', '[10 1]');
add_block('simulink/Continuous/Transport Delay', [mdl '/PureDelay'], 'Position', [960 95 1040 140], 'DelayTime', '3', 'InitialOutput', '0');
add_block('simulink/Sources/Step', [mdl '/LoadDisturbance'], 'Position', [805 220 845 250], 'Time', '60', 'Before', '0', 'After', '0.2', 'SampleTime', '0');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/LoadDynamics'], 'Position', [895 215 1005 260], 'Numerator', '[1.5]', 'Denominator', '[5 1]');
add_block('simulink/Math Operations/Sum', [mdl '/TemperatureOutput'], 'Position', [1110 98 1135 133], 'Inputs', '++', 'IconShape', 'round');
add_block('simulink/Signal Routing/Mux', [mdl '/RecordedSignals'], 'Position', [1190 320 1195 560], 'Inputs', '8');
add_block('simulink/Sinks/Scope', [mdl '/Scope'], 'Position', [1270 350 1320 390]);
add_block('simulink/Sinks/To Workspace', [mdl '/Record'], 'Position', [1240 480 1350 520], 'VariableName', 'simdata', 'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf', 'Decimation', '1', 'SampleTime', '-1');
add_line(mdl, 'Reference/1', 'TemperatureError/1', 'autorouting','on');
add_line(mdl, 'TemperatureError/1', 'TemperaturePI/1', 'autorouting','on');
add_line(mdl, 'TemperaturePI/1', 'FlowError/1', 'autorouting','on');
add_line(mdl, 'FlowError/1', 'FlowPI/1', 'autorouting','on');
add_line(mdl, 'FlowPI/1', 'FuelInput/1', 'autorouting','on');
add_line(mdl, 'FuelDisturbance/1', 'FuelInput/2', 'autorouting','on');
add_line(mdl, 'FuelInput/1', 'FuelDynamics/1', 'autorouting','on');
add_line(mdl, 'FuelDynamics/1', 'TemperatureDynamics/1', 'autorouting','on');
add_line(mdl, 'TemperatureDynamics/1', 'PureDelay/1', 'autorouting','on');
add_line(mdl, 'PureDelay/1', 'TemperatureOutput/1', 'autorouting','on');
add_line(mdl, 'LoadDisturbance/1', 'LoadDynamics/1', 'autorouting','on');
add_line(mdl, 'LoadDynamics/1', 'TemperatureOutput/2', 'autorouting','on');
add_line(mdl, 'TemperatureOutput/1', 'TemperatureError/2', 'autorouting','on');
add_line(mdl, 'FuelDynamics/1', 'FlowError/2', 'autorouting','on');
add_line(mdl, 'Reference/1', 'RecordedSignals/1', 'autorouting','on');
add_line(mdl, 'TemperatureOutput/1', 'RecordedSignals/2', 'autorouting','on');
add_line(mdl, 'TemperatureError/1', 'RecordedSignals/3', 'autorouting','on');
add_line(mdl, 'FlowPI/1', 'RecordedSignals/4', 'autorouting','on');
add_line(mdl, 'FuelDynamics/1', 'RecordedSignals/5', 'autorouting','on');
add_line(mdl, 'TemperaturePI/1', 'RecordedSignals/6', 'autorouting','on');
add_line(mdl, 'LoadDisturbance/1', 'RecordedSignals/7', 'autorouting','on');
add_line(mdl, 'FuelDisturbance/1', 'RecordedSignals/8', 'autorouting','on');
add_line(mdl, 'RecordedSignals/1', 'Scope/1', 'autorouting','on');
add_line(mdl, 'RecordedSignals/1', 'Record/1', 'autorouting','on');
set_param(mdl,'SimulationCommand','update');
target = fullfile(dest,[mdl '.slx']);
if exist(target,'file'), error('Will not overwrite %s; move it first.',target); end
save_system(mdl,target);
close_system(mdl,0);
disp('SLX models created and compiled in generated_slx.');
end
