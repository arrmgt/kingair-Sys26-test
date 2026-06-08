function remove_seconds_from_netcdf(srcFile, dstFile, sps, timeDimName, condFcn)
% remove_seconds_from_netcdf  Trim seconds from a netCDF file based on DP2.
%
% remove_seconds_from_netcdf(srcFile, dstFile, sps, timeDimName, condFcn)
%
% Inputs:
%  - srcFile      : source netCDF filename (string)
%  - dstFile      : destination netCDF filename to create (string)
%  - sps          : samples per second for high-rate vars (e.g., 1000)
%  - timeDimName  : name of the seconds dimension in file (e.g., 'time')
%  - condFcn      : function handle accepting a DP2 slice of shape
%                   [sps, secCount, ...] (or broadcastable variants) and
%                   returning logicals marking "problem" samples.
%                   Examples:
%                     @(x) x < 20
%                     @(x) squeeze(x(25,:,:)) < 20
%                     @(x) any(x < 20, 1)
%
% Behavior:
%  - Scans DP2 only. A second is removed if any sample in that second
%    (across all pages) is marked true by condFcn.
%  - Writes dstFile copying all variables but omitting removed seconds:
%      * 1 Hz variables (time dim = seconds) drop whole-second entries
%      * high-rate variables (first dim == sps and contain time dim) drop
%        the corresponding seconds (keep columns for remaining seconds)
%
% Notes:
%  - The function reads DP2 in blocks to limit memory. It reads other
%    variables entirely; for very large vars you can adapt streaming.
%  - Test on a small copy first.
% Ensure destination file exists so ncwriteatt can write global attributes
% Get file info
info = ncinfo(srcFile);
delete(dstFile);
try
    % Create an empty netCDF4 file (overwrites if already exists? no: create fails if exists)
    fid = netcdf.create(dstFile, 'NETCDF4');
    netcdf.close(fid);
catch ME
    % If file already exists, creation will error; ignore other errors
    if ~contains(ME.message, 'File exists') && ~contains(ME.message, 'already exists')
        rethrow(ME);
    end
end

 % Copy global attributes from raw file
    atts0={info.Attributes.Name};
    vals0 = {info.Attributes.Value}; 
    for i = 1:numel(atts0)
        try
            ncwriteatt(dstFile,'/',atts0{i},vals0{i});
        catch ME
            warning('Failed to copy attribute %s: %s',atts0{i},vals0{i});
            netcdf.close(ncid);
            error("Aborted.");
        end
    end

% Find time dimension length (nSeconds)
timeDim = [];
for d = info.Dimensions
    if strcmp(d.Name, timeDimName)
        timeDim = d; break;
    end
end
if isempty(timeDim)
    error('Time dimension "%s" not found in %s.', timeDimName, srcFile);
end
nSeconds = timeDim.Length;

% Locate DP2
vnames = {info.Variables.Name};
iDP2 = find(strcmp(vnames, 'DP2'), 1);
if isempty(iDP2)
    error('Variable DP2 not found in %s.', srcFile);
end
vDP2 = info.Variables(iDP2);

% Validate DP2 shape: first dim should be sps and it must contain the time dim
dimNames_DP2 = {vDP2.Dimensions.Name};
if vDP2.Dimensions(1).Length ~= sps || ~any(strcmp(dimNames_DP2, timeDimName))
    error('DP2 does not match expected shape [sps, time, ...] with sps=%d.', sps);
end

% Build removeMask by scanning DP2 in blocks of seconds
removeMask = false(nSeconds,1);
blockSec = 200; % tune for memory; reduce if you run out of RAM
secStart = 1;
nd = numel(vDP2.Dimensions);
timeDimIdx = find(strcmp(dimNames_DP2, timeDimName),1);

while secStart <= nSeconds
    secCount = min(blockSec, nSeconds - secStart + 1);
    % prepare start/count for ncread (one element per dim default)
    start = ones(1, nd);
    count = zeros(1, nd);
    for d = 1:nd
        count(d) = vDP2.Dimensions(d).Length;
    end
    start(timeDimIdx) = secStart;
    count(timeDimIdx) = secCount;
    % read slice
    slice = ncread(srcFile, 'DP2', start, count);
    % Ensure slice has first dim = sps and time slice length = secCount. If needed permute.
    ssz = size(slice);
    if ssz(1) ~= sps || ssz(timeDimIdx) ~= secCount
        % attempt to permute so first dim = sps and time dim = 2
        perm = 1:nd;
        perm([1, timeDimIdx]) = perm([timeDimIdx, 1]); % swap
        try
            slice = permute(slice, perm);
            ssz = size(slice);
        catch
            % leave as-is; will handle shapes in cond reduction below
        end
    end

    % Evaluate condition function (user-supplied)
    cond = condFcn(slice); % cond should be logical or convertible to logical

    % Robust reduction to per-second flag (true = problematic second)
    csz = size(cond);
    if isempty(csz), csz = [1 1]; end
    % Normalize csz length
    if numel(csz) == 1, csz = [csz 1]; end

    % Attempt common cases:
    if csz(1) == sps
        % cond: [sps, secCount, rest...]
        secCount_here = csz(2);
        rest = prod(csz(3:end));
        cond2 = reshape(cond, [sps, secCount_here * rest]);
    elseif numel(csz) >= 2 && csz(2) == sps
        % sample dim is second -> bring to first
        perm2 = 1:numel(csz);
        perm2([1,2]) = perm2([2,1]);
        cperm = permute(cond, perm2);
        csz2 = size(cperm);
        secCount_here = csz2(2);
        rest = prod(csz2(3:end));
        cond2 = reshape(cperm, [sps, secCount_here * rest]);
    else
        % sample dim apparently removed, cond is per-second (maybe with rest)
        % Interpret cond as [secCount, rest...] or [1, secCount, rest...]
        if csz(1) == 1 && numel(csz) >= 2
            secCount_here = csz(2);
            rest = prod(csz([1,3:numel(csz)])); % treat 1 as sample-dim removed
            cond2 = reshape(cond, [1, secCount_here * rest]); % sample dim=1
        else
            % assume first dimension is seconds
            secCount_here = csz(1);
            rest = prod(csz(2:end));
            cond2 = reshape(cond, [1, secCount_here * rest]); % sample dim=1
        end
    end

    % Now cond2 is [sps_or_1, secCount_here * rest]
    probFlat = any(cond2, 1); % 1 x (secCount_here * rest)
    probPerSecond = reshape(probFlat, [secCount_here, rest]); % secCount_here x rest
    probPerSecond = any(probPerSecond, 2); % secCount_here x 1
    % Sanity check secCount match
    if secCount_here ~= secCount
        % If mismatch, try to reconcile: if secCount_here==1 and secCount>1, treat as per-block flag
        if secCount_here == 1 && secCount > 1
            % replicate flag for the whole block (conservative)
            probPerSecond = repmat(probPerSecond(1), secCount, 1);
        else
            error('Unexpected condition shape: produced %d seconds but expected %d.', secCount_here, secCount);
        end
    end

    % update removeMask
    removeMask(secStart:secStart+secCount-1) = removeMask(secStart:secStart+secCount-1) | probPerSecond;
    secStart = secStart + secCount;
end

% Determine keep seconds
keepSecs = find(~removeMask);
newNSeconds = numel(keepSecs);


% Copy global attributes
for a = info.Attributes
    try
        ncwriteatt(dstFile, '/', a.Name, a.Value);
    catch
        % skip unsupported attributes
    end
end

% Helper to index time dim in arbitrary-dimension arrays
indexAlongTime = @(data, tIdx, keepIdx) ...
    subsref_wrapper(data, tIdx, keepIdx);

% Copy variables, removing seconds where appropriate
for v = info.Variables
    vname = v.Name;
    varDims = {v.Dimensions.Name};
    hasTime = any(strcmp(varDims, timeDimName));
    % Build dimension pairs for creation
    dimPairs = {};
    for dIdx = 1:numel(v.Dimensions)
        dname = v.Dimensions(dIdx).Name;
        if strcmp(dname, timeDimName)
            dimPairs{end+1} = dname; %#ok<AGROW>
            dimPairs{end+1} = newNSeconds; %#ok<AGROW>
        else
            dimPairs{end+1} = dname; %#ok<AGROW>
            dimPairs{end+1} = v.Dimensions(dIdx).Length; %#ok<AGROW>
        end
    end
    % Create variable in destination
    try
        nccreate(dstFile, vname, 'Dimensions', dimPairs, 'Datatype', v.Datatype);
    catch
        % If nccreate fails (e.g., for scalar vars), create minimal var
        nccreate(dstFile, vname, 'Dimensions', dimPairs);
    end
    % Copy attributes
    for a = v.Attributes
        try
            ncwriteatt(dstFile, vname, a.Name, a.Value);
        catch
        end
    end

    % Read source variable (for very large variables, streaming would be preferable)
    data = ncread(srcFile, vname);
    if ~hasTime
        ncwrite(dstFile, vname, data);
        continue;
    end

    % Find time dim index for this variable
    tIdx = find(strcmp(varDims, timeDimName), 1);
    % Select keepSecs along that dimension
    outData = indexAlongTime(data, tIdx, keepSecs);
    ncwrite(dstFile, vname, outData);
end

end

% -----------------------
% Helper functions below
% -----------------------

function out = subsref_wrapper(data, tDim, keepIdx)
% Return data with dimension tDim indexed by keepIdx, preserving order.
% Works for ndims >= 1.
nd = ndims(data);
% Build cell subscripts
subs = repmat({':'}, 1, nd);
subs{tDim} = keepIdx;
out = data(subs{:});
end
