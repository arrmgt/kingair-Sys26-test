function [qHat, qSE, qCI, breakdown] = predictQTotalUncertainty(betaf, covB, Z, sigma, opts)
%PREDICTQTOTALUNCERTAINTY Total SE/CI for qx1: parameter uncertainty
%PLUS residual scatter propagated from the input measurement sigmas.
%
%   [qHat, qSE, qCI, breakdown] = predictQTotalUncertainty(betaf, covB, Z, sigma)
%   [qHat, qSE, qCI, breakdown] = predictQTotalUncertainty(betaf, covB, Z, sigma, opts)
%
%   Extends predictQConfidence.m: that function's qSE/qCI only reflect
%   uncertainty in the FITTED CURVE from betaf's covariance (a confidence
%   interval). This function additionally propagates each input
%   channel's OWN measurement uncertainty (sigma.PTB, sigma.PSA,
%   sigma.DPA, sigma.DPB, sigma.DPR, sigma.DPN -- any field present in
%   BOTH sigma and Z; sigma.fcoef/sigma.pcor aren't Z channels, so they
%   are skipped automatically) through qx1, turning the confidence
%   interval into a PREDICTION interval: how uncertain is q for a single
%   point, given both parameter uncertainty AND how noisy the underlying
%   pressure measurements themselves are.
%
%   Var_total(i)       = Var_param(i) + Var_measurement(i)
%   Var_param(i)       = J_beta(i,:) * covB * J_beta(i,:)'      (delta method on betaf)
%   Var_measurement(i) = sum_k (dqx1_i/dZ_k)^2 * sigma_k(i)^2   (delta method on each input channel k, summed)
%
%   The two sources are treated as independent (variances add). Both
%   Jacobians are numerical (central finite differences), since qx1
%   depends on betaf AND the raw pressures through fcalc's iterative
%   loop, not a closed form.
%
%   betaf, covB, Z, sigma - same as predictQConfidence
%   opts - same fields as predictQConfidence (.confLevel, .relStep, .dof), plus:
%     .measRelStep   finite-difference step for the measurement-channel
%                    Jacobian, as a FRACTION OF EACH CHANNEL'S OWN SIGMA
%                    (default 1e-4) -- deliberately small relative to
%                    the physical noise scale, for an accurate local
%                    derivative (not related to the noise magnitude
%                    itself, which is what sigma_k contributes).
%
%   qHat - qx1 at betaf (n x 1)
%   qSE  - TOTAL standard error (parameter + measurement), n x 1
%   qCI  - [qHat-halfwidth, qHat+halfwidth] using qSE, n x 2
%   breakdown - struct: qSEParam, qSEMeasurement, qSETotal (all n x 1,
%               same qSETotal as qSE) and perChannelVar (struct, each
%               sigma-having channel's own variance contribution -- use
%               this to see which measurement dominates the uncertainty)
%
% See also: predictQConfidence, runCalibrationFit, fcalc

if nargin < 5, opts = struct(); end
if ~isfield(opts, 'confLevel') || isempty(opts.confLevel), opts.confLevel = 0.95; end
if ~isfield(opts, 'relStep') || isempty(opts.relStep), opts.relStep = 1e-6; end
if ~isfield(opts, 'measRelStep') || isempty(opts.measRelStep), opts.measRelStep = 1e-4; end

betaf = betaf(:);
p = numel(betaf);

[~, qHat] = fcalc(betaf, Z, sigma);
qHat = qHat(:);
n = numel(qHat);

% --- Parameter uncertainty (same construction as predictQConfidence) ---
Jb = zeros(n, p);
for j = 1:p
    db = zeros(p, 1);
    step = opts.relStep * max(1, abs(betaf(j)));
    db(j) = step;
    [~, qPlus] = fcalc(betaf + db, Z, sigma);
    [~, qMinus] = fcalc(betaf - db, Z, sigma);
    Jb(:, j) = (qPlus(:) - qMinus(:)) / (2 * step);
end
qVarParam = sum((Jb * covB) .* Jb, 2);

% --- Measurement uncertainty: propagate each channel's own sigma ---
chanNames = fieldnames(sigma);
qVarMeas = zeros(n, 1);
perChannelVar = struct();
for c = 1:numel(chanNames)
    name = chanNames{c};
    if ~isfield(Z, name)
        continue % e.g. fcoef, pcor -- not a measurement channel, skip
    end
    sigK = sigma.(name);
    sigK = sigK(:);
    if isscalar(sigK)
        sigK = sigK * ones(n, 1);
    end
    if all(sigK == 0)
        perChannelVar.(name) = zeros(n, 1);
        continue
    end
    baseVal = Z.(name)(:);
    step = opts.measRelStep .* max(sigK, eps);

    Zpert = Z;
    Zpert.(name) = baseVal + step;
    [~, qPlus] = fcalc(betaf, Zpert, sigma);
    Zpert.(name) = baseVal - step;
    [~, qMinus] = fcalc(betaf, Zpert, sigma);

    dqdZ = (qPlus(:) - qMinus(:)) ./ (2 * step);
    contrib = (dqdZ.^2) .* (sigK.^2);
    perChannelVar.(name) = contrib;
    qVarMeas = qVarMeas + contrib;
end

qVarTotal = qVarParam + qVarMeas;
qSEParam = sqrt(max(qVarParam, 0));
qSEMeas = sqrt(max(qVarMeas, 0));
qSE = sqrt(max(qVarTotal, 0));

if ~isfield(opts, 'dof') || isempty(opts.dof)
    dof = max(n - p, 1);
else
    dof = opts.dof;
end

alpha = 1 - opts.confLevel;
if exist('tinv', 'file') == 2
    tcrit = tinv(1 - alpha/2, dof);
else
    tcrit = sqrt(2) * erfinv(opts.confLevel); % normal approximation, no toolbox required
end

qCI = [qHat - tcrit .* qSE, qHat + tcrit .* qSE];

breakdown = struct();
breakdown.qSEParam = qSEParam;
breakdown.qSEMeasurement = qSEMeas;
breakdown.qSETotal = qSE;
breakdown.perChannelVar = perChannelVar;

end
