function [Z, sigma] = buildZStruct(calTable, varMap, sigmaSource)
%BUILDZSTRUCT Assemble the Z struct (and sigma) that fcalc expects, from
%a decimated calibration-point table.
%
%   [Z, sigma] = buildZStruct(calTable, varMap, sigmaSource)
%
%   calTable    - table from decimateNetCDFToCalPoints (one row per
%                 calibration point)
%   varMap      - struct mapping each Z field fcalc needs to a column
%                 name in calTable, e.g.:
%                     varMap.DPA = 'DPA_mean';
%                     varMap.DPB = 'DPB_mean';
%                     varMap.DPR = 'DPR_mean';
%                     varMap.DPN = 'DPN_mean';
%                     varMap.DP1 = 'DP1_mean';
%                     varMap.PSA = 'PSA_mean';
%                     varMap.mr  = 'mr_mean';
%                     varMap.PTB = 'PTB_mean';
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
%                 vector with one value per calibration point (e.g. a
%                 calTable column such as 'DP1_std', the within-window
%                 scatter, as a data-driven per-point uncertainty).
%                 sigma is passed straight through as this struct to
%                 fcalc/r858_solve3.
%
%                 For convenience, sigmaSource may also be a single
%                 calTable column name (char/string) or a plain numeric
%                 scalar/vector -- in that case sigma is returned as a
%                 plain vector rather than a struct (legacy behavior;
%                 only useful if r858_solve3 accepts sigma as a bare
%                 vector rather than a struct).
%
% See also: decimateNetCDFToCalPoints, runCalibrationFit, fcalc

fields = fieldnames(varMap);
n = height(calTable);
Z = struct();
for i = 1:numel(fields)
    col = varMap.(fields{i});
    assert(ismember(col, calTable.Properties.VariableNames), ...
        'buildZStruct:missingColumn', ...
        'varMap.%s = ''%s'' is not a column of calTable. Available columns: %s', ...
        fields{i}, col, strjoin(calTable.Properties.VariableNames, ', '));
    Z.(fields{i}) = calTable.(col)(:);
end

if isstruct(sigmaSource)
    sigma = struct();
    sf = fieldnames(sigmaSource);
    for i = 1:numel(sf)
        v = sigmaSource.(sf{i});
        if ischar(v) || isstring(v)
            % Field value is itself a calTable column name to pull per-point sigma from.
            col = char(v);
            assert(ismember(col, calTable.Properties.VariableNames), ...
                'buildZStruct:missingSigmaColumn', ...
                'sigma.%s = ''%s'' is not a column of calTable.', sf{i}, col);
            sigma.(sf{i}) = calTable.(col)(:);
        elseif isscalar(v)
            sigma.(sf{i}) = v; % fixed per-channel uncertainty, passed through as-is
        else
            v = v(:);
            assert(numel(v) == n, 'buildZStruct:sigmaFieldLengthMismatch', ...
                'sigma.%s has %d elements; expected 1 (constant) or %d (one per calibration point).', ...
                sf{i}, numel(v), n);
            sigma.(sf{i}) = v;
        end
    end
elseif ischar(sigmaSource) || isstring(sigmaSource)
    col = char(sigmaSource);
    assert(ismember(col, calTable.Properties.VariableNames), ...
        'buildZStruct:missingSigmaColumn', ...
        'sigmaSource ''%s'' is not a column of calTable.', col);
    sigma = calTable.(col)(:);
else
    sigma = sigmaSource(:);
    if isscalar(sigma)
        sigma = sigma * ones(n, 1);
    end
    assert(numel(sigma) == n, 'buildZStruct:sigmaLengthMismatch', ...
        'sigma must be scalar or have one value per calibration point (%d), got %d.', ...
        n, numel(sigma));
end

end
