function [flightData, report] = loadFlightDataFromMat(matFile, varNames, orate, kk, opts)
%LOADFLIGHTDATAFROMMAT Load channels from a processed .mat file (RAW/RATE
%structs, each channel possibly at its own native sample rate), resample
%every channel to a common orate, then apply an in-flight (kk) selection
%and an outlier/sanity check. The .mat-file equivalent of
%loadFlightData.m (which reads from NetCDF instead).
%
%   [flightData, report] = loadFlightDataFromMat(matFile, varNames, orate, kk, opts)
%   [flightData, report] = loadFlightDataFromMat(matFile, varNames, orate, [], opts)  % with opts.kkFcn
%
%   matFile  - path to a .mat file containing (at least) two structs:
%                RAW.<name>   raw samples for each channel
%                RATE.<name>  that channel's native sample rate (Hz)
%              with one RAW/RATE field per name in varNames.
%   varNames - cellstr/string array of channel names to load, e.g.
%              ["PTB","DP1","DP2","PSA","PSB","DPA","DPB","DPR","DPN"]
%   orate    - common output rate (Hz) every channel is resampled to via
%              changeRate(RAW.(name), RATE.(name), orate). Channels can
%              have different native rates -- that's what RATE is for.
%   kk       - indices marking in-flight samples to keep, in the
%              RESAMPLED (orate) sample space -- same convention as
%              loadFlightData. Pass [] and use opts.kkFcn instead if
%              your in-flight condition is itself defined on the
%              resampled channels (the common case).
%   opts     - struct, optional fields:
%     .repairKkFcn      function handle @(resampledStruct) -> indices,
%                        a ROUGH in-flight condition evaluated on the
%                        just-resampled data and used to REPAIR every
%                        channel (via opts.repairFcn) before the final kk
%                        is computed -- fills short non-qualifying dips
%                        within the flight by interpolation, and
%                        flattens before-takeoff/after-landing samples to
%                        the nearest in-flight value, WITHOUT shrinking
%                        the array. Optional; if omitted, no repair step
%                        runs and kk/kkFcn are evaluated directly on the
%                        resampled data. e.g.:
%                          opts.repairKkFcn = @(d) find(d.PTB>d.PSA & d.DPA>200 & d.DPR>20);
%     .repairFcn        function handle @(x,kk)->x used to do the actual
%                        per-channel repair, default @repairOne.
%     .kkFcn            function handle @(dataStruct) -> indices or
%                        logical mask -- the FINAL in-flight selection,
%                        evaluated on the REPAIRED data if repairKkFcn
%                        was given (else on the resampled data directly),
%                        used INSTEAD of a literal kk, e.g.:
%                          opts.kkFcn = @(d) find(d.DP1>20 & d.PSA<d.PTB & d.PSA>200);
%                        Note this can be a DIFFERENT condition than
%                        repairKkFcn -- the rough condition drives
%                        repair, a separate/refined condition picks the
%                        final calibration points. If both kk and
%                        opts.kkFcn are given, opts.kkFcn wins.
%     .changeRateFcn    default @changeRate
%     .outlierMethod    'mad' | 'zscore' | 'none' (default) -- statistical
%                        outlier rejection on top of kk selection; off by
%                        default since repairKkFcn/repair already cleans
%                        up the flight-envelope boundary and short dips
%     .outlierThreshold  default 5
%     .bounds           struct keyed by channel name, [min max] physical
%                        sanity range, same as loadFlightData
%     .verbose          default true
%
%   flightData - struct of column vectors (field names run through
%                matlab.lang.makeValidName), one per varNames entry,
%                containing rows that survived both kk/kkFcn AND the
%                sanity check.
%   report      - struct: file, nAfterResample, nInFlight, nAfterSanity,
%                perVariableRemoved
%
% See also: loadFlightData, buildZFromStruct, detectOutliers

if nargin < 4, kk = []; end
if nargin < 5, opts = struct(); end
opts = localDefaultOpts(opts);

varNames = cellstr(varNames);

S = load(matFile, 'RAW', 'RATE');
assert(isfield(S, 'RAW') && isfield(S, 'RATE'), 'loadFlightDataFromMat:missingStructs', ...
    '%s must contain both a RAW struct and a RATE struct.', matFile);
RAW = S.RAW;
RATE = S.RATE;

resampled = struct();
for i = 1:numel(varNames)
    name = varNames{i};
    assert(isfield(RAW, name), 'loadFlightDataFromMat:missingRawField', ...
        'RAW.%s not found in %s.', name, matFile);
    assert(isfield(RATE, name), 'loadFlightDataFromMat:missingRateField', ...
        'RATE.%s not found in %s.', name, matFile);
    v = opts.changeRateFcn(RAW.(name), RATE.(name), orate);
    resampled.(matlab.lang.makeValidName(name)) = v(:);
end

fns = fieldnames(resampled);
nAfterResample = numel(resampled.(fns{1}));
for i = 1:numel(fns)
    assert(numel(resampled.(fns{i})) == nAfterResample, ...
        'loadFlightDataFromMat:resampleLengthMismatch', ...
        'changeRate produced inconsistent lengths across channels (%s: %d vs %d).', ...
        fns{i}, numel(resampled.(fns{i})), nAfterResample);
end

if opts.verbose
    fprintf('%s: resampled %d channels to %g Hz (%d samples each)\n', ...
        matFile, numel(fns), orate, nAfterResample);
end

if ~isempty(opts.repairKkFcn)
    initialKk = opts.repairKkFcn(resampled);
    if isempty(initialKk)
        warning('loadFlightDataFromMat:emptyRepairKk', ...
            ['%s: repairKkFcn matched 0 samples -- repair step skipped entirely ' ...
             '(channels left as resampled, unrepaired). This usually means the rough ' ...
             'in-flight condition doesn''t match this file/units -- worth double-checking.'], ...
            matFile);
    else
        for i = 1:numel(fns)
            resampled.(fns{i}) = opts.repairFcn(resampled.(fns{i}), initialKk);
        end
        if opts.verbose
            fprintf('  %s: repaired %d channels using rough kk (%d points)\n', ...
                matFile, numel(fns), numel(initialKk));
        end
    end
end

if ~isempty(opts.kkFcn)
    kkRaw = opts.kkFcn(resampled);
else
    kkRaw = kk;
end

if isempty(kkRaw)
    kkMask = true(nAfterResample, 1);
elseif islogical(kkRaw)
    kkMask = kkRaw(:);
else
    kkMask = false(nAfterResample, 1);
    kkMask(kkRaw) = true;
end
assert(numel(kkMask) == nAfterResample, 'loadFlightDataFromMat:kkLengthMismatch', ...
    'kk implies %d rows but the resampled record has %d rows.', ...
    numel(kkMask), nAfterResample);

sub = struct();
for i = 1:numel(fns)
    sub.(fns{i}) = resampled.(fns{i})(kkMask);
end
nInFlight = sum(kkMask);

goodMask = true(nInFlight, 1);
perVarRemoved = struct();
for i = 1:numel(varNames)
    fld = matlab.lang.makeValidName(varNames{i});
    v = sub.(fld);
    m = detectOutliers(v, opts.outlierMethod, opts.outlierThreshold);
    if isfield(opts.bounds, varNames{i})
        b = opts.bounds.(varNames{i});
        m = m & v >= b(1) & v <= b(2);
    end
    perVarRemoved.(varNames{i}) = sum(~m);
    goodMask = goodMask & m;
end

flightData = struct();
for i = 1:numel(fns)
    flightData.(fns{i}) = sub.(fns{i})(goodMask);
end

report = struct();
report.file = matFile;
report.nAfterResample = nAfterResample;
report.nInFlight = nInFlight;
report.nAfterSanity = sum(goodMask);
report.perVariableRemoved = perVarRemoved;

if opts.verbose
    fprintf('%s: %d after resample -> %d in-flight (kk) -> %d after sanity check (%d flagged)\n', ...
        matFile, nAfterResample, nInFlight, report.nAfterSanity, nInFlight - report.nAfterSanity);
end

end

% ------------------------------------------------------------------
function opts = localDefaultOpts(opts)
defaults = struct('outlierMethod', 'none', 'outlierThreshold', 5, ...
    'bounds', struct(), 'changeRateFcn', @changeRate, 'kkFcn', [], ...
    'repairKkFcn', [], 'repairFcn', @repairOne, 'verbose', true);
fn = fieldnames(defaults);
for i = 1:numel(fn)
    if ~isfield(opts, fn{i}) || isempty(opts.(fn{i}))
        opts.(fn{i}) = defaults.(fn{i});
    end
end
end
