function e = esw_MK_water(T_in)
% esw_MK_water  Saturation vapor pressure over liquid water (Pa)
% Murphy & Koop (2005), valid down into supercooled range.
%
% Input:
%   T_in : temperature in K or degC
%          (if <100, interpreted as degC and converted to K)
% Output:
%   e    : saturation vapor pressure over liquid water (Pa)

    T = T_in;
    if any(T < 100, 'all')
        T = T + 273.15;   % degC -> K
    end

    lnT   = log(T);
    term1 = 54.842763 - 6763.22 ./ T - 4.210 .* lnT + 0.000367 .* T;

    x     = 0.0415 .* (T - 218.8);
    term2 = tanh(x) .* ( ...
              53.878          ...
            - 1331.22 ./ T    ...
            - 9.44523 .* lnT  ...
            + 0.014025 .* T );

    e = exp(term1 + term2);  % Pa
end
