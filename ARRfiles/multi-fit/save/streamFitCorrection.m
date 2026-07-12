function model = streamFitCorrection(ncFiles, predictorVars, xVar, yVar, opts)
%STREAMFITCORRECTION Out-of-core multivariate regression over many NetCDF
%files, fitting parameters that predict the correction needed so that
%X (after correction) matches Y, from 4-5 input measurements.
%
%   model = streamFitCorrection(ncFiles, predictorVars, xVar, yVar)
%   model = streamFitCorrection(ncFiles, predictorVars, xVar, yVar, opts)
%
% WHAT THIS FITS
%   response  = Y - X                      (the correction needed)
%   predictor = the 4-5 measurement variables named in predictorVars
%   model:  response ~ Phi(predictors) * beta
%   so that     X_corrected = X + Phi(predictors)*beta  ~=  Y
%
%   This is the "calibration" reading of forcing X=Y: rather than
%   predicting Y directly, we predict the gap between X and Y from the
%   input measurements, which is usually the better-conditioned and more
%   physically interpretable target for a calibration/bias-correction
%   problem. If you actually want to predict Y directly from the
%   predictors (ordinary regression, not correction), pass xVar as a
%   vector of zeros or ask me to add a modeTarget='direct' option -- the
%   plumbing is identical either way, only the response definition
%   changes (see local function computeResponse below).
%
% HOW IT SCALES TO "GIGABYTES OF DATA"
%   Nothing here ever holds the full dataset in memory. Files are
%   processed one at a time; each file only ever contributes to running
%   sums (XtX, X'y, y'y, sum(y), n) -- the "normal equation" sufficient
%   statistics for ordinary least squares. Those sums are tiny (p x p
%   where p ~ 5-20), so the whole fit -- coefficients AND R^2/RMSE -- is
%   computed from accumulated sums without ever forming or storing the
%   full design matrix. See accumulateStats below.
%
%   Caveat: each *individual* NetCDF file's requested variables are read
%   fully into memory via ncread (one file at a time). This is fine as
%   long as no single file is bigger than RAM even though the whole
%   collection is gigabytes. If you have single files that themselves
%   exceed memory, say so and this can be switched to block reads using
%   ncread's start/count indexing.
%
% INPUTS
%   ncFiles        cellstr/string array of paths to .nc files
%   predictorVars  cellstr of 4-5 NetCDF variable names (the inputs)
%   xVar, yVar     NetCDF variable names for X and Y (must be co-located
%                  with the predictors within each file -- same grid)
%   opts           struct, all fields optional:
%     .modelOrder   'linear' (default) | 'interactions' | 'quadratic'
%     .validFrac    fraction of FILES held out for validation (default 0.2)
%     .standardize  z-score predictors before fitting (default false)
%     .chunkRows    max rows processed per accumulation step, bounds peak
%                   memory when building Phi for a single file (default 2e6)
%     .seed         RNG seed for the train/validation file split (default 1)
%     .verbose      true/false, print progress per file (default true)
%
% OUTPUT  model struct with fields:
%   termNames, beta, R2, RMSE, n, valR2, valRMSE, nVal, modelOrder,
%   standardize, mu, sigma, predictorVars, xVar, yVar,
%   trainFiles, valFiles
%
% See also: buildDesignMatrix, applyCorrectionModel, exportModel, readNetCDFChunk

if nargin < 5, opts = struct(); end
opts = localDefaultOpts(opts);

ncFiles = cellstr(ncFiles);
predictorVars = cellstr(predictorVars);
assert(numel(predictorVars) >= 2 && numel(predictorVars) <= 8, ...
    'streamFitCorrection:predictorCount', ...
    'Expected roughly 4-5 predictor variables, got %d.', numel(predictorVars));

% --- Train / validation split at the FILE level (not row level) ---
rng(opts.seed);
nFiles = numel(ncFiles);
perm = randperm(nFiles);
if opts.validFrac <= 0 || nFiles <= 1
    nVal = 0; % validation disabled, or can't hold out files if there's only one
else
    nVal = max(1, round(opts.validFrac * nFiles));
    nVal = min(nVal, nFiles - 1); % always keep at least 1 training file
end
valIdx = perm(1:nVal);
trainIdx = perm(nVal+1:end);
trainFiles = ncFiles(trainIdx);
valFiles = ncFiles(valIdx);

if opts.verbose
    fprintf('streamFitCorrection: %d train files, %d validation files.\n', ...
        numel(trainFiles), numel(valFiles));
end

% --- Pass 1 (only if standardizing): predictor mean/std over train files ---
mu = zeros(1, numel(predictorVars));
sigma = ones(1, numel(predictorVars));
if opts.standardize
    if opts.verbose, fprintf('Pass 1/2: accumulating predictor mean/std...\n'); end
    [mu, sigma] = localAccumulateMeanStd(trainFiles, predictorVars, xVar, yVar, opts);
end

% --- Fitting pass over train files ---
if opts.verbose
    passLabel = 'Pass 2/2';
    if ~opts.standardize, passLabel = 'Pass 1/1'; end
    fprintf('%s: accumulating normal equations over training files...\n', passLabel);
end
[XtX, Xty, yty, sumY, n, termNames] = localAccumulateStats( ...
    trainFiles, predictorVars, xVar, yVar, opts, mu, sigma);

assert(n > 0, 'streamFitCorrection:noData', ...
    'No valid (non-NaN) observations were found across the training files.');

% Solve normal equations; fall back to pseudo-inverse if XtX is
% (near-)singular, e.g. from collinear predictors.
condXtX = rcond(XtX);
if condXtX < 1e-12 || isnan(condXtX)
    warning('streamFitCorrection:illConditioned', ...
        ['Normal-equation matrix is ill-conditioned (rcond=%.2g). ' ...
         'Falling back to pinv; consider decorrelating predictors or ' ...
         'using standardize=true.'], condXtX);
    beta = pinv(XtX) * Xty;
else
    beta = XtX \ Xty;
end

[R2, RMSE] = localGoodnessOfFit(XtX, Xty, yty, sumY, n, beta);

% --- Validation pass (reuses fitted beta/mu/sigma, no re-fitting) ---
valR2 = NaN; valRMSE = NaN; nValObs = 0;
if ~isempty(valFiles)
    if opts.verbose, fprintf('Validation pass over held-out files...\n'); end
    [XtXv, Xtyv, ytyv, sumYv, nValObs] = localAccumulateStats( ...
        valFiles, predictorVars, xVar, yVar, opts, mu, sigma);
    if nValObs > 0
        [valR2, valRMSE] = localGoodnessOfFit(XtXv, Xtyv, ytyv, sumYv, nValObs, beta);
    end
end

model = struct();
model.termNames = termNames;
model.beta = beta;
model.R2 = R2;
model.RMSE = RMSE;
model.n = n;
model.valR2 = valR2;
model.valRMSE = valRMSE;
model.nVal = nValObs;
model.modelOrder = opts.modelOrder;
model.standardize = opts.standardize;
model.mu = mu;
model.sigma = sigma;
model.predictorVars = predictorVars;
model.xVar = xVar;
model.yVar = yVar;
model.trainFiles = trainFiles;
model.valFiles = valFiles;
model.targetDefinition = 'response = Y - X (correction), X_corrected = X + Phi(predictors)*beta';

if opts.verbose
    fprintf('Done. Train R^2=%.4f RMSE=%.4g (n=%d) | Val R^2=%.4f RMSE=%.4g (n=%d)\n', ...
        R2, RMSE, n, valR2, valRMSE, nValObs);
end

end

% ------------------------------------------------------------------
function opts = localDefaultOpts(opts)
defaults = struct('modelOrder','linear', 'validFrac',0.2, 'standardize',false, ...
    'chunkRows',2e6, 'seed',1, 'verbose',true);
fn = fieldnames(defaults);
for i = 1:numel(fn)
    if ~isfield(opts, fn{i}) || isempty(opts.(fn{i}))
        opts.(fn{i}) = defaults.(fn{i});
    end
end
end

% ------------------------------------------------------------------
function resp = computeResponse(X, Y)
% The regression target: correction needed so X + correction ~= Y.
% Change this line (and nothing else) to retarget the whole pipeline,
% e.g. resp = Y; for direct prediction of Y from the predictors instead
% of predicting the X-to-Y correction.
resp = Y - X;
end

% ------------------------------------------------------------------
function [mu, sigma] = localAccumulateMeanStd(files, predictorVars, xVar, yVar, opts)
k = numel(predictorVars);
s = zeros(1,k); ss = zeros(1,k); n = 0;
for i = 1:numel(files)
    [data, ok] = readNetCDFChunk(files{i}, [predictorVars, {xVar, yVar}]);
    if ~ok, continue; end
    P = localToMatrix(data, predictorVars);
    X = data.(matlab.lang.makeValidName(xVar));
    Y = data.(matlab.lang.makeValidName(yVar));
    valid = all(isfinite(P), 2) & isfinite(X) & isfinite(Y);
    P = P(valid, :);
    if isempty(P), continue; end
    s = s + sum(P, 1);
    ss = ss + sum(P.^2, 1);
    n = n + size(P,1);
    if opts.verbose
        fprintf('  [mean/std pass] %s: %d valid rows (cumulative n=%d)\n', files{i}, size(P,1), n);
    end
end
if n == 0
    error('streamFitCorrection:noDataMeanStd', 'No valid rows found while computing predictor mean/std.');
end
mu = s / n;
sigma = sqrt(max(ss/n - mu.^2, eps));
end

% ------------------------------------------------------------------
function [XtX, Xty, yty, sumY, n, termNames] = localAccumulateStats( ...
    files, predictorVars, xVar, yVar, opts, mu, sigma)

termNames = {};
XtX = []; Xty = []; yty = 0; sumY = 0; n = 0;

for i = 1:numel(files)
    [data, ok] = readNetCDFChunk(files{i}, [predictorVars, {xVar, yVar}]);
    if ~ok, continue; end
    P = localToMatrix(data, predictorVars);
    X = data.(matlab.lang.makeValidName(xVar));
    Y = data.(matlab.lang.makeValidName(yVar));

    valid = all(isfinite(P), 2) & isfinite(X) & isfinite(Y);
    P = P(valid, :); X = X(valid); Y = Y(valid);
    nRows = size(P, 1);
    if nRows == 0
        if opts.verbose, fprintf('  %s: 0 valid rows, skipped\n', files{i}); end
        continue;
    end

    if opts.standardize
        P = (P - mu) ./ sigma;
    end

    resp = computeResponse(X, Y);

    % Process in row-chunks to bound peak memory for Phi construction.
    chunk = opts.chunkRows;
    for startRow = 1:chunk:nRows
        endRow = min(startRow + chunk - 1, nRows);
        [Phi, tn] = buildDesignMatrix(P(startRow:endRow, :), opts.modelOrder, predictorVars);
        if isempty(termNames), termNames = tn; end
        r = resp(startRow:endRow);

        if isempty(XtX)
            XtX = zeros(size(Phi,2));
            Xty = zeros(size(Phi,2), 1);
        end
        XtX = XtX + Phi' * Phi;
        Xty = Xty + Phi' * r;
        yty = yty + (r' * r);
        sumY = sumY + sum(r);
        n = n + numel(r);
    end

    if opts.verbose
        fprintf('  %s: %d valid rows (cumulative n=%d)\n', files{i}, nRows, n);
    end
end

end

% ------------------------------------------------------------------
function P = localToMatrix(data, predictorVars)
k = numel(predictorVars);
n = numel(data.(matlab.lang.makeValidName(predictorVars{1})));
P = zeros(n, k);
for j = 1:k
    P(:, j) = data.(matlab.lang.makeValidName(predictorVars{j}));
end
end

% ------------------------------------------------------------------
function [R2, RMSE] = localGoodnessOfFit(XtX, Xty, yty, sumY, n, beta)
% All quantities derived purely from accumulated sums -- no need to
% revisit the raw data. SSE = y'y - 2*beta'*X'y + beta'*X'X*beta.
SSE = yty - 2*(beta' * Xty) + beta' * XtX * beta;
SST = yty - (sumY^2) / n;
if SST <= 0
    R2 = NaN; % response was (numerically) constant
else
    R2 = 1 - SSE / SST;
end
RMSE = sqrt(max(SSE, 0) / n);
end
