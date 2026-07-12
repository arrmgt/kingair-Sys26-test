function [data, ok] = readNetCDFChunk(ncFile, varNames)
%READNETCDFCHUNK Read and flatten a set of variables from one NetCDF file.
%
%   [data, ok] = readNetCDFChunk(ncFile, varNames) reads each variable in
%   the cellstr/string array varNames from ncFile, flattens it to a
%   column vector (data.(name) = value(:)), and replaces any _FillValue /
%   missing_value entries with NaN.
%
%   ok is true if every requested variable was present and all variables
%   had the same number of elements (i.e. they are co-located on the same
%   grid within this file, which is the assumption the rest of the
%   toolbox relies on). If ok is false, the file is skipped by the caller
%   and a warning is issued -- this is the main thing to check first if
%   your dataset uses per-variable dimensions that don't line up.
%
%   data is a struct with one field per variable name, each an Nx1
%   double column vector with fill values converted to NaN.
%
% See also: streamFitCorrection, listNetCDFVariables

varNames = cellstr(varNames);
data = struct();
ok = true;
n = NaN;

for i = 1:numel(varNames)
    name = varNames{i};
    try
        raw = ncread(ncFile, name);
    catch err
        warning('readNetCDFChunk:missingVar', ...
            'Variable "%s" not found in %s (%s). Skipping file.', ...
            name, ncFile, err.message);
        ok = false;
        return
    end

    col = double(raw(:));

    % Replace fill/missing values with NaN using standard CF attributes
    % when present.
    fillVal = localGetAttribute(ncFile, name, '_FillValue');
    if ~isempty(fillVal)
        col(col == fillVal) = NaN;
    end
    missVal = localGetAttribute(ncFile, name, 'missing_value');
    if ~isempty(missVal)
        col(col == missVal) = NaN;
    end

    if isnan(n)
        n = numel(col);
    elseif numel(col) ~= n
        warning('readNetCDFChunk:sizeMismatch', ...
            ['Variable "%s" in %s has %d elements, expected %d ' ...
             '(does not match the other selected variables). Skipping file.'], ...
            name, ncFile, numel(col), n);
        ok = false;
        return
    end

    data.(matlab.lang.makeValidName(name)) = col;
end

end

function val = localGetAttribute(ncFile, varName, attName)
val = [];
try
    val = ncreadatt(ncFile, varName, attName);
catch
    % Attribute not present -- that's fine, most files won't have both.
end
end
