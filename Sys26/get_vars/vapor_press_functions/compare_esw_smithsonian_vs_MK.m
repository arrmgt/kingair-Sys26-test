function compare_esw_smithsonian_vs_MK
% compare_esw_smithsonian_vs_MK
% Compare saturation vapor pressure over *liquid water* (supercooled)
% between:
%   1) Goff–Gratch / Smithsonian formulation (legacy standard)
%   2) Murphy & Koop (2005) (modern recommended)
%
% Temperature range: 0 to -50 °C (supercooled liquid region).
%
% This is useful for understanding the impact of using Smithsonian tables
% vs. Murphy & Koop for hypothetical dewpoint below freezing.

    %% Temperature grid (degC)
    T_C = (0 : -1 : -50).';       % column vector, 0, -1, -2, ..., -50

    %% Saturation vapor pressure over liquid water (Pa)
    e_SMT = esw_GoffGratch_water(T_C);     % Smithsonian/Goff–Gratch
    e_MK  = esw_MurphyKoop_water(T_C);     % Murphy & Koop (2005)

    %% Convert to hPa for plotting
    e_SMT_hPa = e_SMT / 100;
    e_MK_hPa  = e_MK  / 100;

    %% Percent difference: (SMT - MK) / MK * 100
    dPct = (e_SMT - e_MK) ./ e_MK * 100;

    %% Plot saturation curves
    figure;
    plot(T_C, e_MK_hPa, 'LineWidth', 1.6); hold on;
    plot(T_C, e_SMT_hPa, '--', 'LineWidth', 1.6);
    grid on;
    xlabel('Temperature (^{\circ}C)');
    ylabel('e_s over liquid water (hPa)');
    title('Saturation Vapor Pressure over Supercooled Liquid Water');
    legend('Murphy & Koop (2005)', 'Goff–Gratch / Smithsonian', ...
           'Location', 'northeast');

    %% Plot percent difference
    figure;
    plot(T_C, dPct, 'LineWidth', 1.6);
    grid on;
    xlabel('Temperature (^{\circ}C)');
    ylabel('Percent difference SMT vs MK (%)');
    title('Relative Difference: Smithsonian (Goff–Gratch) vs Murphy & Koop');
    yline(0, ':');
end


function e = esw_GoffGratch_water(T_C)
% esw_GoffGratch_water
% Saturation vapor pressure over *liquid water* (Pa)
% using the classic Goff–Gratch (1946) formulation as used in
% Smithsonian Meteorological Tables.
%
% Input:
%   T_C : temperature in degC (scalar or array)
% Output:
%   e   : saturation vapor pressure over liquid water (Pa)

    T  = T_C + 273.15;  % K
    T0 = 373.16;        % K (boiling point at 1 atm)
    e0 = 1013.246;      % hPa, saturation at T0

    term1 = -7.90298 * (T0./T - 1);
    term2 =  5.02808 * log10(T0./T);
    term3 = -1.3816e-7 * (10.^(11.344 * (1 - T./T0)) - 1);
    term4 =  8.1328e-3 * (10.^(-3.49149 * (T0./T - 1)) - 1);

    log10_e = term1 + term2 + term3 + term4 + log10(e0);  % e in hPa
    e_hPa   = 10.^log10_e;
    e       = e_hPa * 100;  % Pa
end


function e = esw_MurphyKoop_water(T_in)
% esw_MurphyKoop_water
% Saturation vapor pressure over *liquid water* (Pa)
% using Murphy & Koop (2005), valid down to about -50 °C.
%
% Input:
%   T_in : temperature in K or degC (scalar or array)
%          If any(T_in < 100), interpreted as degC and shifted to K.
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
