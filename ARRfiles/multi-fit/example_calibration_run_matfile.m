%% example_calibration_run_matfile.m
% Calibration fit reading from a processed .mat file (RAW/RATE structs,
% each channel possibly at its own native rate) instead of NetCDF.
% Reproduces the manual script exactly, including the two-stage kk:
%
%   1. resample every channel to orate via changeRate(RAW.(name),RATE.(name),orate)
%   2. a ROUGH kk (find(PTB>PSA & DPA>200 & DPR>20)) drives repairOne on
%      EVERY channel -- interpolates over short non-qualifying dips
%      within the flight, and flattens before-takeoff/after-landing
%      samples to the nearest in-flight value, WITHOUT shrinking the array
%   3. a DIFFERENT, final kk (find(DP1>20 & PSA<PTB & PSA>200)) is
%      computed on the now-REPAIRED data and used to select the actual
%      calibration points
%
% (loadFlightDataFromMat does the same two-stage process without eval --
% results assigned into struct fields per channel instead.)

%% ---------------- CONFIG (edit this section) ----------------
matFile = "E:\MATLAB-DATA2\kingair_data\scratch\test26\temp\20260701_arr_TAS.mat";

% All channels to load/resample from RAW/RATE (kept as a superset --
% DP2/PSB aren't used by fcalc but are available for kk/bounds/inspection).
rnames = ["PTB","DP1","DP2","PSA","PSB","DPA","DPB","DPR","DPN"];

orate = 10;   % common output rate (Hz) every channel is resampled to

% NetCDF-workflow-style Z field map, but pointing at the resampled .mat
% channel names (identical here since the names already match).
% 'mr' (mixing ratio) is still unavailable -- see dummyZFields below.
rawVarMap = struct( ...
    'DPA', 'DPA', ...
    'DPB', 'DPB', ...
    'DPR', 'DPR', ...
    'DPN', 'DPN', ...
    'DP1', 'DP1', ...
    'PSA', 'PSA', ...
    'PTB', 'PTB');

dummyZFields = struct();
dummyZFields.mr = 0;   % mixing ratio unavailable for now -> all zeros

loadOpts = struct();

% Stage 1: rough in-flight condition, computed on the just-resampled
% channels, used ONLY to drive repairOne (gap-fill/extrapolate every
% channel, full length, no shrinking).
loadOpts.repairKkFcn = @(d) find(d.PTB > d.PSA & d.DPA > 200 & d.DPR > 20);
% loadOpts.repairFcn = @repairOne;  % default

% Stage 2: final in-flight selection, computed on the REPAIRED data --
% intentionally a DIFFERENT condition than repairKkFcn above. This is
% what actually picks the calibration points.
loadOpts.kkFcn = @(d) find(d.DP1 > 20 & d.PSA < d.PTB & d.PSA > 200);

% No additional statistical outlier rejection -- matches the manual
% script, which relies entirely on the repair + final-kk steps above.
loadOpts.outlierMethod = 'none';
loadOpts.bounds = struct();
loadOpts.verbose = true;

% sigma: per-channel measurement uncertainty, passed straight through to
% r858_solve3, PLUS fcoef/pcor (uncertainty on the fitted f-coefficient
% and on the position-error correction) -- both required by r858_solve3
% and easy to miss since they aren't per-channel.
%
% NOTE: DP1 (impact pressure) has NO sigma here -- it wasn't in the
% original manual sigma struct either. qx1 = fqx./f0 is built from DP1
% via qx0 = impactPcalc(dp1,...), so DP1 is very likely the DOMINANT
% driver of qx1's real-world uncertainty. Without sigma.DP1,
% predictQTotalUncertainty never propagates DP1's own measurement noise
% at all -- this is the most likely reason the computed SE looked
% smaller than your expected tenths-of-hPa. Added below as a first
% guess (matching PTB/PSA's scale) -- replace with your actual impact
% pressure transducer's real uncertainty.
sigmaValue = struct;
sigmaValue.('PTB')   = 0.1;
sigmaValue.('PSA')   = 0.1;
sigmaValue.('DP1')   = 0.1;   % EDIT: your best estimate of impact-pressure sensor uncertainty (hPa)
sigmaValue.('DPA')   = 0.01;
sigmaValue.('DPB')   = 0.01;
sigmaValue.('DPR')   = 0.01;
sigmaValue.('DPN')   = 0.01;
sigmaValue.('fcoef') = 0.01;
sigmaValue.('pcor')  = 0.5;

% Initial guess.
x0 = [0; 1; -2; 2];

%% ---------------- 1. Load + resample + repair + select ----------------
[flightData, report] = loadFlightDataFromMat(matFile, rnames, orate, [], loadOpts);
disp(report);

%% ---------------- 2. Build Z / sigma ----------------
[Z, sigma] = buildZFromStruct(flightData, rawVarMap, sigmaValue);
Z = addDummyZFields(Z, dummyZFields);   % adds Z.mr = zeros(...) for now
fprintf('Calibration points after kk selection: %d\n', numel(Z.DPA));

%% ---------------- 3. Fit ----------------
% If lsqnonlin ever stalls (resnorm flat, first-order optimality huge and
% not shrinking, step size ~0), run these diagnostics first:
% checkFcalcConditioning(x0, Z, sigma);
% checkPredictorVariation(x0, Z);

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
figure('Name', 'Calibration residuals (matfile source)');
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

% Same comparison as the manual script's plot([qx1,OUT1.q]) -- corrected
% impact pressure (qx1) vs the independent reference (OUT1.q):
[~, qx1, pkor, fcoef] = fcalc(betaf, Z, sigma);
OUT1 = r858_solve3(Z.PTB, Z.PSA, Z.DPA, Z.DPB, Z.DPR, Z.DPN, fcoef, pkor, sigma, .05);

%% ---------------- 5. SE / confidence + prediction intervals on qx1 ----------------
% Confidence interval: parameter uncertainty only (delta method through
% betaf's covariance, diagOut.covB) -- uncertainty in the fitted curve.
ciOpts = struct('confLevel', 0.95, 'dof', diagOut.dof);
[qHat, qSEci, qCI] = predictQConfidence(betaf, diagOut.covB, Z, sigma, ciOpts);

% Prediction interval: parameter uncertainty PLUS residual scatter
% propagated from the input measurement sigmas (sigma.PTB, .PSA, .DPA,
% .DPB, .DPR, .DPN) -- uncertainty for a single new point.
[~, qSEpi, qPI, breakdown] = predictQTotalUncertainty(betaf, diagOut.covB, Z, sigma, ciOpts);

fprintf('qx1 SE: parameter-only median=%.4g   total (+measurement) median=%.4g\n', ...
    median(qSEci), median(qSEpi));
fprintf('  measurement-noise contribution by channel (median variance share):\n');
chanNames = fieldnames(breakdown.perChannelVar);
totalMeasVar = median(breakdown.qSEMeasurement)^2;
for c = 1:numel(chanNames)
    v = median(breakdown.perChannelVar.(chanNames{c}));
    pct = 100 * v / max(totalMeasVar, eps);
    fprintf('    %-6s %.4g%%\n', chanNames{c}, pct);
end

% NOTE: with ~40k scattered real-data points, a filled fill() ribbon
% sorted only by index renders as a dense jagged mass rather than a
% clean band (looks like a solid blob, not a 1D line) -- so this uses
% plain scatter plots instead, which scale to any point count cleanly.
figure('Name', 'qx1 vs reference q, with uncertainty');

subplot(1,2,1);
plot(qHat, OUT1.q, '.', 'MarkerSize', 3);
hold on;
lims = [min([qHat; OUT1.q]), max([qHat; OUT1.q])];
plot(lims, lims, 'r--');
hold off;
xlabel('qx1 (corrected)'); ylabel('OUT1.q (reference)');
title('Corrected vs reference q');

subplot(1,2,2);
plot(qHat, qSEpi, '.', 'MarkerSize', 3);
hold on;
plot(qHat, qSEci, '.', 'MarkerSize', 3);
hold off;
legend('SE total (parameter + measurement)', 'SE parameter-only', 'Location', 'best');
xlabel('qx1'); ylabel('standard error');
title('Uncertainty vs q');

%% ---------------- 6. Binned CI/PI band plot ----------------
% A proper band/ribbon plot, but binned by qx1 (median per bin) instead
% of drawn per raw point -- avoids the earlier overplotting/blob issue
% at ~40k points while still showing a real confidence/prediction band.
nBins = 40;
edges = linspace(min(qHat), max(qHat), nBins + 1);
binIdx = discretize(qHat, edges);
binCenter = nan(nBins, 1);
ciLo = nan(nBins, 1); ciHi = nan(nBins, 1);
piLo = nan(nBins, 1); piHi = nan(nBins, 1);
refMed = nan(nBins, 1);
for b = 1:nBins
    m = binIdx == b;
    if any(m)
        binCenter(b) = median(qHat(m));
        ciLo(b) = median(qCI(m,1));
        ciHi(b) = median(qCI(m,2));
        piLo(b) = median(qPI(m,1));
        piHi(b) = median(qPI(m,2));
        refMed(b) = median(OUT1.q(m));
    end
end
valid = ~isnan(binCenter);
binCenter = binCenter(valid); ciLo = ciLo(valid); ciHi = ciHi(valid);
piLo = piLo(valid); piHi = piHi(valid); refMed = refMed(valid);

figure('Name', 'Binned confidence/prediction band for qx1');
fill([binCenter; flipud(binCenter)], [piLo; flipud(piHi)], ...
    [1 0.9 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.7);
hold on;
fill([binCenter; flipud(binCenter)], [ciLo; flipud(ciHi)], ...
    [0.85 0.85 1], 'EdgeColor', 'none', 'FaceAlpha', 0.8);
plot(binCenter, binCenter, 'k-', 'LineWidth', 1.5);
plot(binCenter, refMed, 'ko', 'MarkerFaceColor', 'w');
hold off;
legend('95% prediction interval (+ measurement noise)', '95% CI (parameter uncertainty only)', ...
    'qx1 (fit)', 'OUT1.q (reference, binned median)', 'Location', 'best');
xlabel('qx1 (binned)'); ylabel('q');
title(sprintf('Binned %d-point confidence/prediction band', nBins));
