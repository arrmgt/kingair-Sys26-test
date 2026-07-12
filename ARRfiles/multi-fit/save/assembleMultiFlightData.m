function [combinedData, perFlightReports] = assembleMultiFlightData(flights, varNames, opts)
%ASSEMBLEMULTIFLIGHTDATA Load + sanity-check several flights and
%concatenate them into one struct of vectors, ready for buildZFromStruct.
%
%   [combinedData, perFlightReports] = assembleMultiFlightData(flights, varNames, opts)
%
%   flights  - struct array (or cell array of structs), one entry per
%              flight, each with fields:
%                .file  - path to that flight's .nc file
%                .kk    - that flight's in-flight indices/logical mask
%                         (same convention as loadFlightData)
%              e.g.:
%                flights(1).file = 'flight1.nc'; flights(1).kk = kk1;
%                flights(2).file = 'flight2.nc'; flights(2).kk = kk2;
%   varNames - cellstr of NetCDF variable names to load for every flight
%   opts     - passed straight through to loadFlightData for every
%              flight (outlierMethod, outlierThreshold, bounds, verbose)
%
%   combinedData adds one extra field, FlightIndex (1,2,3,... per row,
%   matching the order of `flights`), so you can trace calibration
%   points back to their source flight afterward.
%
% See also: loadFlightData, buildZFromStruct, runCalibrationFit

if nargin < 3, opts = struct(); end
if iscell(flights)
    flights = [flights{:}];
end

perFlightReports = cell(numel(flights), 1);
chunks = cell(numel(flights), 1);

for i = 1:numel(flights)
    [fd, rep] = loadFlightData(flights(i).file, varNames, flights(i).kk, opts);
    n = numel(fd.(matlab.lang.makeValidName(varNames{1})));
    fd.FlightIndex = i * ones(n, 1);
    chunks{i} = fd;
    perFlightReports{i} = rep;
end

fns = fieldnames(chunks{1});
combinedData = struct();
for f = 1:numel(fns)
    parts = cellfun(@(c) c.(fns{f}), chunks, 'UniformOutput', false);
    combinedData.(fns{f}) = vertcat(parts{:});
end

totalIn = sum(cellfun(@(r) r.nAfterSanity, perFlightReports));
fprintf('assembleMultiFlightData: %d flights combined, %d total calibration-eligible points.\n', ...
    numel(flights), totalIn);

end
