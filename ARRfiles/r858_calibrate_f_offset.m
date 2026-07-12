function out = r858_calibrate_f_offset(ptb, psa, dpa, dpb, dpr, dpn, f0, pkor0, sigma, alpha, opts)
%R858_CALIBRATE_F_OFFSET  Single-parameter version of
%r858_calibrate_offsets.m: fits ONLY a global additive delta_f on top of
%your existing per-row f0, holding pkor FIXED at pkor0 (not searched) -
%for use when you derive pkor from f yourself downstream.
%
%   out = R858_CALIBRATE_F_OFFSET(ptb, psa, dpa, dpb, dpr, dpn, f0, pkor0, ...
%                                  sigma, alpha, opts)
%
%   WHY THIS EXISTS (see chat)
%   The joint 2-parameter (delta_f, delta_pkor) fit in
%   r858_calibrate_offsets.m turned out to be poorly conditioned: q_beta's
%   sensitivity to pkor is exactly 1 (dp1+pkor enters it directly), and
%   q_hat's (eq.1-driven) sensitivity to pkor is ALSO close to 1 whenever
%   D=1+ta^2+tb^2 is close to 1 (i.e. whenever ta, tb are small, which is
%   typical) - so a shift in pkor very nearly cancels between q_hat and
%   q_beta almost regardless of f. That leaves a long, shallow, nearly
%   degenerate ridge in the (delta_f, delta_pkor) plane - similar in
%   spirit to the original q/pkor identifiability problem - that an
%   unconstrained 2-D search can slide along to extreme, unphysical
%   values (seen in practice: delta_f driving f from ~1.7 to ~0.04,
%   paired with a delta_pkor of several thousand, chi2 dropping
%   suspiciously far, SE collapsing to 0 - all symptoms of a degenerate
%   fit, not a real calibration signal).
%   Fixing pkor removes that direction entirely. Verified numerically:
%   with pkor held fixed, the 1-D objective (see METHOD) is a clean,
%   unimodal function of delta_f over a wide bounded range - no nearby
%   false minimum - so this is both what you asked for AND the more
%   statistically sound approach.
%
%   INPUTS   same as r858_calibrate_offsets.m, except pkor0 is used as-is
%            (never adjusted) - only delta_f is fit.
%     opts.bounds   [lo hi] additive bounds on delta_f (default:
%                   +/-0.5*median(abs(f0)), i.e. roughly +/-50% of your
%                   typical f magnitude). The search NEVER leaves this
%                   range - if the best fit sits at (or very near) a
%                   bound, out.atBound is true and you should treat the
%                   result as "no interior optimum found within the
%                   search range" rather than a real answer - widen
%                   opts.bounds deliberately and re-check, don't just
%                   trust a boundary hit.
%     opts.nGrid    number of points in the initial coarse scan across
%                   the bounds (default 41) - a global scan, not just a
%                   local search, run BEFORE the local refinement, so a
%                   secondary local minimum elsewhere in range can't trap
%                   the result silently. out.grid holds the raw scan so
%                   you can eyeball the shape yourself.
%     opts.tol      golden-section refinement tolerance on delta_f
%                   (default 1e-8 * the bounds width)
%
%   METHOD
%   Same q_hat (3-way GLS q, depends on f) vs q_beta (exact,
%   f-independent alternative - see r858_calibrate_offsets.m) comparison,
%   but pkor0 is fixed, so q_beta is evaluated once and never changes.
%   Weights are the delta-method-propagated variance of (q_hat-q_beta) at
%   delta_f=0, frozen for the search (same convention as
%   r858_calibrate_offsets.m). A coarse grid scan over opts.bounds finds
%   the neighborhood of the global minimum, then a bounded golden-section
%   search refines it. SE comes from a finite-difference second
%   derivative of the (chi-square-like) objective at the optimum
%   (Cov = 2/Hessian, the 1-D analogue of the 2x2 case).
%
%   OUTPUT
%     out.f_offset, out.f_offset_SE, out.f_offset_CI     delta_f
%     out.f_hat                      f0 + delta_f (per row)
%     out.atBound                    true if the optimum sits at/near a
%                                     search bound - DO NOT trust f_offset
%                                     if this is true; widen opts.bounds
%     out.chi2_before, out.chi2_after, out.dof, out.pvalue
%     out.rms_before, out.rms_after
%     out.grid.df, out.grid.chi2     the coarse scan, for a sanity-check
%                                     plot: plot(out.grid.df, out.grid.chi2)
%     out.excluded                   struct with counts of rows dropped
%                                     (dropout sentinel / zero DPA-DPB /
%                                     other non-finite)
%     out.notes

if nargin < 10 || isempty(alpha)
    alpha = 0.05;
end
if nargin < 11 || isempty(opts)
    opts = struct();
end
if ~isfield(opts,'nGrid'), opts.nGrid = 41;    end
if ~isfield(opts,'tol'),   opts.tol   = [];    end   % filled in after bounds are known

sz = size(ptb); %#ok<NASGU>
n = numel(ptb);

ptb = expand_(ptb,n); psa = expand_(psa,n); dpa = expand_(dpa,n); dpb = expand_(dpb,n);
dpr = expand_(dpr,n); dpn = expand_(dpn,n);
f0    = expand_(f0,n);    pkor0 = expand_(pkor0,n);

if ~isfield(opts,'mask') || isempty(opts.mask)
    mask = true(n,1);
else
    mask = expand_(logical(opts.mask), n);
end

% --- accept sigma as scalar, 8-vector, or struct (same convention as the other r858_* functions) ---
if isstruct(sigma)
    sigma = normalize_sigma_struct_(sigma, 'r858_calibrate_f_offset');
elseif isscalar(sigma)
    sigma = struct('ptb',sigma,'psa',sigma,'dpa',sigma,'dpb',sigma,'dpr',sigma,'dpn',sigma);
elseif numel(sigma) == 8
    sigma = struct('ptb',sigma(1),'psa',sigma(2),'dpa',sigma(3),'dpb',sigma(4), ...
                    'dpr',sigma(5),'dpn',sigma(6),'f',sigma(7),'pkor',sigma(8));
else
    error('r858_calibrate_f_offset:sigmaFormat', ...
        'sigma must be a struct, a scalar, or an 8-vector [ptb psa dpa dpb dpr dpn f pkor].');
end
if ~isfield(sigma,'f'),    sigma.f    = 0; end
if ~isfield(sigma,'pkor'), sigma.pkor = 0; end
req = {'ptb','psa','dpa','dpb','dpr','dpn'};
for i = 1:numel(req)
    if ~isfield(sigma, req{i})
        error('r858_calibrate_f_offset:missingSigma', 'sigma.%s is required.', req{i});
    end
end
s = struct();
s.ptb  = expand_(sigma.ptb,n);  s.psa = expand_(sigma.psa,n);
s.dpa  = expand_(sigma.dpa,n);  s.dpb = expand_(sigma.dpb,n);
s.dpr  = expand_(sigma.dpr,n);  s.dpn = expand_(sigma.dpn,n);
s.f    = expand_(sigma.f,n);    s.pkor = expand_(sigma.pkor,n);

% ---- restrict to the calibration mask ----
ptb=ptb(mask); psa=psa(mask); dpa=dpa(mask); dpb=dpb(mask); dpr=dpr(mask); dpn=dpn(mask);
f0=f0(mask); pkor0=pkor0(mask);
s.ptb=s.ptb(mask); s.psa=s.psa(mask); s.dpa=s.dpa(mask); s.dpb=s.dpb(mask);
s.dpr=s.dpr(mask); s.dpn=s.dpn(mask); s.f=s.f(mask); s.pkor=s.pkor(mask);

z = sqrt(2)*erfinv(1-alpha);

% ---- auto-detect and exclude rows this calibration can't handle: exact
% DPR/DPN dropout sentinels, exact-zero DPA/DPB (ground/static segments -
% a 0/0 in the closed form), or anything else non-finite. See
% r858_calibrate_offsets.m - same rationale (this function also SUMS
% across rows, so one bad row would otherwise poison everything). ----
dropTol = 1e-12;
dprOut  = abs(dpr) < dropTol;
dpnOut  = abs(dpn) < dropTol;
dpaZero = abs(dpa) < dropTol;
dpbZero = abs(dpb) < dropTol;
dp1a0 = (ptb - psa) + pkor0;
qb0 = qbeta_(dp1a0, dpa, dpb, dpr);
r0 = qhat3_(ptb,psa,dpa,dpb,dpr,dpn,f0,pkor0,s) - qb0;
bad = dprOut | dpnOut | dpaZero | dpbZero | ~isfinite(r0);
nDropoutOrZero = sum(dprOut|dpnOut|dpaZero|dpbZero);
nOtherBad = sum(~isfinite(r0) & ~dprOut & ~dpnOut & ~dpaZero & ~dpbZero);
if any(bad)
    warning('r858_calibrate_f_offset:droppedRows', ...
        ['%d of %d row(s) excluded before fitting: %d with a DPR/DPN dropout sentinel (0) or ', ...
         'exact-zero DPA/DPB, %d other non-finite. Pass opts.mask for tighter control.'], ...
        sum(bad), numel(bad), nDropoutOrZero, nOtherBad);
end
keep = ~bad;
if sum(keep) < 10
    error('r858_calibrate_f_offset:tooFewRows', ...
        'Only %d row(s) remain after exclusions - not enough to calibrate.', sum(keep));
end
ptb=ptb(keep); psa=psa(keep); dpa=dpa(keep); dpb=dpb(keep); dpr=dpr(keep); dpn=dpn(keep);
f0=f0(keep); pkor0=pkor0(keep); qb0=qb0(keep);
s.ptb=s.ptb(keep); s.psa=s.psa(keep); s.dpa=s.dpa(keep); s.dpb=s.dpb(keep);
s.dpr=s.dpr(keep); s.dpn=s.dpn(keep); s.f=s.f(keep); s.pkor=s.pkor(keep);
nEff = sum(keep);

out.excluded = struct('dropoutOrZero', nDropoutOrZero, 'otherNonFinite', nOtherBad, 'total', sum(bad));

% ---- one-time weights: delta-method propagation of (q_hat-q_beta)'s
% variance at delta_f=0, frozen for the whole search. ----
inputs8 = {ptb,psa,dpa,dpb,dpr,dpn,f0,pkor0};
sigmas8 = {s.ptb,s.psa,s.dpa,s.dpb,s.dpr,s.dpn,s.f,s.pkor};
var_r = zeros(nEff,1);
for i = 1:8
    h = 1e-6 * max(1, abs(inputs8{i}));
    argsP = inputs8; argsP{i} = inputs8{i} + h;
    argsN = inputs8; argsN{i} = inputs8{i} - h;
    rP = qhat3_(argsP{:}, s) - qbeta_((argsP{1}-argsP{2})+argsP{8}, argsP{3}, argsP{4}, argsP{5});
    rN = qhat3_(argsN{:}, s) - qbeta_((argsN{1}-argsN{2})+argsN{8}, argsN{3}, argsN{4}, argsN{5});
    dr = (rP - rN) ./ (2*h);
    var_r = var_r + (dr.^2) .* (sigmas8{i}.^2);
end
w = 1 ./ max(var_r, eps);

    function val = objective_(df)
        qh = qhat3_(ptb,psa,dpa,dpb,dpr,dpn, f0+df, pkor0, s);
        r = qh - qb0;
        if any(~isfinite(r))
            val = Inf;
        else
            val = sum(w .* r.^2);
        end
    end

chi2_before = objective_(0);

% ---- bounds ----
f0mag = median(abs(f0));
if ~isfield(opts,'bounds') || isempty(opts.bounds)
    lo = -0.5*f0mag; hi = 0.5*f0mag;
else
    lo = opts.bounds(1); hi = opts.bounds(2);
end
if isempty(opts.tol)
    opts.tol = 1e-8*(hi-lo);
end

% ---- coarse global grid scan (avoids a silent local-minimum trap) ----
gridDf = linspace(lo, hi, opts.nGrid)';
gridChi2 = zeros(opts.nGrid,1);
for k = 1:opts.nGrid
    gridChi2(k) = objective_(gridDf(k));
end
[~, bestIdx] = min(gridChi2);
out.grid.df = gridDf;
out.grid.chi2 = gridChi2;

% ---- bounded golden-section refinement, bracketing the best grid point ----
padIdx1 = max(bestIdx-1, 1);
padIdx2 = min(bestIdx+1, opts.nGrid);
[df_hat, chi2_after] = golden_section_(@objective_, gridDf(padIdx1), gridDf(padIdx2), opts.tol, 200);

atBound = (df_hat - lo) < 10*opts.tol || (hi - df_hat) < 10*opts.tol;
out.atBound = atBound;
if atBound
    warning('r858_calibrate_f_offset:atBound', ...
        ['Best-fit delta_f (%.6g) sits at or very near the search bound [%.6g, %.6g] - this ', ...
         'is NOT a well-identified interior optimum. Widen opts.bounds and re-run before ', ...
         'trusting this number.'], df_hat, lo, hi);
end

% ---- SE via 1-D finite-difference second derivative at the optimum ----
hh = max(1e-6, 1e-4*max(abs(df_hat), f0mag));
f00 = chi2_after;
fP = objective_(df_hat+hh);
fM = objective_(df_hat-hh);
H = (fP - 2*f00 + fM) / hh^2;
if H > 0
    df_SE = sqrt(2/H);
else
    df_SE = NaN;
end

dof = nEff - 1;
pval = NaN;
if dof > 0 && isfinite(chi2_after)
    pval = 1 - gammainc(chi2_after/2, dof/2);
end

r_before = qhat3_(ptb,psa,dpa,dpb,dpr,dpn, f0, pkor0, s) - qb0;
r_after  = qhat3_(ptb,psa,dpa,dpb,dpr,dpn, f0+df_hat, pkor0, s) - qb0;

out.f_offset    = df_hat;
out.f_offset_SE = df_SE;
out.f_offset_CI = [df_hat - z*df_SE, df_hat + z*df_SE];
out.f_hat = f0 + df_hat;
out.chi2_before = chi2_before;
out.chi2_after  = chi2_after;
out.dof = dof;
out.pvalue = pval;
out.rms_before = sqrt(mean(r_before.^2));
out.rms_after  = sqrt(mean(r_after.^2));
out.notes = sprintf(['Fit delta_f=%.6g (SE %.3g) over %d rows (dropped %d: %d dropout/zero, ', ...
    '%d other non-finite), dof=%d. RMS(q_hat-q_beta) went from %.4g to %.4g. pkor was held ', ...
    'fixed at your supplied pkor0 throughout - only delta_f was fit. Search bounds were ', ...
    '[%.6g, %.6g]; atBound=%d (if true, do not trust f_offset - widen opts.bounds). Inspect ', ...
    'out.grid.df vs out.grid.chi2 to confirm the minimum is clean and isolated.'], ...
    df_hat, df_SE, nEff, out.excluded.total, nDropoutOrZero, nOtherBad, dof, ...
    out.rms_before, out.rms_after, lo, hi, atBound);

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
function out = normalize_sigma_struct_(sigma, errId)
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
function qb = qbeta_(dp1a, dpa, dpb, dpr)
% Exact, f-independent, dpn-independent closed-form q (see
% r858_calibrate_offsets.m for the derivation).
t2 = dpb.^2;
qb = dp1a - ((t2+dpa.^2).*(dpb+dpr.*2 - sqrt(2).*sqrt(t2+dpb.*dpr.*2+dpr.^2.*2))) ./ (t2.*2);
end

% ------------------------------------------------------------------
function [dp1, ta, tb, Y] = raw_to_ests_(ptb,psa,dpa,dpb,dpr,dpn,f,pkor)
dp1 = ptb - psa;
tb_big = -(dpb + 2*dpr + sqrt(2*dpb.^2 + 4*dpb.*dpr + 4*dpr.^2)) ./ dpb;
tb = -1 ./ tb_big;
ta_big = -(dpa + 2*dpn + sqrt(2*dpa.^2 + 4*dpa.*dpn + 4*dpn.^2)) ./ dpa;
ta = -1 ./ ta_big;
D = 1 + ta.^2 + tb.^2;
q_eq1 = (dp1 + pkor).*D ./ (D.*(1-f) + f);
qb1 = dpb.*D ./ (2*f.*tb);
qb2 = 2*dpr.*D ./ (f.*(1 - 2*tb - tb.^2));
q_bside = (qb1 + qb2) / 2;
qa1 = dpa.*D ./ (2*f.*ta);
qa2 = 2*dpn.*D ./ (f.*(1 - 2*ta - ta.^2));
q_aside = (qa1 + qa2) / 2;
Y = [q_eq1, q_aside, q_bside];
end

% ------------------------------------------------------------------
function qh = qhat3_(ptbv,psav,dpav,dpbv,dprv,dpnv,fv,pkorv,s)
% 3-way GLS combination of [q_eq1,q_aside,q_bside] (same as
% r858_solve2.m/r858_calibrate_offsets.m), Jacobian taken locally at the
% given trial (f,pkor).
[~,~,~,Y] = raw_to_ests_(ptbv,psav,dpav,dpbv,dprv,dpnv,fv,pkorv);
inLoc = {ptbv,psav,dpav,dpbv,dprv,dpnv,fv,pkorv};
nLoc = numel(ptbv);
Jq = zeros(nLoc,3,8);
for k = 1:8
    hk = 1e-6*max(1,abs(inLoc{k}));
    aP = inLoc; aP{k} = inLoc{k}+hk;
    aN = inLoc; aN{k} = inLoc{k}-hk;
    [~,~,~,YP] = raw_to_ests_(aP{:});
    [~,~,~,YN] = raw_to_ests_(aN{:});
    Jq(:,:,k) = (YP-YN)./(2*hk);
end
sig2Loc = [s.ptb.^2, s.psa.^2, s.dpa.^2, s.dpb.^2, s.dpr.^2, s.dpn.^2, s.f.^2, s.pkor.^2];
a=zeros(nLoc,1);b=zeros(nLoc,1);c=zeros(nLoc,1);d=zeros(nLoc,1);e=zeros(nLoc,1);g=zeros(nLoc,1);
for k = 1:8
    J1=Jq(:,1,k); J2=Jq(:,2,k); J3=Jq(:,3,k); ww=sig2Loc(:,k);
    a=a+J1.*J1.*ww; b=b+J1.*J2.*ww; c=c+J1.*J3.*ww;
    d=d+J2.*J2.*ww; e=e+J2.*J3.*ww; g=g+J3.*J3.*ww;
end
detC = a.*d.*g - a.*e.^2 - b.^2.*g + 2*b.*c.*e - c.^2.*d;
inv11=(d.*g-e.^2)./detC; inv22=(a.*g-c.^2)./detC; inv33=(a.*d-b.^2)./detC;
inv12=(c.*e-b.*g)./detC; inv13=(b.*e-c.*d)./detC; inv23=(b.*c-a.*e)./detC;
w1=inv11+inv12+inv13; w2=inv12+inv22+inv23; w3=inv13+inv23+inv33;
wsum=w1+w2+w3;
qh = (w1.*Y(:,1) + w2.*Y(:,2) + w3.*Y(:,3)) ./ wsum;
end

% ------------------------------------------------------------------
function [xbest, fbest] = golden_section_(fun, lo, hi, tol, maxIter)
% Standard bounded golden-section search for a 1-D unimodal minimum on
% [lo,hi]. No Optimization Toolbox dependency.
gr = (sqrt(5)-1)/2;
a = lo; b = hi;
c = b - gr*(b-a);
d = a + gr*(b-a);
fc = fun(c); fd = fun(d);
for it = 1:maxIter
    if abs(b-a) < tol
        break
    end
    if fc < fd
        b = d; d = c; fd = fc;
        c = b - gr*(b-a);
        fc = fun(c);
    else
        a = c; c = d; fc = fd;
        d = a + gr*(b-a);
        fd = fun(d);
    end
end
if fc < fd
    xbest = c; fbest = fc;
else
    xbest = d; fbest = fd;
end
end
