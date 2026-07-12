function calTable = decimateNetCDFToCalPoints(ncFiles, varNames, opts)
%DECIMATENETCDFTOCALPOINTS Reduce gigabytes of raw NetCDF data to a small
%table of calibration points, so lsqnonlin can run in-memory.
%
%   calTable = decimateNetCDFToCalPoints(ncFiles, varNames, opts)
%
%   ncFiles  - cellstr/string array of .nc file paths
%   varNames - cellstr of NetCDF variable names to carry through
%              (e.g. {'DPA','DPB','DPR','DPN','DP1','PSA','mr','PTB'} --
%              whatever your Z struct and sigma need)
%   opts     - struct, all fields optional:
%     .timeVar        NetCDF variable name for time, used to build
%                      fixed-duration averaging windows. If omitted,
%                      windows are built from a fixed sample count instead.
%     .windowSec       window length in seconds when timeVar is given
%                       (default 1)
%     .blockSize        samples per window when timeVar is NOT given
%                       (default 100)
%     .minPointsPerWindow  drop windows with fewer valid samples than
%                       this (default 5) -- avoids calibration points
%                       built from a couple of noisy stragglers
%     .stabilityFcn     function handle @(dataStruct) -> logical mask,
%                       same length as the raw data, true where the
%                       aircraft/rig is in a condition you want to keep
%                       (e.g. steady-state: low pitch rate, low dAlt/dt).
%                       dataStruct has one field per entry in varNames
%                       (plus timeVar if given), exactly as read by
%                       readNetCDFChunk. Default: keep everything.
%     .verbose          default true
%
%   OUTPUT  calTable: one row per calibration point (per time/sample
%   window, per file), with columns <var>_mean, <var>_std for every
%   variable in varNames, plus N (samples averaged) and SourceFile.
%
%   This is a REDUCTION step only -- it does not know anything about
%   fcalc, Z, or betaf. Feed the output into buildZStruct.m next.
%
% See also: buildZStruct, runCalibrationFit, readNetCDFChunk

if nargin < 3, opts = struct(); end
opts = localDefaultOpts(opts);

ncFiles = cellstr(ncFiles);
varNames = cellstr(varNames);
readVars = varNames;
if ~isempty(opts.timeVar) && ~any(strcmp(readVars, opts.timeVar))
    readVars = [readVars, {opts.timeVar}];
end

rows = {};

for fi = 1:numel(ncFiles)
    f = ncFiles{fi};
    [data, ok] = readNetCDFChunk(f, readVars);
    if ~ok
        if opts.verbose, fprintf('  %s: skipped (missing/mismatched variable)\n', f); end
        continue
    end

    n = numel(data.(matlab.lang.makeValidName(varNames{1})));

    if ~isempty(opts.stabilityFcn)
        mask = opts.stabilityFcn(data);
    else
        mask = true(n, 1);
    end

    if ~isempty(opts.timeVar)
        t = data.(matlab.lang.makeValidName(opts.timeVar));
        t0 = min(t(mask));
        windowId = floor((t - t0) / opts.windowSec);
    else
        windowId = floor((0:n-1)' / opts.blockSize);
    end
    windowId(~mask) = NaN; % excluded rows never join a window

    uWin = unique(windowId(~isnan(windowId)));
    nAdded = 0;
    for w = uWin'
        idx = windowId == w;
        nPts = sum(idx);
        if nPts < opts.minPointsPerWindow
            continue
        end
        row = struct();
        for v = 1:numel(varNames)
            fld = matlab.lang.makeValidName(varNames{v});
            vals = data.(fld)(idx);
            vals = vals(isfinite(vals));
            if isempty(vals)
                row.([varNames{v} '_mean']) = NaN;
                row.([varNames{v} '_std']) = NaN;
            else
                row.([varNames{v} '_mean']) = mean(vals);
                row.([varNames{v} '_std']) = std(vals);
            end
        end
        row.N = nPts;
        row.SourceFile = string(f);
        rows{end+1} = row; %#ok<AGROW>
        nAdded = nAdded + 1;
    end

    if opts.verbose
        fprintf('  %s: %d raw rows -> %d calibration points\n', f, n, nAdded);
    end
end

if isempty(rows)
    error('decimateNetCDFToCalPoints:noPoints', ...
        'No calibration points survived decimation (check stabilityFcn / minPointsPerWindow / variable names).');
end

calTable = struct2table([rows{:}]);

if opts.verbose
    fprintf('Total calibration points: %d (from %d files)\n', height(calTable), numel(ncFiles));
end

end

% ------------------------------------------------------------------
function opts = localDefaultOpts(opts)
defaults = struct('timeVar', '', 'windowSec', 1, 'blockSize', 100, ...
    'minPointsPerWindow', 5, 'stabilityFcn', [], 'verbose', true);
fn = fieldnames(defaults);
for i = 1:numel(fn)
    if ~isfield(opts, fn{i}) || isempty(opts.(fn{i}))
        opts.(fn{i}) = defaults.(fn{i});
    end
end
end
