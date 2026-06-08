% SPEC. Power spectrum estimate of one or two REAL data sequences. 
function [P,freq,T] = spec(x,y,m,noverlap,rfact)
%$Source: /home/cvs/kingair/Sys09/spec.m,v $
%Project $Name:  $ ($Revision: 1.2 $)
%$Date: 2023/04/10 18:06:19 $
%
% [P,F,T]=SPEC(X,Y,M,NOVERLAP,RFACT)  - for two sequences
% [P,F,T]=SPEC(X,Y,M,NOVERLAP)
% [P,F,T]=SPEC(X,Y,M)
%
% performs FFT analysis of the two sequences X and Y using the Welch method of
% power spectrum estimation.  The X and Y sequences of N points are divided
% into K sections of M(1) points each.	Using an M(2)-point (M(2) must be power
% of 2) FFT, successive M(1)-point sections are Hanning windowed, padded with
% zeros to M(2), FFT'd and accumulated. RFACT, if exist, defines time
% interpolation factor for auto/cross-covariance function.  The allowed values
% are: 1,2,4 (default is 1).
%
% SPEC returns the M(2)/2+1 by 9 array:
% 
%	  P = [Pxx Pyy Pxy Txy Cxy Rxy Pxxc Pyyc Pxyc],
%         where
%	        Pxx  - X-vector power spectral density
%	        Pyy  - Y-vector power spectral density
%	        Pxy  - Cross spectral density
%	        Txy  - Complex transfer function from X to Y
%		       (Use ABS and ANGLE for magnitude and phase)
%	        Cxy  - Coherence function between X and Y
%               Rxy  - Cross covariance function for lags from -M(2)/4 to M(2)/4
%
%	        Pxxc,Pyyc,Pxyc - Confidence range (95 percent).
%
%         F    - given the sampling frequency Fs=1/M(3), returns a vector of
%                freqs. the same length as P.  The default for Fs is 1.
%
%         T    - time lags for Rxy (according to the value of RFACT) 
%  
% If you enter M(3) equal to the sampling interval(in sec) Pxx, Pyy and Pxy
% will be properly scaled (for more info TYPE SPEC).  P = SPEC(X,Y,M,NOVERLAP)
% specifies that the  M(1)-point sections should overlap NOVERLAP points.
%
% [P,F,T]=SPEC(X,M,NOVERLAP,RFACT)  - for single sequence
% [P,F,T]=SPEC(X,M,NOVERLAP)
% [P,F,T]=SPEC(X,M)
%
%	  P = [Pxx Rxx Pxxc],
%         where
%	        Pxx  - X-vector power spectral density
%	        Rxx  - X-vector autocovariance
%	        Pxxc - Pxx Confidence range (95 percent)

%	J.N. Little 7-9-86
%	Revised 4-25-88 CRD, 12-20-88 LS, 8-31-89 JNL, 6-19-91 SJH
%	Copyright (c) 1986-89 by the MathWorks, Inc.

%	1) The units on the power spectra Pxx and Pyy when you use time
%	scale factor M(3) are such that, using Parseval's theorem:
%
%	SUM(Pxx)/(M(3)*LENGTH(Pxx)) = SUM(X.^2)/LENGTH(X),     (real signal)
%
%	2) The units on the power spectra Pxx and Pyy when you don't use
%	time scale factor M(3) are such that, using Parseval's theorem:
%
%	SUM(Pxx)/LENGTH(Pxx) = SUM(X.^2)/LENGTH(X) = COV(X),  (real signal)
%
%	The RMS value of the signal is the square root of this.
%	If the input signal is in Volts as a function of time, then
%	the units on Pxx are Volts^2*seconds = Volt^2/Hz.
%	To normalize Pxx so that a unit sine wave corresponds to
%	one unit of Pxx, use Pn = 2*SQRT(Pxx/LENGTH(Pxx))
%
%	Here are the covariance, RMS, and spectral amplitude values of
%	some common functions:
%	  Function   Cov=SUM(Pxx)/LENGTH(Pxx)	RMS	   Pxx
%	  a*sin(w*t)	    a^2/2	     a/sqrt(2)	 a^2*LENGTH(Pxx)/4
%Normal:  a*rand(t)	    a^2 	     a		 a^2
%Uniform: a*rand(t)	    a^2/12	     a/sqrt(12)  a^2/12
%
%	For example, a pure sine wave with amplitude A has an RMS value
%	of A/sqrt(2), so A = SQRT(2*SUM(Pxx)/LENGTH(Pxx)).
%
%	See Page 556, A.V. Oppenheim and R.W. Schafer, Digital Signal
%	Processing, Prentice-Hall, 1975.

Sf = 1; 	    % scale factor for the samp.int = 1s and two-sided spectrum

if (isreal(x) == 0 | isreal(y) == 0)
   disp('This routine does not work for complex signals.')
   return
end

nargin1=nargin;
if (nargin1 == 2)
   rfact = 1;
   if length(y) == 1
      m = y; mm = m; noverlap = 0;
   else
      m = y(1); mm = y(2); noverlap = 0;
      if length(y) == 3 Sf = y(3); end	% scale factor for the actual sampling
   end
elseif (nargin1 == 3)
   rfact = 1;
   if (length(y) == 1)
      nargin1 = 2;
      noverlap = m;
      m = y; mm = m;
   elseif (length(y) == 2 | length(y) == 3)
      nargin1 = 2;
      noverlap = m;
      m = y(1); mm = y(2);
      if length(y) == 3 Sf = y(3); end
   else
      noverlap = 0;
      if length(m) == 3 Sf = m(3); end
      if length(m) > 1 mm = m(2); m = m(1); else mm = m; end
   end
elseif (nargin1 == 4)
   if ((length(y) ~= length(x)) & length(y) < 4)
      nargin1 = 2;
      rfact = noverlap;
      noverlap = m;
      if isempty(noverlap) noverlap = 0; end
      if (length(y) > 1) m = y(1); mm = y(2); else m = y;  mm = m; end
      if length(y) == 3 Sf = y(3); end
   else
      rfact = 1;
      if length(m) == 3 Sf = m(3); end
      if length(m) > 1 mm = m(2); m = m(1); else mm = m; end
   end
elseif (nargin1 == 5)
   if length(m) == 3 Sf = m(3); end
   if length(m) > 1 mm = m(2); m = m(1); else mm = m; end
   if isempty(noverlap) noverlap = 0; end
end

if ~(rfact == 1 | rfact == 2 | rfact == 4) rfact = 1; end

x = x(:);				% Make sure x and y are column vectors
y = y(:);
Fs= 1/Sf;                               % Sampling frequency
n = length(x);				% Number of data points

k = fix((n-noverlap)/(m-noverlap));	% Number of windows
					% (k = fix(n/m) for noverlap=0)
index = 1:m;
w = hanning(m); 	  % Window specification; change this if you want:
			  % (Try HAMMING, BLACKMAN, BARTLETT, or your own)
KMU = k*norm(w)^2 ./Sf;   % Scale factor

if (nargin1 == 2)	  % Single sequence case.
	Pxx = zeros(mm,1); Pxx2 = zeros(mm,1); cPxx = zeros(mm,1);
	for ii=1:k
		xw = w.*detrend(x(index));
		index = index + (m - noverlap);
		Xx = abs(fft(xw,mm)).^2;
		Pxx = Pxx + Xx;
		Pxx2 = Pxx2 + abs(Xx).^2;
	end

        % Select appropriate points

        if rem(mm,2),    % mm odd
           ii = (mm+1)/2;
	else
           ii = mm/2+1;       % include DC AND Nyquist
	end

        select = [1:ii];

        % Calculate autocovariance (biased) and lag axis

        ii = fix(mm/2)+1;
        if rfact > 1
           Xx = [0; Pxx(2:ii);zeros((rfact-1)*mm,1); Pxx(ii+1:mm)];
        else 
           Xx = Pxx;
        end

        Xx = rfact*mm*real(ifft(Xx))./sum(Pxx);

        if rfact > 1 Xx = [Xx(1:ii-1); Xx((rfact-0.5)*mm+1:rfact*mm)]; end 
        Xx = Xx(select);
        T = (0:ii-1)'./(rfact*Fs);

        % Finilize the output

	Pxx=Pxx(select); Pxx2=Pxx2(select); cPxx=zeros(size(Pxx));

	if k > 1
		c = (k.*Pxx2-abs(Pxx).^2)./(k-1);
		c = max(c,zeros(size(c)));
		cPxx = sqrt(c);
	end
	pp = 0.95;		  % 95 percent confidence.
	f = sqrt(2)*erfinv(pp);   % Equal-tails. Use inverse error function
	P = [Pxx./KMU Xx f.*cPxx./KMU];
        freq = (select - 1)'*Fs/mm;
	return
end

Pxx = zeros(mm,1);                % Dual sequence case.
Pyy = Pxx; Pxy = Pxx; Pxx2 = Pxx; Pyy2 = Pxx; Pxy2 = Pxx;

for ii=1:k   
	xw = w.*detrend(x(index));
	yw = w.*detrend(y(index));
	index = index + (m - noverlap);
	Xx = fft(xw,mm);
	Yy = fft(yw,mm);
	Yy2 = abs(Yy).^2;
	Xx2 = abs(Xx).^2;
	Xy  = Yy .* conj(Xx);
	Pxx = Pxx + Xx2;
	Pyy = Pyy + Yy2;
	Pxy = Pxy + Xy;
	Pxx2 = Pxx2 + abs(Xx2).^2;
	Pyy2 = Pyy2 + abs(Yy2).^2;
	Pxy2 = Pxy2 + Xy .* conj(Xy);
end



% Select appropriate points

  if rem(mm,2),    % mm odd
     ii = (mm+1)/2;
  else
     ii = mm/2+1;       % include DC AND Nyquist
  end

  select = [1:ii];


% Calculate autocovariance (biased) and lag axis

  ii = fix(mm/2); jj = ii+1; 
  if rfact > 1
     Xy = [0; Pxy(2:ii);zeros((rfact-1)*mm,1); Pxx(jj:mm)];
  else 
     Xy = Pxy;
  end

  Xy = rfact*mm*real(ifft(Xy))/sqrt(sum(Pxx)*sum(Pyy));
  Xy = [Xy(rfact*mm-fix(jj/2)+(mod(jj,2) == 0):rfact*mm); Xy(1:fix(jj/2))]; 

  T = ((0:ii)-fix(jj/2)-1+(mod(jj,2) == 0))'./(rfact*Fs);

% Finilize the output

Pxx = Pxx(select); Pxx2=Pxx2(select);
Pyy = Pyy(select); Pyy2=Pyy2(select);
Pxy = Pxy(select); Pxy2=Pxy2(select);

cPxx = zeros(size(Pxx)); cPyy = cPxx; cPxy = cPxx;

if k > 1
   c = max((k.*Pxx2-abs(Pxx).^2)./(k-1),zeros(size(Pxx)));
   cPxx = sqrt(c);
   c = max((k.*Pyy2-abs(Pyy).^2)./(k-1),zeros(size(Pyy)));
   cPyy = sqrt(c);
   c = max((k.*Pxy2-abs(Pxy).^2)./(k-1),zeros(size(Pxy)));
   cPxy = sqrt(c);
end

Txy = Pxy./Pxx;
Cxy = (abs(Pxy).^2)./(Pxx.*Pyy);

pp = 0.95;			   % 95 percent confidence.
f = sqrt(2)*erfinv(pp); 	   % Equal-tails.

P = [ [Pxx Pyy Pxy]./KMU Txy Cxy Xy f.*[cPxx cPyy cPxy]./KMU ];
freq = (select - 1)'*Fs/mm;
