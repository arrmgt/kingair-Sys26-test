function [pcor, q, f] = calc_pcor(BETA, DP1, DPB, DPA, DPR, DPN, PTB, PS, TDPK, Tmeas, recovf)
% Apply linear model coefficients to predictor matrix X.
% beta : (p+1)x1 vector [intercept; b1; b2; ...; bp]
% X    : NxP numeric matrix where columns match beta(2:end) order
% yhat : Nx1 predicted responses
BETA=BETA(:);
[q0, f0, ta0, tb0] = ...
          solve858(DP1, DPA, DPB, 'dpr', DPR, 'DPN', DPN);
ADat = airdata(PS, q0+PS, Tmeas, recovf, TDPK);
Mnum = ADat.M;

x1 = Mnum;
x2 = q0;
x3 = atan(ta0);
x4 = atan(tb0);
x5 = ta0.^2 + tb0.^2;
X = [x1,x2,x3,x4,x5];
pcor = X * BETA(2:end) + BETA(1);
[q, f, ta, tb] = ...
          solve858(DP1, DPA, DPB, 'dpr', DPR, 'DPN', DPN, ...
          'ps_cor',pcor);
end