function [f,qx1,pErr,f0] = fcalc(x,Z,sigma)
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
pn  = Z.DPN;
dp1 = Z.DP1;
psm = Z.PSA;
mr  = Z.mr;
ptb = Z.PTB;

% These are independent of static pressure correction
tax = tanAlpha(pa,pb,pr);
tbx = tanBeta(pb,pr);
abFact = 1 + tax.^2 + tbx.^2;

qx0 = impactPcalc(dp1,pa,pb,pr); % uncorrected qc
% fqx is f*q; fqx/f = q; fqx is independent of pcor
fqx = fqCalc(pa,pb,pr);

betaf = x;
onez = ones(size(psm));

% Set default f
f0 = 1.68 .* ones(size(dp1)); % just a guess
% We need mach number to get f, so we have to iterate
pErr = fqx./f0 - qx0; % error in q
for jj = 1:3 % iterate three times
    % We need machn to get pErr, and pErr to get machn
    machn = mach(qx0+pErr, psm-pErr, mr);
    % Rodi & Leon (2012)
    XX = [machn machn.^2 abFact];
    XXf = [onez XX];
    f0 = XXf*betaf;
    pErr = fqx./f0 - qx0;
end
qx1 = fqx./f0;

% "(ptb, psa, dpa, dpb, dpr, dpn, f, pkor, sigma, alpha, opts)"
OUT1 = r858_solve3(ptb, psm, pa, pb, pr, pn, f0, pErr, sigma, .05);
f = OUT1.q - qx0 + pErr;
f = fillmissing(f, 'constant', 0);

end
