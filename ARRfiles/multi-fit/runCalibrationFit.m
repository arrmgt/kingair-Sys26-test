function [betaf, diagnostics] = runCalibrationFit(Z, sigma, x0, opts)
%RUNCALIBRATIONFIT Fit betaf via lsqnonlin so corrected X matches
%reference Y, using fcalc as the residual function.
%
%   [betaf, diagnostics] = runCalibrationFit(Z, sigma, x0)
%   [betaf, diagnostics] = runCalibrationFit(Z, sigma, x0, opts)
%
%   Z, sigma - as built by buildZStruct/buildZFromStruct (already
%              reduced to a size that comfortably fits in memory -- this
%              function does NOT stream, it calls lsqnonlin directly).
%              sigma is normally a struct of per-channel uncertainties
%              (e.g. sigma.PTB = 0.1) -- it is passed straight through
%              to fcalc/r858_solve3 unchanged, this function never looks
%              inside it.
%   x0       - initial guess for betaf (4x1: intercept, machn, machn^2,
%              abFact coefficients, matching fcalc's XXf layout)
%   opts     - struct, optional fields:
%     .lb, .ub        bounds passed to lsqnonlin (default: unbounded).
%                      STRONGLY RECOMMENDED if you see lsqnonlin stall
%                      (first-order optimality huge and not shrinking,
%                      step size collapsed near zero, resnorm flat) --
%                      that pattern usually means f0 = XXf*betaf is
%                      wandering close to zero somewhere in Z during the
%                      search, which blows up fqx./f0 inside fcalc.
%                      Bounding betaf to a physically sensible range
%                      keeps the search away from that. Run
%                      checkFcalcConditioning(x0,Z,sigma) first to check.
%     .typicalX       passed to optimoptions as 'TypicalX' -- the
%                      expected magnitude of each betaf entry. Default is
%                      max(abs(x0),1), which is a weak guess; if your
%                      parameters have very different natural scales
%                      (e.g. intercept ~1.68 but a coefficient that's
%                      naturally ~1e-4), supply real typical values here
%                      -- badly mismatched scales are a common cause of
%                      exactly the stall pattern described above.
%     .lsqnonlinOpts  an optimoptions('lsqnonlin', ...) object to use
%                      instead of the default (Display='iter-detailed',
%                      FunctionTolerance/StepTolerance=1e-8,
%                      MaxFunctionEvaluations=1000, MaxIterations=200 --
%                      deliberately NOT the very tight 1e-10 tolerances
%                      from an earlier version of this file, which let a
%                      stalled fit grind for a very long time before
%                      stopping instead of terminating and reporting)
%
%   diagnostics fields: exitflag, resnorm, output, se (approximate
%   parameter standard errors from the Jacobian), covB (full parameter
%   covariance matrix, mse*inv(J'*J) -- feed to predictQConfidence.m for
%   SE/CI on qx1), dof (n-p, degrees of freedom), fBefore, fAfter,
%   rmsBefore, rmsAfter, pctResidualReduction
%
% See also: buildZStruct, fcalc, decimateNetCDFToCalPoints,
%           checkFcalcConditioning, predictQConfidence

if nargin < 4, opts = struct(); end
if ~isfield(opts, 'lb') || isempty(opts.lb), opts.lb = []; end
if ~isfield(opts, 'ub') || isempty(opts.ub), opts.ub = []; end
if ~isfield(opts, 'typicalX') || isempty(opts.typicalX)
    opts.typicalX = max(abs(x0(:)), 1);
end
if ~isfield(opts, 'lsqnonlinOpts') || isempty(opts.lsqnonlinOpts)
    opts.lsqnonlinOpts = optimoptions('lsqnonlin', ...
        'Display', 'iter-detailed', ...
        'FunctionTolerance', 1e-8, ...
        'StepTolerance', 1e-8, ...
        'TypicalX', opts.typicalX, ...
        'MaxFunctionEvaluations', 1000, ...
        'MaxIterations', 200);
end

fBefore = fcalc(x0, Z, sigma);

[betaf, resnorm, residual, exitflag, output, ~, jacobian] = lsqnonlin( ...
    @(x) fcalc(x, Z, sigma), x0, opts.lb, opts.ub, opts.lsqnonlinOpts);

x=fcalc(betaf,Z,sigma);
fAfter = residual;

n = numel(fAfter);
p = numel(betaf);
dof = max(n - p, 1);
mse = resnorm / dof;
J = full(jacobian);
try
    covB = mse * inv(J' * J); %#ok<MINV>
    se = sqrt(diag(covB));
catch
    warning('runCalibrationFit:singularJacobian', ...
        'J''J is singular at the solution; parameter standard errors not available.');
    covB = NaN(p, p);
    se = NaN(p, 1);
end

rmsBefore = sqrt(mean(fBefore.^2));
rmsAfter = sqrt(mean(fAfter.^2));

diagnostics = struct();
diagnostics.exitflag = exitflag;
diagnostics.resnorm = resnorm;
diagnostics.output = output;
diagnostics.se = se;
diagnostics.covB = covB;   % full parameter covariance -- feed to predictQConfidence for SE/CI on qx1
diagnostics.dof = dof;
diagnostics.fBefore = fBefore;
diagnostics.fAfter = fAfter;
diagnostics.rmsBefore = rmsBefore;
diagnostics.rmsAfter = rmsAfter;
diagnostics.pctResidualReduction = 100 * (1 - rmsAfter / rmsBefore);

fprintf('\nlsqnonlin exit flag: %d (%s)\n', exitflag, output.message);
fprintf('betaf = [%s]\n', sprintf('%.6g  ', betaf));
fprintf('approx std err = [%s]\n', sprintf('%.3g  ', se));
fprintf('RMS residual: before=%.6g  after=%.6g  (%.1f%% reduction)\n', ...
    rmsBefore, rmsAfter, diagnostics.pctResidualReduction);
if exitflag <= 0
    fprintf(['WARNING: exitflag <= 0 means lsqnonlin did NOT converge to a solution ' ...
        '(it stopped on an iteration/evaluation limit or stalled). Try ' ...
        'checkFcalcConditioning(x0,Z,sigma), and/or set opts.lb/opts.ub to bound betaf.\n']);
end


end
