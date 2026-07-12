function [Phi, termNames] = buildDesignMatrix(X, modelOrder, predictorNames)
%BUILDDESIGNMATRIX Expand raw predictors into a regression design matrix.
%
%   [Phi, termNames] = buildDesignMatrix(X, modelOrder, predictorNames)
%
%   X              - n x k matrix of raw predictor values (the 4-5 input
%                    measurements for n observations)
%   modelOrder     - 'linear'       -> [1, x1..xk]
%                     'interactions'-> [1, x1..xk, pairwise products]
%                     'quadratic'   -> interactions + squared terms
%   predictorNames - cellstr of the k predictor names, used to build
%                    human-readable termNames (e.g. "temp:pressure")
%
%   Phi is n x p (p depends on modelOrder and k). termNames is a 1 x p
%   cellstr aligned with the columns of Phi (first column is always the
%   intercept, "1").
%
% See also: streamFitCorrection, applyCorrectionModel

switch lower(modelOrder)
    case 'linear'
        spec = 'linear';
    case {'interactions','interaction'}
        spec = 'interaction';
    case 'quadratic'
        spec = 'quadratic';
    otherwise
        error('buildDesignMatrix:badModelOrder', ...
            'modelOrder must be ''linear'', ''interactions'', or ''quadratic'' (got ''%s'').', modelOrder);
end

Phi = x2fx(X, spec);
k = size(X, 2);

if nargin < 3 || isempty(predictorNames)
    predictorNames = arrayfun(@(i) sprintf('x%d', i), 1:k, 'UniformOutput', false);
end
predictorNames = cellstr(predictorNames);

termNames = {'(intercept)', predictorNames{:}}; %#ok<CCAT>

if any(strcmpi(spec, {'interaction','quadratic'}))
    for i = 1:k
        for j = (i+1):k
            termNames{end+1} = sprintf('%s:%s', predictorNames{i}, predictorNames{j}); %#ok<AGROW>
        end
    end
end

if strcmpi(spec, 'quadratic')
    for i = 1:k
        termNames{end+1} = sprintf('%s^2', predictorNames{i}); %#ok<AGROW>
    end
end

assert(numel(termNames) == size(Phi,2), ...
    'buildDesignMatrix:termCountMismatch', ...
    'Internal error: term name count (%d) does not match design matrix columns (%d).', ...
    numel(termNames), size(Phi,2));

end
