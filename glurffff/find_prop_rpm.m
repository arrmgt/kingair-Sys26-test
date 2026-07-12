function C = find_prop_rpm_candidates(obsHz, fs_old, fs_new, blades, maxWrap, rpmMax)
% find_prop_rpm_candidates  Enumerate candidate RPMs that could map to observed aliased freqs
% C = find_prop_rpm_candidates(obsHz, fs_old, fs_new, blades, maxWrap, rpmMax)
% Inputs:
%   obsHz    - vector of observed aliased frequencies (Hz), in [0, fs_new/2]
%   fs_old   - original sampling rate (Hz)
%   fs_new   - new sampling rate after decimation (Hz)
%   blades   - number of blades (N)
%   maxWrap  - max integer wraps (n) to try (default 10)
%   rpmMax   - optional upper bound on RPM to keep plausible candidates (default inf)
% Output:
%   C - table with columns: obsHz, n_wrap, f_mod, f_phys_Hz, RPM

if nargin<5 || isempty(maxWrap), maxWrap = 10; end
if nargin<6 || isempty(rpmMax), rpmMax = inf; end
obsHz = obsHz(:);
Nyq = fs_new/2;
scaleUp = fs_old / fs_new;   % inverse of scaling used when downsampling

rows = [];
for i=1:numel(obsHz)
    fa = obsHz(i);
    % two possible f_mod values (before folding): fa or fs_new - fa
    fmods = unique([fa, fs_new - fa]);
    for n = 0:maxWrap
        for fm = fmods
            % scaled-back physical frequency candidate:
            f_phys = (n*fs_new + fm) * scaleUp;
            RPM = 60 * f_phys / blades;
            if RPM <= rpmMax
                rows = [rows; i, n, fm, f_phys, RPM]; %#ok<AGROW>
            end
        end
    end
end

C = array2table(rows, 'VariableNames', {'obsIndex','n_wrap','f_mod_Hz','f_phys_Hz','RPM'});
C.obsHz = obsHz(C.obsIndex);
C = movevars(C, 'obsHz','Before','obsIndex');

end
