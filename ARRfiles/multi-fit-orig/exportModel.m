function exportModel(model, outPath)
%EXPORTMODEL Save a fitted streamFitCorrection model to .mat and .csv.
%
%   exportModel(model, outPath)
%
%   outPath - path without extension, e.g. 'fits/my_model'. Writes:
%       <outPath>.mat  - the full model struct (reload with load/applyCorrectionModel)
%       <outPath>_coefficients.csv - term name + coefficient value table
%
% See also: streamFitCorrection, applyCorrectionModel

[folder, ~, ~] = fileparts(outPath);
if ~isempty(folder) && ~exist(folder, 'dir')
    mkdir(folder);
end

save([outPath '.mat'], 'model');

coefTable = table(model.termNames(:), model.beta(:), ...
    'VariableNames', {'Term','Coefficient'});
writetable(coefTable, [outPath '_coefficients.csv']);

fprintf('Saved model to %s.mat and %s_coefficients.csv\n', outPath, outPath);

end
