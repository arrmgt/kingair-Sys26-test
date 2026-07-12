function [f,qx1,pErr,f0] = fcalc(x,Z,sigma)
% These are independent of static pressure correctitbx = tanBeta(pb,pr);
pa = Z.DPA;
pb = Z.DPB;
pr = Z.DPR;
pn = Z.DPN;
dp1 = Z.DP1;
psm = Z.PSA;
mr = Z.mr;
ptb = Z.PTB;
tax = tanAlpha(pa,pb,pr);
tbx = tanBeta(pb,pr);
abFact = 1 + tax.^2 + tbx.^2;
qx0 = impactPcalc(dp1,pa,pb,pr); %uncorrecteddb
% fqx us f*q; fqx/f = q; fqx is independent of pcor
fqx = fqCalc(pa,pb,pr); 

betaf = x;
onez = ones(size(psm));
% Set default f
f0=1.68.*ones(size(dp1)); % just a guess
%  We need mach number to get f, so we have to iterate
pErr = fqx./f0 -qx0;  %  Error in q
for jj=1:3 % Iterate three times
% We need machn to get pErr, and pErr to get machn
    machn=mach(qx0+pErr,psm-pErr,mr);
    % Rodi & Leon(2012)
    XX=[machn machn.^2 abFact ]; 
    XXf=[onez XX];
    f0=XXf*betaf; 
    pErr=fqx./f0-qx0;
end
qx1 = fqx./f0;
%"(ptb, psa, dpa, dpb, dpr, dpn, f, pkor, sigma, alpha, opts)"
OUT1 = r858_solve3(ptb, psm, pa, pb, pr, pn, f0, pErr, sigma, .05);

f = OUT1.q - qx0 + pErr;
f = fillmissing(f,'constant',0);

return
