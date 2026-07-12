function T = resample_alias_map(fs_old, fs_new, f_phys)
% resample_alias_map  Map physical frequencies to aliased frequencies
%   T = resample_alias_map(fs_old, fs_new, f_phys)
%   Inputs:
%     fs_old - original sam
% T = resample_alias_map(fs_old, fs_new, f_phys)pling rate (Hz)
%     fs_new - new sampling rate after resampling (Hz)
%     f_phys - vector of physical frequencies (Hz) (can be negative)
%   Output:
%     T - table with columns:
%         f_phys        original physical frequencies (Hz)
%         f_alias_fsold alias folded into [0, fs_old/2] (Hz)
%         f_scaled      f_phys scaled to fs_new grid (Hz)
%         f_alias_fsnew alias folded into [0, fs_new/2] (Hz)
%
% Notes:
% - Folding rule used: reduce to [0, fs) via mod, then fold values > fs/2 to fs - value.
% - To obtain signed aliases in [-Nyq, Nyq], change folding accordingly.
%
% Example:
%   fs_old = 1000; fs_new = 100;
%   f_phys = (1:9).' * 25;
%   T = resample_alias_map(fs_old, fs_new, f_phys)

if nargin < 3
    error('Provide fs_old, fs_new, and f_phys');
end

f_phys = f_phys(:);  % column vector

% Helper: fold positive frequencies into [0, fs/2]
fold_to_nyq = @(fs, f) ...
    local_fold(fs, f);

% Alias at original sampling rate
f_alias_fsold = fold_to_nyq(fs_old, f_phys);

% Scale to new sampling grid then alias under fs_new
scale = fs_new / fs_old;
f_scaled = f_phys * scale;
f_alias_fsnew = fold_to_nyq(fs_new, f_scaled);

T = table(f_phys, f_alias_fsold, f_scaled, f_alias_fsnew, ...
    'VariableNames', {'f_phys_Hz','f_alias_at_fsold_Hz','f_scaled_to_fsnew_Hz','f_alias_at_fsnew_Hz'});

end

%% Local helper
function a = local_fold(fs, f)
% reduce to [0, fs)
fm = mod(f, fs);
% fold above Nyquist
Nyq = fs/2;
a = fm;
idx = fm > Nyq;
a(idx) = fs - fm(idx);
% small numeric-cleanup: map tiny negatives/near-zero to 0
tol = eps(max(1,fs));
a(abs(a) < tol) = 0;
end
