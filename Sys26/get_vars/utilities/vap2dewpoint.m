function [Td]=vap2dewpoint(e);
% Get dew point temperature [K] from vapor pressure [hPa]
%    using spline fit to WMO 2000 saturation vapor pressure 
%    function.
%
%'WMO2000' 
%         ; WMO formulation, which is very similar to Goff Gratch
%         ; Source : WMO technical regulations, WMO-NO 49, Vol I, 
%         ;     General Meteorological Standards and Recommended Practices, i
%         ;     App. A, Corrigendum Aug 2000.
%
% get IDL code from http://cires.colorado.edu/~voemel/vp.pro .
%

Ts    = 273.16       ; %triple point temperature in K
T=[-60:50] +273.15;
Psat = 10.^(10.79574.*(1.-Ts./T) ...
                     - 5.02800 .* log10(T./Ts) ...
                     + 1.50475E-4 .* (1.-10.^(-8.2969.*(T./Ts-1.))) ...
                     + 0.42873E-3 .* (10.^(-4.76955.*(1.-Ts./T))-1.) ...
                     + 0.78614);
Td = spline(Psat,T,e);
kk=find(e<=0);Td(kk)=-60+273.15;

