function Tb=boilpoint(pmb);
%function Tboil=boilpoint(pmb);
%$Source: /home/cvs/kingair/Sys09/lwc301_funs/boilpoint.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.2 $)
%$Date: 2020/09/04 20:57:15 $
% Gets boiling point of water given pressure(s);
% Uses matlab lsqnonlin with function fboilp to search for result
%
% Input: pmb = static pressure [mb]
% Output:  Tb = boiling point [K]
%

% Guess 100C
x0=373.15.*ones(size(pmb));
options=optimoptions('fsolve','Display','none');
Tb=fsolve('fboilp',x0,options,pmb);
return

function f=fboilp(x,pmb);
% Finds boiling point temperature at given pressure
% Uses WMO formula for vapor pressure
% returns f=residual from pmb - vapor pressure at TK.

TK=x;
f=pmb-sat_vapor_pressure_GG(TK);
return


