%% example_calibration_run.m
% End-to-end pitot-static "f-factor" calibration fit over a large
% NetCDF dataset:
%   1. decimate gigabytes of raw data down to calibration points
%   2. assemble the Z struct + sigma that fcalc expects
%   3. run lsqnonlin (runCalibrationFit) to solve for betaf
%   4. plot before/after diagnostics
%
% EVERYTHING IN THE CONFIG SECTION BELOW NEEDS TO BE EDITED to match
% your actual NetCDF variable names -- these are placeholders.

%% ---------------- CONFIG (edit this section) ----------------
ncFolder = '/path/to/netcdf/files';

% NetCDF variable names for each raw channel fcalc's Z struct needs.
% Left side = Z field name (fixed, must match fcalc.m). Right side =
% your actual NetCDF variable name.
% NOTE: 'mr' (mixing ratio) is currently unavailable, so it is
% deliberately NOT listed here -- it's added back into Z as a
% placeholder further down (see dummyZFields + addDummyZFields).
rawVarMap = struct( ...
    'DPA', 'DPA', ...   % EDIT: NetCDF variable name for DPA
    'DPB', 'DPB', ...   % EDIT
    'DPR', 'DPR', ...   % EDIT
    'DPN', 'DPN', ...   % EDIT
    'DP1', 'DP1', ...   % EDIT
    'PSA', 'PSA', ...   % EDIT
    'PTB', 'PTB');       % EDIT

% Z fields that aren't available from data yet -- filled with a fixed
% placeholder value instead. Remove 'mr' from here once real mr data
% exists (and add it back to rawVarMap above).
dummyZFields = struct();
dummyZFields.mr = 0;   % mixing ratio unavailable for now -> all zeros

timeVar = '';       % EDIT: NetCDF time variable name, or leave '' to
                     % decimate by fixed sample-count blocks instead
windowSec = 1;       % averaging window length in seconds (if timeVar set)
blockSize = 100;     % samples per window (if timeVar not set)

% sigma: per-channel measurement uncertainty, passed straight through to
% r858_solve3. Each field can be a fixed scalar, or a calTable column
% name (e.g. 'DP1_std', the within-window scatter) for a data-driven
% per-point value instead. EDIT these to your real instrument sigmas.
sigmaChoice = struct;
sigmaChoice.('PTB') = 0.1;
sigmaChoice.('PSA') = 0.1;
sigmaChoice.('DPA') = 0.05;
sigmaChoice.('DPB') = 0.05;
sigmaChoice.('DPR') = 0.05;
sigmaChoice.('DPN') = 0.05;
% sigmaChoice.('DPN') = 'DPN_std';  % example: data-driven instead of fixed

% Initial guess for betaf = [intercept; machn coeff; machn^2 coeff; abFact coeff]
% This simple round-number guess has been confirmed (with the LB/UB
% bounds below) to converge to the same minimum (resnorm ~18300.9) as a
% separately fine-tuned hand solution -- a real, well-identified minimum,
% not an artifact of starting near the answer.
x0 = [0; 1; -2; 2];

%% ---------------- 1. Decimate ----------------
listing = dir(fullfile(ncFolder, '**', '*.nc'));
ncFiles = fullfile({listing.folder}, {listing.name});
fprintf('Found %d NetCDF files.\n', numel(ncFiles));

rawVarNames = struct2cell(rawVarMap)';

decOpts = struct();
decOpts.timeVar = timeVar;
decOpts.windowSec = windowSec;
decOpts.blockSize = blockSize;
decOpts.minPointsPerWindow = 5;
decOpts.verbose = true;
% Optional: only keep steady-state points. Example (edit or remove):
% decOpts.stabilityFcn = @(d) abs(diff([d.PSA(1); d.PSA])) < 0.5;

calTable = decimateNetCDFToCalPoints(ncFiles, rawVarNames, decOpts);

%% ---------------- 2. Build Z / sigma ----------------
meanVarMap = struct();
fn = fieldnames(rawVarMap);
for i = 1:numel(fn)
    meanVarMap.(fn{i}) = [rawVarMap.(fn{i}) '_mean'];
end
[Z, sigma] = buildZStruct(calTable, meanVarMap, sigmaChoice);
Z = addDummyZFields(Z, dummyZFields);   % adds Z.mr = zeros(...) for now

fprintf('Assembled %d calibration points for the fit.\n', numel(Z.DPA));

%% ---------------- 3. Fit ----------------
% If lsqnonlin ever stalls (resnorm flat, first-order optimality huge and
% not shrinking, step size ~0), run this diagnostic first:
% checkFcalcConditioning(x0, Z, sigma);

% Bounds + solver options confirmed working manually:
fitOpts = struct();
fitOpts.lb = [-3.0;  0.0; -5.0; 0.0];
fitOpts.ub = [ 3.0;  2.0;  0.0; 4.0];
fitOpts.lsqnonlinOpts = optimoptions('lsqnonlin', ...
    'Display', 'iter', ...
    'MaxFunctionEvaluations', 20000);
% TolX/TolFun intentionally left at lsqnonlin's defaults (not overridden).

[betaf, diag] = runCalibrationFit(Z, sigma, x0, fitOpts);

%% ---------------- 4. Diagnostics / plots ----------------
figure('Name', 'Calibration residuals');
subplot(1,2,1);
histogram(diag.fBefore); hold on;
histogram(diag.fAfter);
legend('before fit', 'after fit');
xlabel('residual f = Y - X'); ylabel('count');
title('Residual distribution');

subplot(1,2,2);
plot(diag.fBefore, 'o'); hold on;
plot(diag.fAfter, '.');
legend('before fit', 'after fit');
xlabel('calibration point index'); ylabel('residual f');
title(sprintf('%.1f%% RMS residual reduction', diag.pctResidualReduction));

%% ---------------- 5. Save results ----------------
save(fullfile(ncFolder, 'fits', 'calibration_result.mat'), 'betaf', 'diag', 'calTable', 'Z', 'sigma');
