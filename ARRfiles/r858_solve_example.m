%% Example usage of r858_solve.m
% The values below are a self-consistent synthetic case (fq_true=0.4,
% u_true=1.3, ta=0.05, tb=0.04) so the chi-square diagnostic reads
% sensibly (p near 1, i.e. the 4 redundant equations agree). Replace all
% of these with your real measurements.

dp1a = 1.298367;
dpa  = 0.039837;
dpb  = 0.031869;
dpr  = 0.182930;
dpra = 0.178767;
ta   = 0.05;
tb   = 0.04;

% 1-sigma measurement uncertainties (same units as the measurements above)
sigma.dp1a = 0.0010;
sigma.dpa  = 0.0005;
sigma.dpb  = 0.0005;
sigma.dpr  = 0.0004;
sigma.dpra = 0.0004;
sigma.ta   = 0.001;   % optional; omit/set 0 if ta,tb are exact
sigma.tb   = 0.001;

alpha = 0.05;  % 95% CI

out = r858_solve(dp1a, dpa, dpb, dpr, dpra, ta, tb, sigma, alpha);

fprintf('fq = %.6g   95%% CI [%.6g, %.6g]\n', out.fq, out.fq_CI(1), out.fq_CI(2));
fprintf('u = q - pkor = %.6g   95%% CI [%.6g, %.6g]\n', out.u, out.u_CI(1), out.u_CI(2));
fprintf('\nPer-equation fq estimates (dpb, dpa, dpr, dpra):\n');
disp(out.diag.fq_estimates);
fprintf('Chi-square consistency check: chi2 = %.4g, dof = %d, p = %.4g\n', ...
    out.diag.chi2, out.diag.dof, out.diag.pvalue);
fprintf('(low p-value => the 4 redundant sensors disagree more than their sigmas predict)\n');

% If you later obtain pkor from calibration, e.g. pkor = 0:
q_est = out.q_given_pkor(0);
fprintf('\nExample: if pkor = 0, q = %.6g\n', q_est);

disp(out.notes);
