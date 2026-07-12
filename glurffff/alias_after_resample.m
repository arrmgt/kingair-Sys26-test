function T = alias_after_resample(fs, f_in)
% alias_after_resample  Map input frequencies to aliased frequencies ≤ Fny.
%   T = alias_after_resample(fs, f_in)
%   Inputs:
%     fs   - new sampling frequency (Hz)
%     f_in - vector of input frequencies (Hz), can be negative or > fs
%   Output table T with columns:
%     f_in    original frequencies
%     f_mod   reduced to [0, fs)
%     f_alias folded into [0, fs/2]
%     status  'DC', 'Nyquist', 'direct', or 'folded'
%
% Example:
%   alias_after_resample(1000, [50, 490, 510, 1500, -250])

if nargin<2, error('Provide fs and f_in'); end
f_in = f_in(:);
Nyq = fs/2;

% reduce into [0, fs) (works for negative values too)
f_mod = mod(f_in, fs);

% fold into [0, Nyq]
f_alias = f_mod;
aboveNyq = f_mod > Nyq;
f_alias(aboveNyq) = fs - f_mod(aboveNyq);

% labels
status = repmat("direct", size(f_in));
status(f_alias==0) = "DC";
status(abs(f_alias-Nyq) <= eps(max(1,Nyq))) = "Nyquist";
status(aboveNyq & f_alias~=0 & abs(f_alias-Nyq)>eps(max(1,Nyq))) = "folded";

T = table(f_in, f_mod, f_alias, status);
end
