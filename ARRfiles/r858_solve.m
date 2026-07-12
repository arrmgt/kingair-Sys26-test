function out = r858_solve(dp1a, dpa, dpb, dpr, dpra, ta, tb, sigma, alpha)
%R858_SOLVE  Solve the Rosemount 858 thermal-correction equations for fq
%and the identifiable combination u = q - pkor, with confidence intervals.
%Fully vectorized: dp1a,dpa,dpb,dpr,dpra,ta,tb may be scalars or equal-size
%vectors (e.g. a whole time series), and the whole batch is processed
%without a per-sample loop.
%
%   out = R858_SOLVE(dp1a, dpa, dpb, dpr, dpra, ta, tb, sigma, alpha)
%
%   INPUTS (each scalar, or all the same size, e.g. Nx1 time series)
%     dp1a, dpa, dpb, dpr, dpra   Measured differential pressures
%     ta, tb                      Known thermal-expansion factors
%
%   sigma   1-sigma measurement uncertainty. Three forms are accepted:
%     (a) a plain scalar - applied as the same sigma to dp1a, dpa, dpb,
%         dpr, dpra; ta and tb are then treated as exact (sigma 0).
%     (b) a 5-element vector [sigma_dp1a sigma_dpa sigma_dpb sigma_dpr
%         sigma_dpra] - one sigma per pressure channel, in that fixed
%         order (matching the function's own input order); ta, tb exact.
%         This is the form to use when each input has its own sigma:
%             r858_solve(DP1,DPA,DPB,DPR,DPN,TA,TB, ...
%                        [0.010 0.005 0.005 0.004 0.004], 0.05)
%     (c) a 7-element vector, same as (b) plus [sigma_ta sigma_tb]
%         appended, if ta/tb also have uncertainty.
%     (d) a struct with required fields dp1a, dpa, dpb, dpr, dpra and
%         optional fields ta, tb (default 0). Each field may be a scalar
%         or a vector matching the input size, e.g.:
%             sigma.dp1a=0.01; sigma.dpa=0.005; sigma.dpb=0.005;
%             sigma.dpr=0.004; sigma.dpra=0.004; sigma.ta=0.001; sigma.tb=0.001;
%
%   alpha   significance level for the confidence interval, e.g. 0.05 for
%           a 95% CI (default 0.05).
%
%   OUTPUT  out (struct; every numeric field is the same size as the inputs)
%     out.fq        weighted-least-squares estimate of fq
%     out.fq_SE     standard error of fq
%     out.fq_CI     [lo hi], N x 2, confidence interval on fq
%     out.u         estimate of u = q - pkor  (see NOTE below)
%     out.u_SE      standard error of u
%     out.u_CI      [lo hi], N x 2, confidence interval on u
%     out.q_given_pkor   function handle: q    = u + pkor, given known pkor
%     out.pkor_given_q   function handle: pkor = q - u,    given known q
%     out.diag.fq_estimates    N x 4, individual fq estimate per redundant
%                              equation (columns: from dpb, dpa, dpr, dpra)
%     out.diag.chi2, out.diag.dof, out.diag.pvalue
%                              chi-square consistency test across the 4
%                              redundant fq equations, per sample. A small
%                              p-value means the sensors disagree by more
%                              than their stated sigmas predict (possible
%                              fault, or mis-specified sigma).
%
%   NOTE ON IDENTIFIABILITY
%   The 5 governing equations (MATLAB Symbolic Toolbox form) are:
%     (1) fq*(ta^2+tb^2) + (dp1a+pkor)*(ta^2+tb^2+1) == q*(ta^2+tb^2+1)
%     (2) 2*fq*tb  == dpb *(ta^2+tb^2+1)
%     (3) 2*fq*ta  == dpa *(ta^2+tb^2+1)
%     (4) 2*dpr *(1+ta^2+tb^2) == fq*(1 - 2*tb - tb^2)
%     (5) 2*dpra*(1+ta^2+tb^2) == fq*(1 - 2*ta - ta^2)
%   In eq. (1), q and pkor multiply (ta^2+tb^2+1) with exactly opposite
%   sign, and neither appears in any other equation. That makes the
%   [q, pkor] part of the system rank-1: only u = q - pkor is determined,
%   never q and pkor individually (adding more dp_ia/pkor_i pairs of the
%   same structural form does not fix this - see chat discussion). Eqs.
%   (2)-(5) give four independent, over-determined estimates of the same
%   scalar fq (from dpb, dpa, dpr, dpra respectively) - that redundancy is
%   what the least-squares fit and chi-square test below make use of.
%
%   METHOD
%   fq is estimated by inverse-variance weighted least squares combining
%   the 4 redundant equations, weighted by the propagated sigmas of dpb,
%   dpa, dpr, dpra (scaled by D = 1+ta^2+tb^2). All 7 input uncertainties
%   (including dp1a, ta, tb) are then propagated into fq and u via a
%   first-order delta-method Taylor expansion, using a vectorized
%   (central-difference) Jacobian of [fq; u] with respect to the 7
%   inputs, computed for the whole batch in one pass (no per-sample
%   loop). Since the assumed-independent input errors give a diagonal
%   input covariance, Var(y_i) = sum_j J(i,j)^2 * sigma_j^2 elementwise.
%   CIs assume approximately Gaussian errors: y +/- z*SE,
%   z = sqrt(2)*erfinv(1-alpha).

if nargin < 9 || isempty(alpha)
    alpha = 0.05;
end

% --- accept sigma as a plain scalar, a 5- or 7-element vector, or a struct ---
if ~isstruct(sigma)
    if isscalar(sigma)
        sigma = struct('dp1a',sigma,'dpa',sigma,'dpb',sigma,'dpr',sigma,'dpra',sigma);
    elseif numel(sigma) == 5
        sigma = struct('dp1a',sigma(1),'dpa',sigma(2),'dpb',sigma(3), ...
                        'dpr',sigma(4),'dpra',sigma(5));
    elseif numel(sigma) == 7
        sigma = struct('dp1a',sigma(1),'dpa',sigma(2),'dpb',sigma(3), ...
                        'dpr',sigma(4),'dpra',sigma(5),'ta',sigma(6),'tb',sigma(7));
    else
        error('r858_solve:sigmaFormat', ['sigma must be a struct, a scalar, a 5-vector ', ...
            '[dp1a dpa dpb dpr dpra], or a 7-vector [dp1a dpa dpb dpr dpra ta tb].']);
    end
end
if ~isfield(sigma,'ta'), sigma.ta = 0; end
if ~isfield(sigma,'tb'), sigma.tb = 0; end

req = {'dp1a','dpa','dpb','dpr','dpra'};
for i = 1:numel(req)
    if ~isfield(sigma, req{i})
        error('r858_solve:missingSigma', 'sigma.%s is required.', req{i});
    end
end

sz = size(dp1a);
n = numel(dp1a);

dp1a = expand_(dp1a,n); dpa = expand_(dpa,n); dpb = expand_(dpb,n);
dpr  = expand_(dpr ,n); dpra = expand_(dpra,n);
ta   = expand_(ta  ,n); tb   = expand_(tb  ,n);
s_dp1a = expand_(sigma.dp1a,n); s_dpa = expand_(sigma.dpa,n);
s_dpb  = expand_(sigma.dpb ,n); s_dpr = expand_(sigma.dpr,n);
s_dpra = expand_(sigma.dpra,n); s_ta  = expand_(sigma.ta ,n);
s_tb   = expand_(sigma.tb  ,n);

z = sqrt(2)*erfinv(1-alpha);

% ---- point estimate at the nominal measurements (vectorized, N x 1) ----
[fq, u, fqEst, chi2, pval] = point_estimate_vec_(dp1a,dpa,dpb,dpr,dpra,ta,tb, ...
    s_dpb,s_dpa,s_dpr,s_dpra);

% ---- delta-method Jacobian of [fq,u] wrt the 7 inputs (vectorized) ----
inputs  = {dp1a, dpa, dpb, dpr, dpra, ta, tb};
sigmas7 = {s_dp1a, s_dpa, s_dpb, s_dpr, s_dpra, s_ta, s_tb};

var_fq = zeros(n,1);
var_u  = zeros(n,1);
for i = 1:7
    h = 1e-6 * max(1, abs(inputs{i}));
    argsP = inputs; argsP{i} = inputs{i} + h;
    argsN = inputs; argsN{i} = inputs{i} - h;
    [fqP, uP] = point_estimate_vec_(argsP{:}, s_dpb,s_dpa,s_dpr,s_dpra);
    [fqN, uN] = point_estimate_vec_(argsN{:}, s_dpb,s_dpa,s_dpr,s_dpra);
    dfq = (fqP - fqN) ./ (2*h);
    du  = (uP  - uN ) ./ (2*h);
    var_fq = var_fq + (dfq.^2) .* (sigmas7{i}.^2);
    var_u  = var_u  + (du.^2)  .* (sigmas7{i}.^2);
end
fq_SE = sqrt(var_fq);
u_SE  = sqrt(var_u);

out.fq    = reshape(fq,sz);
out.fq_SE = reshape(fq_SE,sz);
out.fq_CI = [fq - z*fq_SE, fq + z*fq_SE];
out.u     = reshape(u,sz);
out.u_SE  = reshape(u_SE,sz);
out.u_CI  = [u - z*u_SE, u + z*u_SE];
out.q_given_pkor = @(pkor) out.u + pkor;
out.pkor_given_q = @(q) q - out.u;
out.diag.fq_estimates = fqEst;
out.diag.chi2   = reshape(chi2,sz);
out.diag.dof    = 3;
out.diag.pvalue = reshape(pval,sz);
out.notes = ['q and pkor are NOT separately identifiable from these 5 ', ...
    'equations - only u = q - pkor is determined. Supply pkor to get q ', ...
    '(out.q_given_pkor) or q to get pkor (out.pkor_given_q).'];

end

% ------------------------------------------------------------------
function v = expand_(v, n)
if isscalar(v)
    v = repmat(v, n, 1);
else
    v = v(:);
end
end

% ------------------------------------------------------------------
function [fq, u, fqEst, chi2, pval] = point_estimate_vec_( ...
    dp1a,dpa,dpb,dpr,dpra,ta,tb, sig_dpb,sig_dpa,sig_dpr,sig_dpra)
% All inputs are N x 1 column vectors. Returns N x 1 (fq,u,chi2,pval) and
% N x 4 (fqEst, one column per redundant equation: dpb,dpa,dpr,dpra).

D = ta.^2 + tb.^2 + 1;
T = ta.^2 + tb.^2;

% Coefficients "A" and right-hand sides "b" of the 4 redundant,
% linear-in-fq equations (2),(3),(4),(5):
%   A1*fq = b1   from eq.(2), driven by dpb
%   A2*fq = b2   from eq.(3), driven by dpa
%   A3*fq = b3   from eq.(4), driven by dpr
%   A4*fq = b4   from eq.(5), driven by dpra
A1 = 2*tb;              b1 = dpb.*D;
A2 = 2*ta;              b2 = dpa.*D;
A3 = 1 - 2*tb - tb.^2;  b3 = 2*dpr.*D;
A4 = 1 - 2*ta - ta.^2;  b4 = 2*dpra.*D;

fqEst = [b1./A1, b2./A2, b3./A3, b4./A4];

% Propagated sigma on each b(i):
sigb1 = max(sig_dpb.*D,  eps);
sigb2 = max(sig_dpa.*D,  eps);
sigb3 = max(2*sig_dpr.*D,  eps);
sigb4 = max(2*sig_dpra.*D, eps);
w1 = 1./sigb1.^2; w2 = 1./sigb2.^2; w3 = 1./sigb3.^2; w4 = 1./sigb4.^2;

denom = w1.*A1.^2 + w2.*A2.^2 + w3.*A3.^2 + w4.*A4.^2;
bad = denom < 1e-12;
if any(bad)
    warning('r858_solve:degenerate', ...
        '%d sample(s) have all 4 redundant equations uninformative about fq (A ~ 0 at that ta/tb); returning NaN for those.', ...
        sum(bad));
    denom(bad) = NaN;
end
numer = w1.*A1.*b1 + w2.*A2.*b2 + w3.*A3.*b3 + w4.*A4.*b4;
fq = numer ./ denom;

resid1 = b1 - A1.*fq; resid2 = b2 - A2.*fq;
resid3 = b3 - A3.*fq; resid4 = b4 - A4.*fq;
chi2 = w1.*resid1.^2 + w2.*resid2.^2 + w3.*resid3.^2 + w4.*resid4.^2;
chi2 = max(chi2, 0);
dof = 3;
pval = 1 - gammainc(chi2/2, dof/2);

u = dp1a + fq.*T./D;
end
