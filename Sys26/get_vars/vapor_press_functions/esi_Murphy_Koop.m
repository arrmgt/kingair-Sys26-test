function e = esi_Murphy_Koop(T)
% esi_MurphyKoop  Saturation vapor pressure over ice using
% Murphy & Koop (2005), QJRMS — equation 7.
%
% Input:
%   T = temperature (K)   [can accept degC, see below]
%
% Output:
%   e = saturation vapor pressure over ice (hPa)
%
% Valid from about 110 K to 273 K (−163°C to +0°C)
%
% Notes:
% Highly accurate; recommended for atmospheric work,
% frost-point hygrometry, radiosondes, aircraft met sensors.

    % If user enters degC, convert to K
    if any(T<100)  % assume input is Celsius
        T = T + 273.15;
    end

    % Murphy & Koop (2005):
    e = exp(9.550426 - 5723.265./T + 3.53068.*log(T) - 0.00728332.*T);
    e = e/100; %hPa
end
