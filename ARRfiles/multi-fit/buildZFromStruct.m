function [Z, sigma] = buildZFromStruct(dataStruct, varMap, sigmaSource)
%BUILDZFROMSTRUCT Assemble the Z struct (and sigma) fcalc expects,
%directly from a struct-of-vectors (e.g. output of loadFlightData /
%assembleMultiFlightData), with no windowed averaging.
%
%   [Z, sigma] = buildZFromStruct(dataStruct, varMap, sigmaSource)
%
%   dataStruct  - struct of equal-length column vectors, as returned by
%                 loadFlightData or assembleMultiFlightData
%   varMap      - struct mapping each Z field fcalc needs to a field
%                 name in dataStruct, e.g.:
%                     varMap.DPA = 'DPA'; varMap.DPB = 'DPB'; ...
%                 (field names in dataStruct follow
%                 matlab.lang.makeValidName, same as readNetCDFChunk --
%                 usually identical to the raw NetCDF variable name)
%   sigmaSource - a struct of per-channel measurement uncertainties,
%                 matching what r858_solve3 expects, e.g.:
%                     sigmaSource = struct();
%                     sigmaSource.PTB = 0.1;
%                     sigmaSource.PSA = 0.1;
%                     sigmaSource.DPA = 0.05;
%                     sigmaSource.DPB = 0.05;
%                     sigmaSource.DPR = 0.05;
%                     sigmaSource.DPN = 0.05;
%                 Each field can be a scalar (one fixed uncertainty for
%                 that channel, applied to every calibration point) or a
%                 vector with one value per calibration point. sigma is
%                 passed straight through as this struct to fcalc/
%                 r858_solve3 -- field names and count are entirely up
%                 to you/r858_solve3, this function does not require
%                 them to match varMap's fields.
%
%                 For convenience, sigmaSource may also be a single
%                 dataStruct field name (char/string) or a plain numeric
%                 scalar/vector -- in that case sigma is returned as a
%                 plain vector rather than a struct (legacy behavior;
%                 only useful if r858_solve3 accepts sigma as a bare
%                 vector rather than a struct).
%
% See also: loadFlightData, assembleMultiFlightData, buildZStruct (the
%           windowed-table equivalent), runCalibrationFit, fcalc

fields = fieldnames(varMap);
firstFld = dataStruct.(varMap.(fields{1}));
n = numel(firstFld);

Z = struct();
for i = 1:numel(fields)
    col = varMap.(fields{i});
    assert(isfield(dataStruct, col), 'buildZFromStruct:missingField', ...
        'varMap.%s = ''%s'' is not a field of dataStruct. Available fields: %s', ...
        fields{i}, col, strjoin(fieldnames(dataStruct), ', '));
    v = dataStruct.(col)(:);
    assert(numel(v) == n, 'buildZFromStruct:lengthMismatch', ...
        'Field ''%s'' has %d elements, expected %d (does not match the other Z fields).', ...
        col, numel(v), n);
    Z.(fields{i}) = v;
end

if isstruct(sigmaSource)
    sigma = struct();
    sf = fieldnames(sigmaSource);
    for i = 1:numel(sf)
        v = sigmaSource.(sf{i});
        if isscalar(v)
            sigma.(sf{i}) = v; % fixed per-channel uncertainty, passed through as-is
        else
            v = v(:);
            assert(numel(v) == n, 'buildZFromStruct:sigmaFieldLengthMismatch', ...
                'sigma.%s has %d elements; expected 1 (constant) or %d (one per calibration point).', ...
                sf{i}, numel(v), n);
            sigma.(sf{i}) = v;
        end
    end
elseif ischar(sigmaSource) || isstring(sigmaSource)
    col = char(sigmaSource);
    assert(isfield(dataStruct, col), 'buildZFromStruct:missingSigmaField', ...
        'sigmaSource ''%s'' is not a field of dataStruct.', col);
    sigma = dataStruct.(col)(:);
else
    sigma = sigmaSource(:);
    if isscalar(sigma)
        sigma = sigma * ones(n, 1);
    end
    assert(numel(sigma) == n, 'buildZFromStruct:sigmaLengthMismatch', ...
        'sigma must be scalar or have one value per row (%d), got %d.', n, numel(sigma));
end

end
