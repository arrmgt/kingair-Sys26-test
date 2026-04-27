function [fact,TBOIL]=get_fact(area,tairK,tas,ps);
% function [fact,TBOIL]=get_fact(area,tairK,tas,ps);
%$Source: /home/cvs/kingair/Sys09/lwc301_funs/get_fact.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.2 $)
%$Date: 2020/09/05 20:20:36 $
% Factor to convert hot wire power to LWC g/m3
%   and boiling point of water as f(ps)
%
% Inputs:
%   area = sensing element Diam*Length [m^2]
%   tairK = air temp [K]
%   tas = true airspeed [m/s]
%   ps = static pressure [mb]
% Outputs:
%   fact = conversion factor
%          LWC=(power - dry_air_power).*fact
%   Tb = boiling point [K] at given pressure
%

C=phycon;
cw=C.Cw; % specific heat of liquid water

PP=[300:1100]'; % Range of static pressures [mb]
% boilpoint.m finds water boiling point ([K] as function of pressure
TBOIL=spline(PP,boilpoint(PP),ps);

% latent heat of vaporization = f(T)
alhv=lhvtemp(TBOIL-C.Tzero); %latent heat vap = f(T)

%
% conversion factor (power to LWC)
fact = 1.0e3./(area.*tas.*(alhv+cw.*(TBOIL-tairK))) ;
