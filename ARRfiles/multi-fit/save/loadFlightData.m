function [flightData, report] = loadFlightData(ncFile, varNames, kk, opts)
%LOADFLIGHTDATA Load one NetCDF file, keep only the "in-flight" samples
%given by kk, and run an outlier/sanity check on top.
%
%   [flightData, report] = loadFlightData(ncFile, varNames, kk, opts)
%
%   ncFile   - path to a single .nc file (one flight)
%   varNames - cellstr of NetCDF variable names to load (e.g. the 8 raw
%              channels fcalc's Z struct is built from)
%   kk       - indices marking in-flight samples to keep. Can be a
%              logical mask or a vector of numeric indices, same
%              convention as normal MATLAB indexing. Pass [] or omit to
%              keep everything (no in-flight subsetting). IMPORTANT: if
%              resampling is enabled (irate/orate below), kk is defined
%              in the RESAMPLED (orate) sample space, i.e. it indexes
%              into the record AFTER changeRate has been applied to the
%              whole file -- not the original native-rate record.
%   opts     - struct, optional fields:
%     .outlierMethod    'mad' (default) | 'zscore' | 'none' -- passed to
%                        detectOutliers, applied per-variable
%     .outlierThreshold  default 5
%     .bounds            struct keyed by NetCDF variable name (as given
%                        in varNames), each a [min max] physical sanity
%                        range, e.g. opts.bounds.PSA = [200 1100]. Points
%                        outside the range are dropped in addition to
%                        the statistical outlier test. Optional, no
%                        bounds applied by default.
%     .irate, .orate     input/output sample rates (Hz), e.g. irate=1000,
%                        orate=25. If both given and irate~=orate, the
%                        WHOLE raw file is downsampled with
%                        changeRate(X, irate, orate) FIRST, and kk is
%                        then applied to that resampled (orate) record --
%                        so kk must be defined in the resampled sample
%                        space. Default: no resampling (irate/orate unset).
%     .changeRateFcn     function handle used for resampling, default
%                        @changeRate (assumed already on your MATLAB
%                        path, same as tanAlpha/mach/r858_solve3 etc.)
%     .verbose           default true
%
%   flightData - struct of column vectors, one field per varNames entry
%                (field names run through matlab.lang.makeValidName,
%                same convention as readNetCDFChunk), containing only
%                the rows that survived both the kk subset AND the
%                sanity check. A row is dropped if ANY of the requested
%                variables fails its check.
%   report      - struct: file, nRaw, nInFlight, nAfterSanity,
%                perVariableRemoved (struct of per-variable outlier
%                counts, counted before combining across variables)
%
% See also: assembleMultiFlightData, buildZFromStruct, detectOutliers,
%           decimateNetCDFToCalPoints (windowed-average alternative)

if nargin < 3, kk = []; end
if nargin < 4, opts = struct(); end
opts = localDefaultOpts(opts);

[raw, ok] = readNetCDFChunk(ncFile, varNames);
if ~ok
    error('loadFlightData:readFailed', ...
        'Could not read one or more of the requested variables from %s.', ncFile);
end

fns = fieldnames(raw);
nRaw = numel(raw.(fns{1}));

doResample = ~isempty(opts.irate) && ~isempty(opts.orate) && opts.irate ~= opts.orate;
nAfterResample = nRaw;
if doResample
    resampled = struct();
    for i = 1:numel(fns)
        resampled.(fns{i}) = opts.changeRateFcn(raw.(fns{i}), opts.irate, opts.orate);
        resampled.(fns{i}) = resampled.(fns{i})(:);
    end
    nAfterResample = numel(resampled.(fns{1}));
    for i = 1:numel(fns)
        assert(numel(resampled.(fns{i})) == nAfterResample, ...
            'loadFlightData:resampleLengthMismatch', ...
            'changeRate produced inconsistent lengths across variables (%s: %d vs %d).', ...
            fns{i}, numel(resampled.(fns{i})), nAfterResample);
    end
    raw = resampled;
    if opts.verbose
        fprintf('  %s: resampled %d Hz -> %d Hz (%d -> %d samples)\n', ...
            ncFile, opts.irate, opts.orate, nRaw, nAfterResample);
    end
end

% kk is applied AFTER resampling, so it must be defined in the
% resampled (orate) sample space when resampling is enabled.
if isempty(kk)
    kkMask = true(nAfterResample, 1);
elseif islogical(kk)
    kkMask = kk(:);
else
    kkMask = false(nAfterResample, 1);
    kkMask(kk) = true;
end
assert(numel(kkMask) == nAfterResample, 'loadFlightData:kkLengthMismatch', ...
    'kk implies %d rows but the (possibly resampled) record has %d rows.', ...
    numel(kkMask), nAfterResample);

sub = struct();
for i = 1:numel(fns)
    sub.(fns{i}) = raw.(fns{i})(kkMask);
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
report.file = ncFile;
report.nRaw = nRaw;
report.nInFlight = nInFlight;
report.nAfterResample = nAfterResample;
report.nAfterSanity = sum(goodMask);
report.perVariableRemoved = perVarRemoved;

if opts.verbose
    fprintf('%s: %d raw -> %d after resample -> %d in-flight (kk) -> %d after sanity check (%d flagged)\n', ...
        ncFile, nRaw, nAfterResample, nInFlight, report.nAfterSanity, nInFlight - report.nAfterSanity);
end

end

% ------------------------------------------------------------------
function opts = localDefaultOpts(opts)
defaults = struct('outlierMethod', 'mad', 'outlierThreshold', 5, ...
    'bounds', struct(), 'irate', [], 'orate', [], ...
    'changeRateFcn', @changeRate, 'verbose', true);
fn = fieldnames(defaults);
for i = 1:numel(fn)
    if ~isfield(opts, fn{i}) || isempty(opts.(fn{i}))
        opts.(fn{i}) = defaults.(fn{i});
    end
end
end
