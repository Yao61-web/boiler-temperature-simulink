# Boiler temperature control in Simulink

An educational comparison of single-loop PI and cascade PI control for a normalized boiler-temperature plant. All dynamic responses are produced by Simulink block diagrams through the `sim` interface.

Plant: fuel dynamics 3/(2s+1), temperature dynamics exp(-3s)/(10s+1), load disturbance 1.5/(5s+1). The models use deviation variables around an unspecified operating point.

## Execution

Run the manual **Simulink boiler control validation** GitHub Actions workflow. It installs MATLAB R2025b and Simulink using the official MathWorks actions, builds two SLX models, and simulates tracking, load disturbance, fuel disturbance, combined disturbances, model mismatch and PI parameter variations. Download the `simulink-results` artifact for models, CSV/MAT data, PNG figures and version logs.

MathWorks documents automatic product licensing for public projects (excluding transformation products): https://github.com/matlab-actions/setup-matlab#licensing

No simulation result is asserted until an actual workflow run succeeds and its data is reviewed. Static source checks do not establish Simulink loading or runtime compatibility. No physical boiler safety claim is made.

This repository contains model source and execution configuration only. The course report, original template and assignment screenshots are excluded.
