function out = r858_calibrate_offsets(ptb, psa, dpa, dpb, dpr, dpn, f0, pkor0, sigma, alpha, opts)
%R858_CALIBRATE_OFFSETS  First-pass estimate of two GLOBAL additive
%corrections, delta_f and delta_pkor, on top of your existing per-row
%f0/pkor0 model (e.g. your old-airplane curves, which may already vary
%with Mach/flow-angle). This does NOT re-derive f(Mach,alpha)/pkor(Mach,alpha)
%from scratch - it only asks "what single constant shift, added everywhere,
%best reconciles the f,pkor-dependent solution with the f-independent
%q_beta estimate?" A full re-calibration of the functional form of f, pkor
%needs a trailing-cone flight; this is a stopgap that uses the redundancy
%already in your data to flag/correct a level offset.
%
%   out = R858_CALIBRATE_OFFSETS(ptb, psa, dpa, dpb, dpr, dpn, f0, pkor0, ...
%                                 sigma, alpha, opts)
%
%   INPUTS
%     ptb, psa, dpa, dpb, dpr, dpn   Same Nx1 (or scalar) raw measurements
%                                    as r858_solve2/3. This function
%                                    assumes clean data (no DPR/DPN
%                                    dropout) - pre-filter those rows out
%                                    via opts.mask if needed.
%     f0, pkor0                     Your current best-guess f, pkor for
%                                    each row (may vary row-to-row with
%                                    Mach/flow-angle - that variation is
%                                    left alone; only a single constant
%                                    delta_f, delta_pkor is fit on top).
%     sigma                         Same scalar/8-vector/struct convention
%                                    as r858_solve2/3 (required - used to
%                                    weight rows by their propagated
%                                    uncertainty).
%     alpha                         significance level for CI (default 0.05).
%     opts.mask                     logical Nx1, default all-true. Restrict
%                                    the fit to a calibration-quality
%                                    segment (steady, maneuver-free) if you
%                                    have one - turbulence/maneuvering adds
%                                    model error that has nothing to do
%                                    with f, pkor and will bias the fit.
%     opts.maxIter                  outer Nelder-Mead iterations (default 300)
%     opts.tol                      outer convergence tolerance (default 1e-12)
%
%   METHOD
%   Two exact, independent closed-form routes to q are compared:
%     - q_hat: the normal 3-way GLS combination (eq.1, a-side, b-side; same
%       as r858_solve2), which depends on f and pkor.
%     - q_beta: an exact alternative solution using only dp1+pkor, dpa,
%       dpb, dpr (no dpn, and - remarkably - no f at all; f cancels
%       algebraically in this particular combination of equations). It is
%       therefore immune to any error in the assumed f, but NOT immune to
%       error in pkor (dp1+pkor enters it directly).
%   In the noiseless/self-consistent limit these agree exactly, for any
%   f, pkor. With real data, if the ASSUMED f0, pkor0 are off by a
%   constant amount, q_hat and q_beta will disagree systematically. This
%   function searches for the (delta_f, delta_pkor) that minimizes the
%   sigma-weighted sum of squared (q_hat - q_beta) differences across all
%   (masked) rows - a 2-parameter outer search (custom Nelder-Mead simplex,
%   no toolbox needed) around a fast, fully vectorized inner evaluation.
%   Per-row weights are the delta-method-propagated variance of
%   (q_hat - q_beta) at the starting point (df,dp)=(0,0), computed once
%   (frozen), not re-derived every outer iteration - a standard, cheap
%   approximation for this kind of profiled fit.
%
%   This is a SIMPLIFIED calibration: it only uses ONE particular
%   redundant comparison (q_hat vs q_beta), not the full likelihood over
%   all 5*N equations. dof = (number of masked rows) - 2 accordingly. It
%   will catch and correct a constant bias in f0/pkor0; it will NOT catch
%   or fix genuine Mach/flow-angle dependence you don't already have in
%   f0/pkor0 - if the fitted offset is very different across different
%   flight segments/speed regimes, that is itself evidence f, pkor
%   actually vary with condition and a single global offset isn't the
%   right model (see out.notes).
%
%   OUTPUT
%     out.f_offset, out.f_offset_SE, out.f_offset_CI       delta_f
%     out.pkor_offset, out.pkor_offset_SE, out.pkor_offset_CI   delta_pkor
%     out.f_hat, out.pkor_hat        f0+delta_f, pkor0+delta_pkor (per row)
%     out.chi2_before, out.chi2_after   weighted sum of squares of
%                                       (q_hat-q_beta) before/after fitting
%     out.dof, out.pvalue            chi-square consistency test at the fit
%     out.rms_before, out.rms_after  unweighted RMS(q_hat-q_beta), the
%                                    plain-English "how much closer did
%                                    this get us" number
%     out.iters                     outer Nelder-Mead iterations used
%     out.notes

if nargin < 10 || isempty(alpha)
    alpha = 0.05;
end
if nargin < 11 || isempty(opts)
    opts = struct();
end
if ~isfield(opts,'maxIter'), opts.maxIter = 300;   end
if ~isfield(opts,'tol'),     opts.tol     = 1e-12; end

sz = size(ptb);
n = numel(ptb);

ptb = expand_(ptb,n); psa = expand_(psa,n); dpa = expand_(dpa,n); dpb = expand_(dpb,n);
dpr = expand_(dpr,n); dpn = expand_(dpn,n);
f0    = expand_(f0,n);    pkor0 = expand_(pkor0,n);

if ~isfield(opts,'mask') || isempty(opts.mask)
    mask = true(n,1);
else
    mask = expand_(logical(opts.mask), n);
end

% --- accept sigma as scalar, 8-vector, or struct (same convention as r858_solve2/3) ---
if isstruct(sigma)
    sigma = normalize_sigma_struct_(sigma, 'r858_calibrate_offsets');
elseif isscalar(sigma)
    sigma = struct('ptb',sigma,'psa',sigma,'dpa',sigma,'dpb',sigma,'dpr',sigma,'dpn',sigma);
elseif numel(sigma) == 8
    sigma = struct('ptb',sigma(1),'psa',sigma(2),'dpa',sigma(3),'dpb',sigma(4), ...
                    'dpr',sigma(5),'dpn',sigma(6),'f',sigma(7),'pkor',sigma(8));
else
    error('r858_calibrate_offsets:sigmaFormat', ...
        'sigma must be a struct, a scalar, or an 8-vector [ptb psa dpa dpb dpr dpn f pkor].');
end
if ~isfield(sigma,'f'),    sigma.f    = 0; end
if ~isfield(sigma,'pkor'), sigma.pkor = 0; end
req = {'ptb','psa','dpa','dpb','dpr','dpn'};
for i = 1:numel(req)
    if ~isfield(sigma, req{i})
        error('r858_calibrate_offsets:missingSigma', 'sigma.%s is required.', req{i});
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

% ---- auto-detect and exclude rows this simplified (dropout-unaware)
% calibration can't handle: exact DPR/DPN dropout sentinels (0), exact
% zero DPA/DPB (e.g. ground/static segments with no dynamic pressure -
% these are a literal 0/0 in the ta/tb closed form), or anything else
% that comes out non-finite. This matters more here than in r858_solve2/3:
% those are per-row, so one bad row only NaNs that row; this function
% SUMS across all rows for its chi-square/weights, so a single bad row
% silently NaNs the entire fit (which is exactly what happened when this
% was run on the full flight record - see chat).
dropTol = 1e-12;
dprOut  = abs(dpr) < dropTol;
dpnOut  = abs(dpn) < dropTol;
dpaZero = abs(dpa) < dropTol;
dpbZero = abs(dpb) < dropTol;
r0 = resid_(ptb,psa,dpa,dpb,dpr,dpn,f0,pkor0);
bad = dprOut | dpnOut | dpaZero | dpbZero | ~isfinite(r0);
if any(bad)
    otherBad = ~isfinite(r0) & ~dprOut & ~dpnOut & ~dpaZero & ~dpbZero;
    warning('r858_calibrate_offsets:droppedRows', ...
        ['%d of %d row(s) excluded before fitting: %d with a DPR/DPN dropout sentinel (0), ', ...
         '%d with exact-zero DPA or DPB (e.g. ground/static segments - a 0/0 in the closed ', ...
         'form; categories may overlap), %d other non-finite. This function assumes clean, ', ...
         'in-flight data - pass opts.mask for tighter control over what gets excluded.'], ...
        sum(bad), numel(bad), sum(dprOut|dpnOut), sum(dpaZero|dpbZero), sum(otherBad));
end
keep = ~bad;
if sum(keep) < 10
    error('r858_calibrate_offsets:tooFewRows', ...
        ['Only %d row(s) remain after excluding dropout/zero/non-finite rows - not enough ', ...
         'to calibrate. Check your inputs, or pass a cleaner opts.mask.'], sum(keep));
end
ptb=ptb(keep); psa=psa(keep); dpa=dpa(keep); dpb=dpb(keep); dpr=dpr(keep); dpn=dpn(keep);
f0=f0(keep); pkor0=pkor0(keep);
s.ptb=s.ptb(keep); s.psa=s.psa(keep); s.dpa=s.dpa(keep); s.dpb=s.dpb(keep);
s.dpr=s.dpr(keep); s.dpn=s.dpn(keep); s.f=s.f(keep); s.pkor=s.pkor(keep);
nEff = sum(keep);

% ---- one-time weights: delta-method propagation of (q_hat - q_beta)'s
% variance at the starting point (df,dp)=(0,0), frozen for the whole outer
% search (standard, cheap approximation - the weights only need to be
% approximately right for the fit to converge to the right place; only
% the FINAL point estimate is used for reported dof/chi2, computed fresh). ----
inputs8 = {ptb,psa,dpa,dpb,dpr,dpn,f0,pkor0};
sigmas8 = {s.ptb,s.psa,s.dpa,s.dpb,s.dpr,s.dpn,s.f,s.pkor};
var_r = zeros(nEff,1);
for i = 1:8
    h = 1e-6 * max(1, abs(inputs8{i}));
    argsP = inputs8; argsP{i} = inputs8{i} + h;
    argsN = inputs8; argsN{i} = inputs8{i} - h;
    rP = resid_(argsP{:});
    rN = resid_(argsN{:});
    dr = (rP - rN) ./ (2*h);
    var_r = var_r + (dr.^2) .* (sigmas8{i}.^2);
end
w = 1 ./ max(var_r, eps);

    function r = resid_(ptbv,psav,dpav,dpbv,dprv,dpnv,fv,pkorv)
        % q_hat (normal 3-way GLS q, same as r858_solve2) minus q_beta
        % (f-independent alternative), both evaluated at the SAME trial
        % f, pkor (pkor enters q_beta too, via dp1+pkor).
        qh = qhat3_(ptbv,psav,dpav,dpbv,dprv,dpnv,fv,pkorv);
        dp1a = (ptbv - psav) + pkorv;
        qb = qbeta_(dp1a,dpav,dpbv,dprv);
        r = qh - qb;
    end

    function qh = qhat3_(ptbv,psav,dpav,dpbv,dprv,dpnv,fv,pkorv)
        [~,~,~,Y] = raw_to_ests_(ptbv,psav,dpav,dpbv,dprv,dpnv,fv,pkorv);
        % Build the 3x3 GLS combination via the SAME 8-input Jacobian used
        % for the weights above, but local to this trial (f,pkor fixed).
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

% ---- objective: sigma-weighted sum of squared (q_hat - q_beta), as a
% function of the 2 free parameters params=[delta_f, delta_pkor] ----
    function val = objective_(params)
        df = params(1); dp = params(2);
        r = resid_(ptb,psa,dpa,dpb,dpr,dpn, f0+df, pkor0+dp);
        if any(~isfinite(r))
            % Rows were already pre-screened at (df,dp)=(0,0); a non-finite
            % result here means this particular trial offset pushed some
            % row into a degenerate spot (e.g. D*(1-f)+f near 0). Reject
            % the trial outright rather than let NaN silently poison the
            % sum and stall the simplex (see chat - this is what happened
            % on the first real-data run, without this guard, for
            % dropout/ground rows that weren't pre-screened at all).
            val = Inf;
        else
            val = sum(w .* r.^2);
        end
    end

chi2_before = objective_([0,0]);

x0 = [0,0];
step0 = 0.02*max([1, mean(abs(f0)), mean(abs(pkor0))]);
[xhat, chi2_after, iters] = nelder_mead_(@objective_, x0, step0, opts.maxIter, opts.tol);

df_hat = xhat(1); dp_hat = xhat(2);

% ---- SE via finite-difference Hessian of the (chi-square-like) objective
% at the optimum: for a weighted sum-of-squares chi2 statistic, Cov =
% 2*inv(Hessian) is the standard asymptotic result (validated against a
% Monte-Carlo simulation - see chat). ----
hh = 1e-4 * max(1, max(abs(xhat)));
f00 = chi2_after;
fPP = objective_(xhat+[hh,0]);  fMM = objective_(xhat-[hh,0]);
fQQ = objective_(xhat+[0,hh]);  fRR = objective_(xhat-[0,hh]);
fPQ = objective_(xhat+[hh,hh]); fMR = objective_(xhat-[hh,hh]);
H11 = (fPP - 2*f00 + fMM) / hh^2;
H22 = (fQQ - 2*f00 + fRR) / hh^2;
H12 = (fPQ - fPP - fQQ + 2*f00 - fMM - fRR + fMR) / (2*hh^2);
H = [H11 H12; H12 H22];
Cov = 2*inv(H);
SE = sqrt(max(diag(Cov),0));
df_SE = SE(1); dp_SE = SE(2);

dof = nEff - 2;
pval = NaN;
if dof > 0
    pval = 1 - gammainc(chi2_after/2, dof/2);
end

r_before = resid_(ptb,psa,dpa,dpb,dpr,dpn, f0,      pkor0);
r_after  = resid_(ptb,psa,dpa,dpb,dpr,dpn, f0+df_hat, pkor0+dp_hat);

out.f_offset      = df_hat;
out.f_offset_SE   = df_SE;
out.f_offset_CI   = [df_hat - z*df_SE, df_hat + z*df_SE];
out.pkor_offset    = dp_hat;
out.pkor_offset_SE = dp_SE;
out.pkor_offset_CI = [dp_hat - z*dp_SE, dp_hat + z*dp_SE];
out.f_hat    = f0 + df_hat;
out.pkor_hat = pkor0 + dp_hat;
out.chi2_before = chi2_before;
out.chi2_after  = chi2_after;
out.dof   = dof;
out.pvalue = pval;
out.rms_before = sqrt(mean(r_before.^2));
out.rms_after  = sqrt(mean(r_after.^2));
out.iters = iters;
out.notes = sprintf(['Fit delta_f=%.6g (SE %.3g), delta_pkor=%.6g (SE %.3g) over %d rows, ', ...
    'dof=%d. RMS(q_hat-q_beta) went from %.4g to %.4g. This is a single global-offset ', ...
    'correction on top of your existing f0/pkor0 (which may already vary with Mach/flow-angle) - ', ...
    'it is NOT a re-derivation of the functional f(Mach,alpha)/pkor(Mach,alpha) dependence, which ', ...
    'needs a trailing-cone flight. If you run this separately on different flight segments/speed ', ...
    'regimes and get materially different offsets, that is evidence the true f, pkor error is ', ...
    'condition-dependent, not a constant bias - the single global offset here is only a stopgap.'], ...
    df_hat, df_SE, dp_hat, dp_SE, nEff, dof, out.rms_before, out.rms_after);

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
% Accepts a sigma struct with field names in any case, and additionally
% recognizes 'fcoef' as an alias for 'f' and 'pcor' as an alias for
% 'pkor'. Unrecognized fields are ignored with a warning.
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
% Exact, f-independent, dpn-independent closed-form q, generated from
% eliminating f between eq.1 and the dpb equation, then eliminating ta via
% the cross-relation ta=(dpa/dpb)*tb, with tb solved from the (dpb,dpr)
% pair alone. Verified symbolically and numerically to reproduce q_true
% exactly given self-consistent, noiseless inputs, for ANY f (i.e. it
% truly does not need to know f) - see chat for the derivation.
t2 = dpb.^2;
qb = dp1a - ((t2+dpa.^2).*(dpb+dpr.*2 - sqrt(2).*sqrt(t2+dpb.*dpr.*2+dpr.^2.*2))) ./ (t2.*2);
end

% ------------------------------------------------------------------
function [dp1, ta, tb, Y] = raw_to_ests_(ptb,psa,dpa,dpb,dpr,dpn,f,pkor)
% Same exact closed-form as r858_solve2.m's raw_to_ests_ (numerically
% stable ta/tb), WITHOUT the sensor-dropout branching - this calibration
% function assumes clean data; pre-filter dropout rows via opts.mask.
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
function [xbest, fbest, iters] = nelder_mead_(fun, x0, step, maxIter, tol)
% Minimal, self-contained Nelder-Mead simplex minimizer for a small number
% of parameters (used here for exactly 2: delta_f, delta_pkor). No
% Optimization Toolbox dependency. Standard reflect/expand/contract/shrink
% steps with coefficients 1, 2, 0.5, 0.5.
n = numel(x0);
simplex = zeros(n+1,n);
fvals = zeros(n+1,1);
simplex(1,:) = x0(:)';
fvals(1) = fun(simplex(1,:));
for i = 1:n
    p = x0(:)';
    p(i) = p(i) + step;
    simplex(i+1,:) = p;
    fvals(i+1) = fun(p);
end
for it = 1:maxIter
    [fvals, idx] = sort(fvals);
    simplex = simplex(idx,:);
    if abs(fvals(end) - fvals(1)) < tol
        break
    end
    centroid = mean(simplex(1:end-1,:), 1);
    worst = simplex(end,:);
    xr = centroid + 1.0*(centroid - worst);   fr = fun(xr);
    if fvals(1) <= fr && fr < fvals(end-1)
        simplex(end,:) = xr; fvals(end) = fr;
    elseif fr < fvals(1)
        xe = centroid + 2.0*(centroid - worst); fe = fun(xe);
        if fe < fr
            simplex(end,:) = xe; fvals(end) = fe;
        else
            simplex(end,:) = xr; fvals(end) = fr;
        end
    else
        xc = centroid + 0.5*(worst - centroid); fc = fun(xc);
        if fc < fvals(end)
            simplex(end,:) = xc; fvals(end) = fc;
        else
            best = simplex(1,:);
            for i = 2:n+1
                simplex(i,:) = best + 0.5*(simplex(i,:) - best);
                fvals(i) = fun(simplex(i,:));
            end
        end
    end
end
[fvals, idx] = sort(fvals);
simplex = simplex(idx,:);
xbest = simplex(1,:);
fbest = fvals(1);
iters = it;
end
