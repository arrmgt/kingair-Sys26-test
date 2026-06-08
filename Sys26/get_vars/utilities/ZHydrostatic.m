function [zz,dz]=ZHydro(z0,pmb,TK,varargin)
%ZHYPSO: hypsometric altitude
%function zz=ztrue(z0,pmb,TK,[mr,[grav]]) 
%
%Inputs:
%  z0       Initial height [m]
%  pmb      Static pressure [any units ok]
%  TK       Temperature [K]
%  [mr]     Mixing Ratio [g/g] (optional)
%  [grav]   Gravity [m/s2] (optional)
%
%Outputs:
%
%  ztrue    High from integration of hypsometric equation
%  dz       Differential of height (for debugging)
%

C=phycon(); % get physical constants
g = C.g0;
p = inputParser;
addParameter(p, 'Mixing_Ratio', 0, @(x) isnumeric(x));
addParameter(p, 'Gravity', g , @(x) isnumeric(x));
parse(p, varargin{:});
Opts = p.Results;

g = Opts.Gravity;
mr = Opts.Mixing_Ratio;

dp_p = gradient(log(pmb)) ;
kk = find( pmb<1200 & pmb>250 & ~isnan(dp_p) & ~isinf(dp_p) );
dp = interp1(kk,dp_p(kk),[1:numel(pmb)]','spline',0);
dz = dp_p .*C.Rd.* TK ./g;
zz = -cumsum(dz) + z0;
