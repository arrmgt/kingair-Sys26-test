function b = kaiser_hp(fs, fc, transWidth, Ap, Ast)
% KAISER_HP  Kaiser-windowed FIR highpass filter.
%
%   fs         : sample rate (Hz)
%   fc         : passband edge (Hz)  -- highpass starts here
%   transWidth : transition width (Hz) -- stopband ends at fc - transWidth
%   Ap         : passband ripple (dB)
%   Ast        : stopband attenuation (dB)
%
%   Stopband:  0  to  fc - transWidth
%   Transition: fc - transWidth  to  fc
%   Passband:  fc  to  fs/2

% Design equivalent lowpass at the mirror cutoff
fc_lp = fs/2 - fc;
b_lp  = kaiser_lp(fs, fc_lp, transWidth, Ap, Ast);

% Spectral inversion: flip sign of every other tap, then invert
% This shifts the spectrum by fs/2, turning LP into HP
n    = length(b_lp);
flip = (-1) .^ (0:n-1);   % [1, -1, 1, -1, ...]
b    = b_lp .* flip;

end