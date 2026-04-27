function Td_C = hypo_dewpoint_from_frostpoint_MK(Tf_C)
% hypo_dewpoint_from_frostpoint_MK
% Convert frost-point temperature (degC, over ice) to
% hypothetical dewpoint (degC, over liquid water), allowing
% supercooled liquid below 0°C.
%
% For each Tf_C:
%   e  = esi_MK_ice(Tf_C);
%   Td = T_d such that esw_MK_water(Td) = e.
%
% Input:
%   Tf_C : frost-point temperature in degC (scalar or array, typically <0)
%
% Output:
%   Td_C : hypothetical dewpoint in degC (same size as Tf_C),
%          ALWAYS on the liquid-water saturation curve.

    Tf_C = double(Tf_C);
    e    = esi_MK_ice(Tf_C);   % Pa, saturation over ice at Tf

    Td_C = nan(size(Tf_C));

    % Bracketing limits for dewpoint (liquid water), in Kelvin
    TlowK  = 223.15;  % -50°C
    ThighK = 323.15;  % +50°C

    for k = 1:numel(e)
        if ~isfinite(e(k)) || e(k) <= 0
            Td_C(k) = NaN;
            continue;
        end

        % f(T) = esw_liquid(T) - e; T in Kelvin
        f = @(T) esw_MK_water(T) - e(k);

        % If out of range, clamp to ends
        if f(TlowK) > 0
            Td_K = TlowK;       % hypothetical Td below -50°C
        elseif f(ThighK) < 0
            Td_K = ThighK;      % hypothetical Td above +50°C
        else
            Td_K = fzero(f, [TlowK, ThighK]);
        end

        Td_C(k) = Td_K - 273.15;
    end
end
