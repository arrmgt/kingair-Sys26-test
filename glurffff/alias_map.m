function T = alias_map(fs, f_in)
% alias_map  Map input frequencies to aliased frequencies below Nyquist.
%   T = alias_map(fs, f_in) returns a table with columns:
%     f_in        original input frequencies (Hz)
%     f_mod       frequency modulo fs in [0, fs)
%     f_alias     aliased frequency folded into [0, fs/2]
%     status      'DC', 'Nyquist', 'direct', or 'folded'
%
% Example:
%   alias_map(1000, [50, 400, 600, 1500, -250])

if nargin<2, error('Provide fs and f_in'); end
f_in = f_in(:);                    % column vector
Nyq = fs/2;

% Reduce into [0, fs) robustly for negative values
f_mod = mod(f_in, fs);             % in [0, fs)

% Fold into [0, Nyq]
f_alias = f_mod;
over = f_mod > Nyq;
f_alias(over) = fs - f_mod(over);  % mirror frequencies above Nyquist

% Status label
status = repmat("direct", size(f_in));
status(f_alias==0) = "DC";
status(abs(f_alias-Nyq) < eps(max(1,Nyq))) = "Nyquist";
status(over & f_alias~=0 & abs(f_alias-Nyq)>=eps(max(1,Nyq))) = "folded";

% Build table for easy reading
T = table(f_in, f_mod, f_alias, status);
end
