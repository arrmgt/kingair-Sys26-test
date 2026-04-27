function [zz,dz]=ZHypso(z0,pmb,tk,varargin)
%ZHYPSO: hypsometric altitude
%function zz=ztrue(z0,pmb,tk,[mr,[grav]]) 
%
%Inputs:
%  z0       Initial height [m]
%  pmb      Static pressure [any units ok]
%  tk       Temperature [K]
%  [mr]     Mixing Ratio [g/g] (optional)
%  [grav]   Gravity [m/s2] (optional)
%
%Outputs:
%
%  ztrue    High from integration of hypsometric equation
%  dz       Differential of height (for debugging)
%

C=phycon(); % get physical constants
p = inputParser;
addParameter(p, 'Mixing_Ratio', 0, @(x) isnumeric(x));
addParameter(p, 'Gravity', C.g0, @(x) isnumeric(x));
parse(p, varargin{:});
Opts = p.Results;
g = Opts.Gravity;
mr = Opts.Mixing_Ratio;

dp = gradient(log(pmb)) ;
kk = find( abs(dp)<0.5e-3 & ~isnan(dp) & ~isinf(dp) );
dp = interp1(kk,dp(kk),[1:numel(dp)]','spline',0);
dz = dp .* C.Rd .* tk ./ g;
zz = -cumsum(dz) + z0;
