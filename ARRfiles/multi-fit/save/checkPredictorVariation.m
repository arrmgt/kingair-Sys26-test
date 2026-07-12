function report = checkPredictorVariation(x0, Z)
%CHECKPREDICTORVARIATION Check whether machn/machn^2/abFact actually vary
%enough across your calibration points to identify a 4-parameter betaf.
%
%   report = checkPredictorVariation(x0, Z)
%
%   Recomputes the same intermediate quantities fcalc does (tanAlpha,
%   tanBeta, abFact, the 3-iteration machn/pErr loop using x0 to get a
%   representative machn) and reports the spread of machn and abFact,
%   plus the rank and condition number of XXf = [1, machn, machn^2, abFact]
%   -- the design matrix multiplying betaf.
%
%   WHY THIS MATTERS: if checkFcalcConditioning shows f0 = XXf*betaf
%   coming back essentially CONSTANT across every calibration point
%   (e.g. min|f0| == median|f0| to full precision), the most likely
%   explanation isn't a bug -- it's that machn/machn^2/abFact don't vary
%   enough across this particular kk-selected segment (e.g. a single
%   steady-state flight condition has almost constant Mach number) for
%   the model to tell betaf(2), betaf(3), betaf(4) apart. If XXf is
%   rank-deficient or has a huge condition number, many different betaf
%   vectors fit ~equally well -- this ALSO explains a stalled/non-
%   converging lsqnonlin (a near-singular Jacobian has no well-defined
%   descent direction) and why a different solve attempt could land on a
%   very different-looking betaf that still reproduces a near-constant f0.
%
%   If this shows low variation / poor rank: you need calibration points
%   spanning a real RANGE of Mach number and angle-of-attack/sideslip
%   (abFact) -- e.g. a speed-varying maneuver, or multiple flights at
%   different conditions -- not just one steady segment.
%
% See also: checkFcalcConditioning, runCalibrationFit, fcalc

pa = Z.DPA; pb = Z.DPB; pr = Z.DPR; dp1 = Z.DP1; psm = Z.PSA; mr = Z.mr;

tax = tanAlpha(pa, pb, pr);
tbx = tanBeta(pb, pr);
abFact = 1 + tax.^2 + tbx.^2;
qx0 = impactPcalc(dp1, pa, pb, pr);
fqx = fqCalc(pa, pb, pr);

f0 = 1.68 .* ones(size(dp1));
pErr = fqx./f0 - qx0;
onez = ones(size(psm));
for jj = 1:3
    machn = mach(qx0+pErr, psm-pErr, mr);
    XX = [machn machn.^2 abFact];
    XXf = [onez XX];
    f0 = XXf * x0(:);
    pErr = fqx./f0 - qx0;
end

report = struct();
report.machn_range = [min(machn) max(machn)];
report.machn_std = std(machn);
report.abFact_range = [min(abFact) max(abFact)];
report.abFact_std = std(abFact);
report.XXf_rank = rank(XXf);
report.XXf_cond = cond(XXf);
report.nPoints = numel(dp1);

fprintf('checkPredictorVariation (n=%d points):\n', report.nPoints);
fprintf('  machn:  range [%.4g, %.4g], std = %.4g\n', report.machn_range(1), report.machn_range(2), report.machn_std);
fprintf('  abFact: range [%.4g, %.4g], std = %.4g\n', report.abFact_range(1), report.abFact_range(2), report.abFact_std);
fprintf('  XXf = [1, machn, machn^2, abFact]: rank = %d (of 4), condition number = %.4g\n', ...
    report.XXf_rank, report.XXf_cond);

if report.XXf_rank < 4
    fprintf('  WARNING: XXf is RANK-DEFICIENT -- betaf is not uniquely identifiable from this data.\n');
elseif report.XXf_cond > 1e6
    fprintf('  WARNING: XXf is very ill-conditioned -- betaf is poorly identifiable; expect an unstable/stalled fit.\n');
end
if report.machn_std < 1e-3
    fprintf('  WARNING: machn barely varies across these points -- looks like a single near-steady flight condition.\n');
end

end
