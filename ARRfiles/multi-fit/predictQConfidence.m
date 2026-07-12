function [qHat, qSE, qCI] = predictQConfidence(betaf, covB, Z, sigma, opts)
%PREDICTQCONFIDENCE Standard error and confidence interval for qx1 (the
%corrected impact pressure) from a fitted calibration, via the delta
%method.
%
%   [qHat, qSE, qCI] = predictQConfidence(betaf, covB, Z, sigma)
%   [qHat, qSE, qCI] = predictQConfidence(betaf, covB, Z, sigma, opts)
%
%   betaf  - fitted parameters (from runCalibrationFit)
%   covB   - parameter covariance matrix, diagnostics.covB from
%            runCalibrationFit (mse*inv(J'*J))
%   Z, sigma - calibration data (the same data used for the fit, or new
%            data, to get predictions/CIs at new points from the fitted
%            model)
%   opts   - struct, optional fields:
%     .confLevel   confidence level, default 0.95
%     .relStep     relative finite-difference step used to build the
%                  Jacobian of qx1 w.r.t. betaf, default 1e-6
%     .dof         degrees of freedom for the critical value. Default:
%                  diagnostics.dof if you pass the whole diagnostics
%                  struct in as covB's source is not tracked here, so by
%                  default this uses numel(qHat) - numel(betaf); pass
%                  opts.dof explicitly if you want runCalibrationFit's
%                  exact dof (e.g. opts.dof = diagnostics.dof).
%
%   qHat - qx1 at betaf (n x 1) -- fcalc's second output
%   qSE  - standard error of qHat FROM PARAMETER UNCERTAINTY ALONE (n x 1).
%          This is not a prediction interval for a new single
%          observation (which would also include residual scatter) --
%          it's the uncertainty in the fitted correction curve itself.
%   qCI  - [qHat-halfwidth, qHat+halfwidth], n x 2, using a t (or normal,
%          if Statistics and Machine Learning Toolbox isn't available)
%          critical value at opts.confLevel
%
%   WHY NUMERICAL DIFFERENTIATION: qx1 = fqx./f0 where f0 is the result
%   of fcalc's fixed 3-iteration loop (f0 depends on betaf both directly
%   AND indirectly, through machn depending on the previous iteration's
%   f0). There's no simple closed form for dqx1/dbetaf, so this
%   perturbs each betaf entry (mirroring how lsqnonlin's own Jacobian is
%   estimated) and re-evaluates fcalc -- p+1 extra evaluations for p
%   parameters (central differences: 2p), cheap since Z is already
%   in-memory-sized.
%
% See also: runCalibrationFit, fcalc

if nargin < 5, opts = struct(); end
if ~isfield(opts, 'confLevel') || isempty(opts.confLevel), opts.confLevel = 0.95; end
if ~isfield(opts, 'relStep') || isempty(opts.relStep), opts.relStep = 1e-6; end

betaf = betaf(:);
p = numel(betaf);

[~, qHat] = fcalc(betaf, Z, sigma);
qHat = qHat(:);
n = numel(qHat);

J = zeros(n, p);
for j = 1:p
    db = zeros(p, 1);
    step = opts.relStep * max(1, abs(betaf(j)));
    db(j) = step;
    [~, qPlus] = fcalc(betaf + db, Z, sigma);
    [~, qMinus] = fcalc(betaf - db, Z, sigma);
    J(:, j) = (qPlus(:) - qMinus(:)) / (2 * step);
end

% Var(qHat_i) = J_i * covB * J_i' for each row i (delta method).
% Vectorized: sum((J*covB) .* J, 2) is the same as computing each
% quadratic form J_i*covB*J_i' without an explicit per-row loop.
qVar = sum((J * covB) .* J, 2);
qSE = sqrt(max(qVar, 0));

if ~isfield(opts, 'dof') || isempty(opts.dof)
    dof = max(n - p, 1);
else
    dof = opts.dof;
end

alpha = 1 - opts.confLevel;
if exist('tinv', 'file') == 2
    tcrit = tinv(1 - alpha/2, dof);
else
    % Normal approximation, no toolbox required: erfinv is core MATLAB.
    tcrit = sqrt(2) * erfinv(opts.confLevel);
end

qCI = [qHat - tcrit .* qSE, qHat + tcrit .* qSE];

end
