function [Xcorrected, correction] = applyCorrectionModel(model, predictorData, Xdata)
%APPLYCORRECTIONMODEL Apply a fitted streamFitCorrection model to new data.
%
%   [Xcorrected, correction] = applyCorrectionModel(model, predictorData, Xdata)
%
%   model          - struct returned by streamFitCorrection
%   predictorData  - n x k matrix of the same predictor variables used to
%                    fit the model, in the same column order as
%                    model.predictorVars
%   Xdata          - n x 1 vector of X values to correct
%
%   correction  = Phi(predictorData) * model.beta
%   Xcorrected  = Xdata + correction    (this should be close to the
%                                         corresponding Y values)
%
% See also: streamFitCorrection, buildDesignMatrix

k = numel(model.predictorVars);
assert(size(predictorData, 2) == k, ...
    'applyCorrectionModel:columnMismatch', ...
    'predictorData must have %d columns (one per predictor in model.predictorVars), got %d.', ...
    k, size(predictorData,2));

P = predictorData;
if model.standardize
    P = (P - model.mu) ./ model.sigma;
end

Phi = buildDesignMatrix(P, model.modelOrder, model.predictorVars);
assert(size(Phi,2) == numel(model.beta), ...
    'applyCorrectionModel:termMismatch', ...
    'Design matrix has %d columns but model.beta has %d entries -- ' ...
    'modelOrder mismatch between fitting and application?', ...
    size(Phi,2), numel(model.beta));

correction = Phi * model.beta;
Xcorrected = Xdata(:) + correction;

end
