%% example_calibration_run_single_flight.m
% Calibration fit starting point: ONE NetCDF file, using your own
% in-flight index vector kk (e.g. computed from weight-on-wheels,
% altitude, or however you already identify the in-flight portion of
% the record), plus an outlier/sanity check on top of that selection.
%
% This is the simplest entry point -- no windowed decimation, every
% surviving in-flight sample becomes a calibration point directly. Once
% you're happy with a single flight, see the "MULTIPLE FLIGHTS" section
% at the bottom for how this extends without changing anything else.
%
% EVERYTHING IN THE CONFIG SECTION BELOW NEEDS TO BE EDITED to match
% your actual NetCDF variable names -- these are placeholders.

%% ---------------- CONFIG (edit this section) ----------------
ncFile = '/path/to/flight1.nc';

% NetCDF variable names for each raw channel fcalc's Z struct needs.
% NOTE: 'mr' (mixing ratio) is currently unavailable, so it is
% deliberately NOT listed here -- that means it's never looked up in the
% NetCDF file (readNetCDFChunk would otherwise fail/skip the file if it
% tried to read a variable that doesn't exist). It gets added back into
% Z as a placeholder further down, via dummyZFields + addDummyZFields.
rawVarMap = struct( ...
    'DPA', 'DPA', ...   % EDIT: NetCDF variable name for DPA
    'DPB', 'DPB', ...   % EDIT
    'DPR', 'DPR', ...   % EDIT
    'DPN', 'DPN', ...   % EDIT
    'DP1', 'DP1', ...   % EDIT
    'PSA', 'PSA', ...   % EDIT
    'PTB', 'PTB');       % EDIT
rawVarNames = struct2cell(rawVarMap)';

% Z fields that aren't available from data yet -- filled with a fixed
% placeholder value instead. Add more fields here if other channels
% become unavailable too; remove 'mr' from here once real mr data exists
% (and add it back to rawVarMap above).
dummyZFields = struct();
dummyZFields.mr = 0;   % mixing ratio unavailable for now -> all zeros over kk

% Outlier / sanity check settings
loadOpts = struct();
loadOpts.outlierMethod = 'mad';      % 'mad' | 'zscore' | 'none'
loadOpts.outlierThreshold = 5;       % scaled-MAD (or std) multiples
loadOpts.bounds = struct();          % optional physical range checks, e.g.:
% loadOpts.bounds.PSA = [200 1100];  % static pressure sanity range
% loadOpts.bounds.DP1 = [0 400];     % impact pressure must be nonnegative-ish
loadOpts.verbose = true;

% Rate change: raw data is 1000 Hz, which makes lsqnonlin painfully slow
% over a full flight. loadFlightData resamples the WHOLE file to 25 Hz
% with your changeRate function FIRST, then kk (below) is applied to
% that resampled record.
loadOpts.irate = 1000;
loadOpts.orate = 25;
% loadOpts.changeRateFcn = @changeRate;  % default; override if you use a different name/signature

% Your in-flight index vector. IMPORTANT: since rate-changing is enabled
% above, kk must be defined in the RESAMPLED (25 Hz) sample space -- i.e.
% indices into the record AFTER changeRate, not the original 1000 Hz
% record. It can be a logical mask the same length as the resampled
% record, or a list of indices.
kk = [];   % EDIT: e.g. kk = 40:2500;  (placeholder keeps everything)

% sigma: per-channel measurement uncertainty, passed straight through to
% r858_solve3. EDIT these to your real instrument uncertainties.
sigmaValue = struct;
sigmaValue.('PTB') = 0.1;
sigmaValue.('PSA') = 0.1;
sigmaValue.('DPA') = 0.05;
sigmaValue.('DPB') = 0.05;
sigmaValue.('DPR') = 0.05;
sigmaValue.('DPN') = 0.05;

% Initial guess for betaf. This simple round-number guess has been
% confirmed (with the LB/UB bounds below) to converge to the same
% minimum (resnorm ~18300.9) as a separately fine-tuned hand solution --
% i.e. this is a real, well-identified minimum, not an artifact of
% starting near the answer, so this is a safe default for future flights
% where you won't already know the answer.
x0 = [0; 1; -2; 2];

%% ---------------- 1. Load + sanity-check this flight ----------------
[flightData, report] = loadFlightData(ncFile, rawVarNames, kk, loadOpts);
disp(report);

%% ---------------- 2. Build Z / sigma ----------------
[Z, sigma] = buildZFromStruct(flightData, rawVarMap, sigmaValue);
Z = addDummyZFields(Z, dummyZFields);   % adds Z.mr = zeros(...) for now
fprintf('Calibration points after kk + sanity check: %d\n', numel(Z.DPA));

%% ---------------- 3. Fit ----------------
% If lsqnonlin ever stalls (resnorm flat, first-order optimality huge and
% not shrinking, step size ~0), run this diagnostic first -- it usually
% means f0 in fcalc is wandering close to zero somewhere:
% checkFcalcConditioning(x0, Z, sigma);

% Bounds + solver options confirmed working manually:
fitOpts = struct();
fitOpts.lb = [-3.0;  0.0; -5.0; 0.0];
fitOpts.ub = [ 3.0;  2.0;  0.0; 4.0];
fitOpts.lsqnonlinOpts = optimoptions('lsqnonlin', ...
    'Display', 'iter', ...
    'MaxFunctionEvaluations', 20000);
% TolX/TolFun intentionally left at lsqnonlin's defaults (not overridden).

[betaf, diagOut] = runCalibrationFit(Z, sigma, x0, fitOpts);

%% ---------------- 4. Diagnostics ----------------
figure('Name', 'Single-flight calibration residuals');
subplot(1,2,1);
histogram(diagOut.fBefore); hold on;
histogram(diagOut.fAfter);
legend('before fit', 'after fit');
xlabel('residual f = Y - X'); ylabel('count');
title('Residual distribution');

subplot(1,2,2);
plot(diagOut.fBefore, 'o'); hold on;
plot(diagOut.fAfter, '.');
legend('before fit', 'after fit');
xlabel('calibration point index'); ylabel('residual f');
title(sprintf('%.1f%% RMS residual reduction', diagOut.pctResidualReduction));

%% ---------------- MULTIPLE FLIGHTS (later) ----------------
% Once you have more than one flight, each with its own kk, this whole
% workflow extends with no changes to fcalc/buildZFromStruct/runCalibrationFit
% -- only the data-assembly step changes, from loadFlightData (one file)
% to assembleMultiFlightData (many files):
%
%   flights(1).file = '/path/to/flight1.nc'; flights(1).kk = kk1;
%   flights(2).file = '/path/to/flight2.nc'; flights(2).kk = kk2;
%   flights(3).file = '/path/to/flight3.nc'; flights(3).kk = kk3;
%
%   [combinedData, perFlightReports] = assembleMultiFlightData(flights, rawVarNames, loadOpts);
%   [Z, sigma] = buildZFromStruct(combinedData, rawVarMap, sigmaValue);
%   Z = addDummyZFields(Z, dummyZFields);   % still needed until real mr exists
%   [betaf, diagOut] = runCalibrationFit(Z, sigma, x0);
%
% combinedData also carries a FlightIndex field (1,2,3,...) so you can
% color/split diagnostic plots by flight, e.g.:
%   gscatter(1:numel(diagOut.fAfter), diagOut.fAfter, combinedData.FlightIndex);
%
% If your combined multi-flight dataset grows into the gigabytes again
% (many long flights), swap this per-sample assembly for
% decimateNetCDFToCalPoints (windowed mean/std reduction) instead of
% loadFlightData/assembleMultiFlightData -- runCalibrationFit doesn't
% care which one produced Z/sigma.
