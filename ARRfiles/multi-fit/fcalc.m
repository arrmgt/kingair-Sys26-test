function [f,qx1,pErr,f0,fqx0,XX1f,betaf,machn] = fcalc(x,Z,sigma)
%FCALC Residual function for lsqnonlin pitot-static "f-factor" calibration.
%
%   [f,qx1,pErr,f0] = fcalc(x,Z,sigma)
%
%   x     - calibration coefficients being solved for (betaf), a 4x1
%           vector multiplying [1, machn, machn.^2, abFact]
%   Z     - struct with fields DPA, DPB, DPR, DPN, DP1, PSA, mr, PTB
%           (one calibration point per row/element)
%   sigma - measurement-uncertainty input passed through to r858_solve3
%
%   f is the residual vector lsqnonlin minimizes: it drives the
%   corrected impact pressure toward the independent reference q from
%   r858_solve3, i.e. this is the "force X=Y" fit --
%       X = qx0 - pErr   (corrected measured impact pressure)
%       Y = OUT1.q        (reference q)
%       f = Y - X
%
%   NOTE: transcribed from the version pasted in chat, with one
%   copy/paste artifact removed -- a "tbx = tanBeta(pb,pr)" call had
%   appeared BEFORE pa/pb/pr were unpacked from Z. Confirmed correct
%   against the original by the user (re-pasted and diffed clean, aside
%   from restoring the "Rodi & Leon (2012)" comment below, which is now
%   included).
%
%   The [1, machn, machn^2, abFact] correction model (the XXf matrix
%   below) follows Rodi & Leon (2012).
%
%   DEPENDENCIES (assumed already on your MATLAB path, not included
%   here): tanAlpha, tanBeta, impactPcalc, fqCalc, mach, r858_solve3.
%
% See also: runCalibrationFit, buildZStruct

pa  = Z.DPA;
pb  = Z.DPB;
pr  = Z.DPR;
dp1 = Z.DPX;
psm = Z.PSX;
pn  = Z.DPN;
mr  = Z.mr;
ptb = Z.PTB;

% These are independent of static pressure correction
tax = tanAlpha(pa,pb,pr);
tbx = tanBeta(pb,pr);
abFact = tax.^2 + tbx.^2;
abFact1 = sqrt(pa.^2+pb.^2);

qx0 = impactPcalc(dp1,pa,pb,pr); % uncorrected qc
% fqx is f*q; fqx/f = q; fqx is independent of pcor
fqx0 = fq_beta(pa,pb,pr);

onez = ones(size(psm));
zeroz = zeros(size(psm));
C=phycon;

% From Rodi&Leon(2012)
betaf0 = [ ...
   1.699864444944109; ...
  -0.156929423443038; ...
   0.066325085038090; ...
   0.001254576494439  ...
   ];

% Set default f
f0 = 1.70 .* ones(size(dp1)); % just a guess
% We need mach number to get f, so we have to iterate
pErr = 0;
zeroz=zeros(size(dp1));
betaf = x;
for jj = 1:3 % iterate three times
    machn = mach(qx0+pErr, psm-pErr, mr);
    XX0 = [machn machn.^2 pa];
    XX0f = [onez XX0];
    f0 = XX0f*betaf0;
    pkor = pcor_beta(dp1,pa,pb,pr,f0,fqx0);
    ptb = qx0+pErr + psm - pErr;
    XX1 = [machn ptb pa pn];
    XX1f = [onez XX1];
    pErr = XX1f*betaf;
end
%qx1 = fqx0./f0;
qx1 = qx0 + pErr;
ptb = dp1 + psm;
fqx1 = f0.*qx1;
% "(ptb, psa, dpa, dpb, dpr, dpn, f, pkor, sigma, alpha, opts)"
OUT1 = r858_solve3(ptb, psm, pa, pb, pr, pn, f0, pErr);

f = OUT1.q - qx0 - pErr;
f = fillmissing(f, 'constant', 0);

end


