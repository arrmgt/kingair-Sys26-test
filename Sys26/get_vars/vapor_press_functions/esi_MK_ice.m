function e = esi_MK_ice(T_C)
% esi_MK_ice  Saturation vapor pressure over ice (Pa)
% Murphy & Koop (2005), Eq. for ice.
%
% Input:
%   T_C : temperature in degC
% Output:
%   e   : saturation vapor pressure over ice (Pa)

    T = T_C + 273.15;  % K

    % Murphy & Koop (2005), ice:
    % ln(e) = 9.550426 - 5723.265/T + 3.53068*ln(T) - 0.00728332*T
    ln_e = 9.550426 ...
         - 5723.265 ./ T ...
         + 3.53068  .* log(T) ...
         - 0.00728332 .* T;

    e = exp(ln_e);     % Pa
end
