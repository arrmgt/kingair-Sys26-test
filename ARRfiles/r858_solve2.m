function out = r858_solve2(ptb, psa, dpa, dpb, dpr, dpn, f, pkor, sigma, alpha)
%R858_SOLVE2  Reformulated Rosemount 858 solve: unknowns [q, ta, tb], with
%f and pkor now KNOWN (unlike r858_solve.m, where fq was one unknown and
%pkor was unresolvable). dp1 is computed internally as dp1 = ptb - psa,
%with its uncertainty propagated from sigma_ptb and sigma_psa. Fully
%vectorized for time-series/batch inputs.
%
%   out = R858_SOLVE2(ptb, psa, dpa, dpb, dpr, dpn, f, pkor, sigma, alpha)
%
%   INPUTS (each scalar, or all the same size, e.g. Nx1 time series)
%     ptb, psa                 Raw pressures; dp1 = ptb - psa internally
%     dpa, dpb, dpr, dpn        Measured differential pressures. SENSOR
%                                DROPOUT: set dpr==0 (exactly) to flag DPR
%                                as out for a row, or dpn==0 for DPN - the
%                                solver falls back to the cross-relation
%                                ta/tb=dpa/dpb for the affected variable
%                                and drops to a 2-way GLS for q (dof 2->1).
%                                Both out simultaneously is unrecoverable
%                                and forced to NaN (ta, tb are too central
%                                to the wind calc to return a low-confidence
%                                guess). Do NOT use 0 for dpa/dpb dropout -
%                                not handled (that removes the cross-relation
%                                itself, a more severe failure mode).
%     f, pkor                   Now KNOWN (previously fq and pkor were the
%                                unresolvable unknowns; see NOTE below)
%
%   sigma   1-sigma measurement uncertainty, for [ptb psa dpa dpb dpr dpn f pkor]
%           in that order. Accepted forms:
%             - scalar: same sigma applied to ptb,psa,dpa,dpb,dpr,dpn; f,pkor
%               treated as exact (sigma 0)
%             - 8-element vector [sig_ptb sig_psa sig_dpa sig_dpb sig_dpr sig_dpn sig_f sig_pkor]
%             - struct with fields ptb,psa,dpa,dpb,dpr,dpn (required) and
%               f,pkor (optional, default 0)
%
%   alpha   significance level for the CI (default 0.05, i.e. 95% CI).
%
%   OUTPUT  out (struct; numeric fields sized like the inputs)
%     out.dp1   = ptb - psa (returned for convenience/inspection)
%     out.dp1_SE  propagated from sigma_ptb, sigma_psa (independent errors
%                 assumed: var(dp1) = var(ptb) + var(psa))
%     out.ta, out.ta_SE, out.ta_CI     thermal factor ta and its CI
%     out.tb, out.tb_SE, out.tb_CI     thermal factor tb and its CI
%     out.q,  out.q_SE,  out.q_CI      flow-related unknown q and its CI
%     out.diag.q_estimates   N x 3, the 3 independent q estimates that
%                            get combined: [q_eq1, q_aside, q_bside]
%     out.diag.chi2, out.diag.dof, out.diag.pvalue
%                            chi-square consistency test of the q
%                            estimates that were actually combined for
%                            that row (properly accounting for their
%                            mutual correlation - they share ta_hat/tb_hat).
%                            dof is per-row: 2 normally, 1 if DPR or DPN
%                            is out for that row, 0 (pvalue = NaN) if both
%                            are out.
%     out.diag.dprOut, out.diag.dpnOut   logical flags, per row
%
%   DEGREES OF FREEDOM
%   Promoting f and pkor from unknowns to knowns changes the count. There
%   are still 5 governing equations and now only 3 unknowns (q, ta, tb):
%       dof = 5 equations - 3 unknowns = 2
%   Concretely: eqs (dpb-eq, dpr-eq) share only ta,tb,f,q and turn out to
%   depend on tb ALONE once f*q is eliminated between them (D cancels) -
%   an exact quadratic in tb, using only dpb, dpr. Symmetrically, (dpa-eq,
%   dpn-eq) reduce to an exact quadratic in ta alone, using only dpa, dpn.
%   Both quadratics have 2 roots; this function uses the same root you
%   specified (the "+sqrt" branch in your formulas). The other root is
%   given in the NOTE below in case the "+" branch turns out not to be
%   the physically reasonable one.
%   That fully consumes 4 of the 5 equations with ZERO leftover degrees
%   of freedom for ta, tb individually (each pair is exactly, not
%   approximately, solved) - so ta, tb get NO fit-residual-based SE, only
%   delta-method-propagated SE from the measurement sigmas of dpa/dpb/dpr/dpn.
%   The 5th equation (the original eq. 1, now usable because pkor is
%   known) plus the already-solved ta, tb give a 3rd, independent route to
%   q: so q is over-determined 3 ways (from eq.1, from the dpa/dpn pair,
%   from the dpb/dpr pair) with only 1 unknown -> dof = 3 - 1 = 2,
%   matching the global count above. Those 3 estimates are combined by
%   generalized least squares (GLS) using their full 3x3 covariance
%   (accounting for the fact that all 3 share ta_hat, tb_hat and are
%   therefore correlated, not independent) - the chi-square test on the
%   GLS residuals has 2 degrees of freedom. Introducing dp1 = ptb - psa
%   does not change this count: it is a linear substitution of one known
%   quantity for two, not a new equation on the unknowns.
%
%   NOTE - OTHER ROOT
%   tb_other = -(dpb + 2*dpr + sqrt(2*dpb.^2+4*dpb.*dpr+4*dpr.^2)) ./ dpb;
%   ta_other = -(dpa + 2*dpn + sqrt(2*dpa.^2+4*dpa.*dpn+4*dpn.^2)) ./ dpa;

if nargin < 10 || isempty(alpha)
    alpha = 0.05;
end

% --- accept sigma as scalar, 8-vector, or struct ---
if isstruct(sigma)
    sigma = normalize_sigma_struct_(sigma, 'r858_solve2');
elseif isscalar(sigma)
    sigma = struct('ptb',sigma,'psa',sigma,'dpa',sigma,'dpb',sigma,'dpr',sigma,'dpn',sigma);
elseif numel(sigma) == 8
    sigma = struct('ptb',sigma(1),'psa',sigma(2),'dpa',sigma(3),'dpb',sigma(4), ...
                    'dpr',sigma(5),'dpn',sigma(6),'f',sigma(7),'pkor',sigma(8));
else
    error('r858_solve2:sigmaFormat', ...
        'sigma must be a struct, a scalar, or an 8-vector [ptb psa dpa dpb dpr dpn f pkor].');
end
if ~isfield(sigma,'f'),    sigma.f    = 0; end
if ~isfield(sigma,'pkor'), sigma.pkor = 0; end
req = {'ptb','psa','dpa','dpb','dpr','dpn'};
for i = 1:numel(req)
    if ~isfield(sigma, req{i})
        error('r858_solve2:missingSigma', 'sigma.%s is required (case-insensitive; also accepts fcoef/pcor for f/pkor).', req{i});
    end
end

sz = size(ptb);
n = numel(ptb);

ptb = expand_(ptb,n); psa = expand_(psa,n); dpa = expand_(dpa,n); dpb = expand_(dpb,n);
dpr = expand_(dpr,n); dpn = expand_(dpn,n);
f    = expand_(f,n);    pkor = expand_(pkor,n);
s = struct();
s.ptb  = expand_(sigma.ptb,n);  s.psa = expand_(sigma.psa,n);
s.dpa  = expand_(sigma.dpa,n);  s.dpb = expand_(sigma.dpb,n);
s.dpr  = expand_(sigma.dpr,n);  s.dpn = expand_(sigma.dpn,n);
s.f    = expand_(sigma.f,n);    s.pkor = expand_(sigma.pkor,n);

z = sqrt(2)*erfinv(1-alpha);

nIn = 8; % ptb, psa, dpa, dpb, dpr, dpn, f, pkor

% ---- sensor dropout detection: dpr==0 or dpn==0 (exactly) flags that
% channel as out for the row. See raw_to_ests_ for how ta/tb fall back to
% the cross-relation; below, the q-combination step switches from 3-way
% to 2-way GLS accordingly. Both out simultaneously is treated as
% unrecoverable (ta, tb are central to the downstream 3-D wind
% calculation - not something to return a low-confidence guess for) and
% forced to NaN.
dropTol = 1e-12;
dprOut = abs(dpr) < dropTol;
dpnOut = abs(dpn) < dropTol;
bothOut = dprOut & dpnOut;
onlyDprOut = dprOut & ~dpnOut;
onlyDpnOut = dpnOut & ~dprOut;
if any(bothOut)
    warning('r858_solve2:bothDropout', ...
        '%d of %d row(s) have both DPR and DPN out simultaneously - ta, tb, q are not recoverable and are returned as NaN for those rows.', ...
        sum(bothOut), numel(bothOut));
end
dofRow = 2 - double(dprOut) - double(dpnOut);   % 2 normally, 1 with one channel out, 0 with both (forced NaN)

% ---- nominal point estimates ----
[dp1, ta, tb, Y] = raw_to_ests_(ptb,psa,dpa,dpb,dpr,dpn,f,pkor);   % Y = [q_eq1, q_aside, q_bside]

% ---- Jacobians of dp1, ta, tb, and Y(:,1:3) wrt the 8 raw inputs (vectorized) ----
inputs  = {ptb, psa, dpa, dpb, dpr, dpn, f, pkor};
sigmas8 = {s.ptb, s.psa, s.dpa, s.dpb, s.dpr, s.dpn, s.f, s.pkor};

var_dp1 = zeros(n,1);
var_ta = zeros(n,1); var_tb = zeros(n,1);
Jq = zeros(n,3,nIn);  % dY(:,k)/d(input i)
for i = 1:nIn
    h = 1e-6 * max(1, abs(inputs{i}));
    argsP = inputs; argsP{i} = inputs{i} + h;
    argsN = inputs; argsN{i} = inputs{i} - h;
    [dp1P,taP,tbP,YP] = raw_to_ests_(argsP{:});
    [dp1N,taN,tbN,YN] = raw_to_ests_(argsN{:});
    ddp1 = (dp1P-dp1N)./(2*h);
    dta  = (taP-taN)./(2*h);
    dtb  = (tbP-tbN)./(2*h);
    dY   = (YP-YN)./(2*h);
    var_dp1 = var_dp1 + (ddp1.^2).*(sigmas8{i}.^2);
    var_ta  = var_ta  + (dta.^2 ).*(sigmas8{i}.^2);
    var_tb  = var_tb  + (dtb.^2 ).*(sigmas8{i}.^2);
    Jq(:,:,i) = dY;
end
dp1_SE = sqrt(var_dp1);   % should reduce to sqrt(sigma_ptb^2 + sigma_psa^2)
ta_SE  = sqrt(var_ta);
tb_SE  = sqrt(var_tb);

% ---- covariance of the 3 q-estimates: C = Jq * diag(sigma^2) * Jq' (per sample) ----
sig2 = zeros(n,nIn);
for i = 1:nIn
    sig2(:,i) = sigmas8{i}.^2;
end
a = zeros(n,1); b = zeros(n,1); c = zeros(n,1);
d = zeros(n,1); e = zeros(n,1); g = zeros(n,1);  % symmetric C = [a b c; b d e; c e g]
for i = 1:nIn
    J1 = Jq(:,1,i); J2 = Jq(:,2,i); J3 = Jq(:,3,i);
    w  = sig2(:,i);
    a = a + J1.*J1.*w;
    b = b + J1.*J2.*w;
    c = c + J1.*J3.*w;
    d = d + J2.*J2.*w;
    e = e + J2.*J3.*w;
    g = g + J3.*J3.*w;
end

% ---- combine the q-estimates via GLS. Normally all 3 (q_eq1, q_aside,
% q_bside) are independent-enough and combined with the full 3x3
% covariance. But when DPR is out, q_bside is NOT independent info (it
% reduces algebraically to a rescaling of q_aside, since tb was itself
% derived from the cross-relation using ta) - so those rows use a 2-way
% GLS of just (q_eq1, q_aside). Symmetrically for DPN out, using
% (q_eq1, q_bside). Both-out rows are forced to NaN.

% -- 3-way (normal rows) --
detC = a.*d.*g - a.*e.^2 - b.^2.*g + 2*b.*c.*e - c.^2.*d;
inv11 = (d.*g - e.^2)   ./ detC;
inv22 = (a.*g - c.^2)   ./ detC;
inv33 = (a.*d - b.^2)   ./ detC;
inv12 = (c.*e - b.*g)   ./ detC;
inv13 = (b.*e - c.*d)   ./ detC;
inv23 = (b.*c - a.*e)   ./ detC;
w1_3 = inv11 + inv12 + inv13;
w2_3 = inv12 + inv22 + inv23;
w3_3 = inv13 + inv23 + inv33;
wsum_3 = w1_3 + w2_3 + w3_3;
q_hat_3 = (w1_3.*Y(:,1) + w2_3.*Y(:,2) + w3_3.*Y(:,3)) ./ wsum_3;
var_q_3 = 1 ./ wsum_3;
r1 = Y(:,1) - q_hat_3; r2 = Y(:,2) - q_hat_3; r3 = Y(:,3) - q_hat_3;
chi2_3 = inv11.*r1.^2 + inv22.*r2.^2 + inv33.*r3.^2 ...
       + 2*inv12.*r1.*r2 + 2*inv13.*r1.*r3 + 2*inv23.*r2.*r3;

% -- 2-way using columns (q_eq1, q_aside) = (1,2) -- for DPR-out rows
det12 = a.*d - b.^2;
inv11_2 = d./det12; inv22_2 = a./det12; inv12_2 = -b./det12;
w1_12 = inv11_2 + inv12_2; w2_12 = inv12_2 + inv22_2;
wsum_12 = w1_12 + w2_12;
q_hat_12 = (w1_12.*Y(:,1) + w2_12.*Y(:,2)) ./ wsum_12;
var_q_12 = 1 ./ wsum_12;
r1b = Y(:,1) - q_hat_12; r2b = Y(:,2) - q_hat_12;
chi2_12 = inv11_2.*r1b.^2 + inv22_2.*r2b.^2 + 2*inv12_2.*r1b.*r2b;

% -- 2-way using columns (q_eq1, q_bside) = (1,3) -- for DPN-out rows
det13 = a.*g - c.^2;
inv11_3 = g./det13; inv33_3 = a./det13; inv13_3 = -c./det13;
w1_13 = inv11_3 + inv13_3; w3_13 = inv13_3 + inv33_3;
wsum_13 = w1_13 + w3_13;
q_hat_13 = (w1_13.*Y(:,1) + w3_13.*Y(:,3)) ./ wsum_13;
var_q_13 = 1 ./ wsum_13;
r1c = Y(:,1) - q_hat_13; r3c = Y(:,3) - q_hat_13;
chi2_13 = inv11_3.*r1c.^2 + inv33_3.*r3c.^2 + 2*inv13_3.*r1c.*r3c;

% -- select per row --
normalRow = ~dprOut & ~dpnOut;
q_hat = q_hat_3; var_q = var_q_3; chi2 = chi2_3;
q_hat(onlyDprOut) = q_hat_12(onlyDprOut); var_q(onlyDprOut) = var_q_12(onlyDprOut); chi2(onlyDprOut) = chi2_12(onlyDprOut);
q_hat(onlyDpnOut) = q_hat_13(onlyDpnOut); var_q(onlyDpnOut) = var_q_13(onlyDpnOut); chi2(onlyDpnOut) = chi2_13(onlyDpnOut);
q_hat(bothOut) = NaN; var_q(bothOut) = NaN; chi2(bothOut) = NaN;
ta(bothOut) = NaN; tb(bothOut) = NaN;   % ta,tb from raw_to_ests_'s 0-fallback aren't trustworthy either
ta_SE(bothOut) = NaN; tb_SE(bothOut) = NaN;

chi2 = max(chi2, 0);
q_SE  = sqrt(var_q);

dof = dofRow;
pval = nan(n,1);
hasDof = dof > 0;
pval(hasDof) = 1 - gammainc(chi2(hasDof)/2, dof(hasDof)/2);

out.dp1    = reshape(dp1,sz);
out.dp1_SE = reshape(dp1_SE,sz);
out.ta    = reshape(ta,sz);
out.ta_SE = reshape(ta_SE,sz);
out.ta_CI = [ta - z*ta_SE, ta + z*ta_SE];
out.tb    = reshape(tb,sz);
out.tb_SE = reshape(tb_SE,sz);
out.tb_CI = [tb - z*tb_SE, tb + z*tb_SE];
out.q     = reshape(q_hat,sz);
out.q_SE  = reshape(q_SE,sz);
out.q_CI  = [q_hat - z*q_SE, q_hat + z*q_SE];
out.diag.q_estimates = Y;   % columns: [q_eq1, q_aside, q_bside] (q_bside/q_aside not
                            % independent on DPR-out/DPN-out rows respectively - see notes)
out.diag.chi2   = reshape(chi2,sz);
out.diag.dof    = reshape(dof,sz);   % per-row: 2 normally, 1 if DPR or DPN out, 0 if both (forced NaN)
out.diag.pvalue = reshape(pval,sz);
out.diag.dprOut = reshape(dprOut,sz);
out.diag.dpnOut = reshape(dpnOut,sz);
out.notes = ['dof = 2 per row normally (5 equations, 3 unknowns [q,ta,tb]). dp1 = ptb - psa, ', ...
    'propagated into dp1_SE. ta,tb solved exactly from (dpa,dpn) and (dpb,dpr) ', ...
    'pairs respectively (+ sqrt branch); q is GLS-combined from 3 correlated ', ...
    'estimates: eq.1 (via dp1), the a-side pair, and the b-side pair. Set DPR==0 or ', ...
    'DPN==0 (exactly) to flag that sensor as out for a row - the affected shape variable ', ...
    'falls back to the cross-relation ta/tb=dpa/dpb and q drops to a 2-way GLS combination ', ...
    '(dof -> 1). Both out simultaneously is treated as unrecoverable and forced to NaN ', ...
    '(see out.diag.dprOut/dpnOut).'];

end

% ------------------------------------------------------------------
function out = normalize_sigma_struct_(sigma, errId)
% Accepts a sigma struct with field names in any case, and additionally
% recognizes 'fcoef' as an alias for 'f' and 'pcor' as an alias for
% 'pkor' (matching common workspace naming, e.g. sigma.PTB, sigma.fcoef,
% sigma.pcor). Unrecognized fields are ignored with a warning.
fn = fieldnames(sigma);
out = struct();
for i = 1:numel(fn)
    name = lower(fn{i});
    val = sigma.(fn{i});
    switch name
        case 'ptb',  out.ptb  = val;
        case 'psa',  out.psa  = val;
        case 'dpa',  out.dpa  = val;
        case 'dpb',  out.dpb  = val;
        case 'dpr',  out.dpr  = val;
        case 'dpn',  out.dpn  = val;
        case {'f','fcoef'},    out.f    = val;
        case {'pkor','pcor'},  out.pkor = val;
        otherwise
            warning([errId ':unknownSigmaField'], ...
                'Ignoring unrecognized sigma field "%s".', fn{i});
    end
end
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
function [dp1, ta, tb, Y] = raw_to_ests_(ptb,psa,dpa,dpb,dpr,dpn,f,pkor)
% All inputs N x 1. Returns dp1, ta, tb (N x 1) and Y = [q_eq1 q_aside q_bside] (N x 3).
%
% SENSOR DROPOUT: dpr==0 or dpn==0 (exactly) flags that channel as out
% for a row. The affected shape variable (tb for dpr, ta for dpn) is then
% reconstructed via the cross-relation ta/tb = dpa/dpb instead of its own
% (now invalid) direct formula. q_bside/q_aside are still computed for
% every row for array-shape consistency, but the caller MUST NOT use the
% one on the dropped-out side directly - see the main function body,
% which switches to a 2-estimate GLS combination for those rows instead
% of blindly averaging in a non-independent (or, for the both-out case,
% flat-out wrong) 3rd value.

dp1 = ptb - psa;

% NUMERICALLY STABLE form. The direct formula tb =
% -(dpb+2*dpr-sqrt(2*dpb^2+4*dpb*dpr+4*dpr^2))/dpb subtracts two nearly
% equal quantities whenever dpb is small relative to dpr (near-zero-flow
% samples), causing catastrophic cancellation - this can produce huge
% spurious outliers (seen in practice up to ~1e83). The two roots of the
% underlying quadratic multiply to exactly -1, so instead we compute the
% other (large, sum-based, cancellation-free) root and take its
% reciprocal - mathematically identical, numerically robust down to
% dpb/dpa ~ 1e-15 (verified against a high-precision reference).
tinyTol = 1e-12;

dprOut = abs(dpr) < tinyTol;
dpnOut = abs(dpn) < tinyTol;
bothOut = dprOut & dpnOut;

tb_big = -(dpb + 2*dpr + sqrt(2*dpb.^2 + 4*dpb.*dpr + 4*dpr.^2)) ./ dpb;
tb_direct = -1 ./ tb_big;
tb_direct(abs(dpb) < tinyTol) = 0;

ta_big = -(dpa + 2*dpn + sqrt(2*dpa.^2 + 4*dpa.*dpn + 4*dpn.^2)) ./ dpa;
ta_direct = -1 ./ ta_big;
ta_direct(abs(dpa) < tinyTol) = 0;

ta = ta_direct;
tb = tb_direct;

onlyDprOut = dprOut & ~dpnOut;
tb(onlyDprOut) = (dpb(onlyDprOut)./dpa(onlyDprOut)) .* ta_direct(onlyDprOut);

onlyDpnOut = dpnOut & ~dprOut;
ta(onlyDpnOut) = (dpa(onlyDpnOut)./dpb(onlyDpnOut)) .* tb_direct(onlyDpnOut);

ta(bothOut) = 0;
tb(bothOut) = 0;

D = 1 + ta.^2 + tb.^2;

% q from eq.1 (now solvable since pkor, f are known)
q_eq1 = (dp1 + pkor).*D ./ (D.*(1-f) + f);

% q_bside, q_aside: computed for every row (with safe denominators so a
% both-out fallback ta=tb=0 doesn't throw spurious divide-by-zero
% warnings), but only meaningful/independent on rows where the
% corresponding sensor is NOT out - the caller excludes them otherwise.
tbSafe = tb; tbSafe(abs(tbSafe)<tinyTol) = tinyTol;
taSafe = ta; taSafe(abs(taSafe)<tinyTol) = tinyTol;

qb1 = dpb.*D ./ (2*f.*tbSafe);
qb2 = 2*dpr.*D ./ (f.*(1 - 2*tb - tb.^2));
q_bside = (qb1 + qb2) / 2;

qa1 = dpa.*D ./ (2*f.*taSafe);
qa2 = 2*dpn.*D ./ (f.*(1 - 2*ta - ta.^2));
q_aside = (qa1 + qa2) / 2;

Y = [q_eq1, q_aside, q_bside];
end
