function report = checkFcalcConditioning(x0, Z, sigma, opts)
%CHECKFCALCCONDITIONING Diagnose why lsqnonlin might stall on fcalc.
%
%   report = checkFcalcConditioning(x0, Z, sigma, opts)
%
%   Run this BEFORE runCalibrationFit if lsqnonlin gets stuck: iterations
%   that stop improving (resnorm flat) while first-order optimality stays
%   huge and the step size collapses toward zero is the classic signature
%   of an exploding/near-singular Jacobian. In fcalc, f0 = XXf*betaf
%   appears in a division (fqx./f0) -- if f0 gets close to zero anywhere
%   in Z for x0 or for the small perturbations lsqnonlin uses to estimate
%   the Jacobian by finite differences, that division blows up, and the
%   resulting Inf/NaN gets silently replaced with 0 by fcalc's
%   `f = fillmissing(f,'constant',0)` line -- which tells the optimizer
%   "this point fits perfectly," a false signal that can create wild,
%   discontinuous gradient estimates exactly like what you're seeing.
%
%   This function evaluates fcalc's f0 output at x0 and at x0 perturbed
%   by a small step in each parameter (mimicking lsqnonlin's own
%   finite-difference steps) and reports how close f0 gets to zero, and
%   how many residuals come back non-finite before fillmissing would
%   have hidden them.
%
%   opts.relStep - relative perturbation size, default 1e-6 (matches
%                  lsqnonlin's default finite-difference step scale)
%
% See also: runCalibrationFit, fcalc

if nargin < 4, opts = struct(); end
if ~isfield(opts, 'relStep') || isempty(opts.relStep), opts.relStep = 1e-6; end

[f_x0, ~, ~, f0_x0] = fcalc(x0, Z, sigma);
report = struct();
report.minAbsF0_at_x0 = min(abs(f0_x0));
report.medAbsF0_at_x0 = median(abs(f0_x0));
report.nNonFiniteResidual_at_x0 = sum(~isfinite(f_x0));

fprintf('checkFcalcConditioning: at x0, min|f0| = %.4g, median|f0| = %.4g\n', ...
    report.minAbsF0_at_x0, report.medAbsF0_at_x0);
if report.minAbsF0_at_x0 < 1e-3 * report.medAbsF0_at_x0
    fprintf(['  WARNING: at least one calibration point has f0 close to zero ' ...
        'relative to the median -- this is exactly what makes fqx./f0 blow up.\n']);
end

p = numel(x0);
report.minAbsF0_perturbed = zeros(p, 1);
report.nNonFiniteResidual_perturbed = zeros(p, 1);
for i = 1:p
    dx = zeros(p, 1);
    step = opts.relStep * max(1, abs(x0(i)));
    dx(i) = step;
    [f_pert, ~, ~, f0_pert] = fcalc(x0 + dx, Z, sigma);
    report.minAbsF0_perturbed(i) = min(abs(f0_pert));
    report.nNonFiniteResidual_perturbed(i) = sum(~isfinite(f_pert));
    fprintf('  perturb param %d by +%.3g: min|f0| = %.4g, %d non-finite residuals (pre-fillmissing)\n', ...
        i, step, report.minAbsF0_perturbed(i), report.nNonFiniteResidual_perturbed(i));
end

if any(report.nNonFiniteResidual_perturbed > 0) || report.nNonFiniteResidual_at_x0 > 0
    fprintf(['  WARNING: fcalc produced non-finite residuals for some points at x0 or ' ...
        'a nearby perturbation. These get silently zeroed by fillmissing, which can ' ...
        'corrupt lsqnonlin''s Jacobian estimate. Consider bounding betaf (lb/ub in ' ...
        'runCalibrationFit) to keep f0 away from zero, or excluding the offending ' ...
        'calibration points.\n']);
end

end
