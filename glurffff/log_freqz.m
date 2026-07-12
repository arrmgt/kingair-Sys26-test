function log_freqz(b,a,nfft,fs)
%get frequency response at many points, freq in Hz
nfft = 2048;
[H, f] = freqz(b, a, nfft, fs);   % f in Hz, H complex

% magnitude in dB, avoid f==0 for semilogx
mask = f>0;
semilogx(f(mask), 20*log10(abs(H(mask))))
grid on
xlabel('Frequency (Hz)')
ylabel('Magnitude (dB)')
title('Frequency Response')