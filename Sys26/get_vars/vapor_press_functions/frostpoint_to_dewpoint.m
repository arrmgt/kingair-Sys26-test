function Td_C = frostpoint_to_dewpoint(Tsens_C)
% edgetech_T_to_hypo_dewpoint_MK
% For Edgetech airborne hygrometer:
%   Tsens_C >= 0: true dewpoint (liquid) => returned unchanged
%   Tsens_C <  0: frost point (ice)      =>
%                 converted to hypothetical liquid dewpoint

    Td_C = Tsens_C;
    mask = Tsens_C < 0;

    if any(mask,'all')
        Td_C(mask) = hypo_dewpoint_from_frostpoint_MK(Tsens_C(mask));
    end
end
