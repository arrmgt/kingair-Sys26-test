% x: column measurement vector, Fs sample rate, f_harm: vector of expected harmonic freqs
function A = harmonic_amplitudes_fft(x, Fs, f_harm, winType, Nfft)
if nargin<4 || isempty(winType), winType = 'hann'; end
if nargin<5 || isempty(Nfft), Nfft = 4*length(x); end

x = x(:);
x = x - mean(x);

n = length(x);
% create window safely from name or handle
if isa(winType,'function_handle')
    w = winType(n);
else
    w = feval(char(winType), n);   % 'hann', 'hamming', etc.
end

cg = mean(w);
xw = x .* w;

X = fft(xw, Nfft);
half = floor(Nfft/2)+1;
X1 = X(1:half);
freqs = (0:half-1)' * (Fs/Nfft);

Aps = abs(X1)/n * 2 / cg;
Aps(1) = abs(X1(1))/n / cg;
if rem(Nfft,2)==0
    Aps(end) = abs(X1(end))/n / cg;
end

A = zeros(size(f_harm));
for k=1:numel(f_harm)
    [~,idx] = min(abs(freqs - f_harm(k)));
    A(k) = Aps(idx);
end
end

