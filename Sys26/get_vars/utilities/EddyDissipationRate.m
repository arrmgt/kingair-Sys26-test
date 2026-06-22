function [epsiux,epsivy,epsiwi,varhatu,varhatv,varhatw,uwf,vwf] = ...
    EddyDissipationRate(Tas,tasx,tasy,tasz,f1,f2,rate)
% 
% Transform winds to along track and cross track components
%   and then estimate EDRs
%

% Inputs wind in along- and cross-track components .
%
% Create bandpass filter
%
% Construct FIR filter
fs         = rate;
fc         = 1.1;       % passband edge: highpass starts here
transWidth = 0.5;       % transition band: 0 to 1 Hz is stopband, 1 to 2 Hz transitionf
Ap         = 0.1;
Ast        = 80;      % full 80 dB (use filtfilt -> 160

b1 = kaiser_hp(fs, fc, transWidth, Ap, Ast);
a1 = 1;

kk1 = find(~isnan(tasx) & ~isinf(tasx) & Tas< 200);
tasx1 = interp1(kk1,tasx(kk1),1:numel(tasx),'linear',1)';
tasy1 = interp1(kk1,tasy(kk1),1:numel(tasy),'linear',1)';
tasz1 = interp1(kk1,tasz(kk1),1:numel(tasz),'linear',1)';



uwf = zeros(size(Tas));
vwf = zeros(size(Tas));
wwf = zeros(size(Tas));
% High-pass filter
uwf(~isnan(tasx1)) = filtfilt(b1,1,tasx1); 
vwf(~isnan(tasy1)) = filtfilt(b1,1,tasy1); 
wwf(~isnan(tasz1)) = filtfilt(b1,1,tasz1);

% Remove outliers
[B,TFrm,TFoutlier] = rmoutliers(uwf,'percentiles],[5,95]);
x = interp1(find(~TFrm),uwf(find(~TFrm)),[1:numel(uwf)]','linear',0);


% Do running variance for each 10 s block 
%
%
% Compute running variances 
%
nblock=rate*10; % point blocks (10 sec)

varu = movvar(uwf,nblock); % movvar centers value so no shift needed.
varv = movvar(vwf,nblock);
varw = movvar(wwf,nblock);

% Change rate to 1 Hz.
varhatu = changeRate(varu,rate,1);
varhatv = changeRate(varv,rate,1);
varhatw = changeRate(varw,rate,1);

tas1 = changeRate(Tas,rate,1); % to 1 Hz
tas1(tas1<0) = .1;
% Use Feng Xia MS (2001) eqn 2.20 
I=[f1.^(-2/3)-f2.^(-2/3)].*(tas1./(2.*pi)).^(2/3);

varhatu(find(varhatu<=0))  = 1e-5;
varhatv(find(varhatv<=0))  = 1e-5;
varhatw(find(varhatw<=0))  = 1e-5;

% Use Feng Xia MS (2001) eqn 2.20 
I=[f1.^(-2/3)-f2.^(-2/3)].*(tas1./(2.*pi)).^(2/3);
kk      = find(~isnan(I) & ~isnan(tas1));
Ia      = interp1(kk,   I(kk),[1:numel(I)]',   'linear',1 );
tas1a   = interp1(kk,tas1(kk),[1:numel(tas1)]','linear',20);

A=1.6;
Clong = 36*A/55;
Clat = 24*A/55;
coefs=[Clong,Clat];
epsiux = (varhatu./(Clong.*mean(Ia))).^(3/2);
epsivy = (varhatv./( Clat.*mean(Ia))).^(3/2);
epsiwi = (varhatw./( Clat.*mean(Ia))).^(3/2);

minTas = 30;
ii=find(tas1a<minTas | epsiux>1 | epsivy>1 | epsiwi>1 );
epsiux(ii) = 0.00001;
epsivy(ii) = 0.00001;
epsiwi(ii) = 0.00001;
 

end
