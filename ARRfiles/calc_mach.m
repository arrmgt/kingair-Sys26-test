function [M, Ts, Tas] = calc_mach(q, Ps, Tr, r)
% CALC_MACH  Compute Mach from total/static pressure and temperature recovery
%
% Inputs:
%   q  = impact pressure     [same units as Ps]
%   Ps = static pressure
%   Tr = recovered/measured temperature (optional, K)
%   r  = recovery factor (optional)
%
% Outputs:
%   M  = Mach number
%   Ts = static temperature (if Tr,r supplied)

C=phycon;
gamma = C.Cpd/C.Cvd;
Rd = C.Rd;


%---- Mach from pressure ratio ----%
PR = (Ps + q)./Ps;
kk=find(q>1 &  q<100 & PR>1 & ~isnan(q) & Ps > 300 & Ps < 1100);
if ~isempty(kk)
    q = interp1(kk,q(kk),[1:numel(q)]','linear',1);
    PR = (Ps+q)./Ps;
end

M = sqrt( (2./(gamma-1)) .* ( PR.^((gamma-1)/gamma) - 1 ) );

%---- Static temp from recovery temp and TAS ----%
if nargin > 2
    Ts = Tr ./ (1 + r*(gamma-1)/2 .* M.^2);
    a = sqrt(gamma .*Rd  .*Ts);
    Tas = M.*a;
else
    Ts = [];
    Tas = [];
end

end