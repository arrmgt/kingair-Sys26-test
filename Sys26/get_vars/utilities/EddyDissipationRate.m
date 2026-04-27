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
fny = rate/2;
n=64;
f1 = fny/2;
f2 = fny;
if(f2==fny)
    b1=fir1(n,f1./fny,"high",chebwin(n+1,30));
else
    b1=fir1(n,[f1,f2]./fny,'bandpass',chebwin(n+1,30));
end
a1 = 1;
%    figure(97);
%    freqz(b1,a1,"ctf",512,rate);
TAS = Tas(:,1);
kk1 = find(~isnan(tasx) & ~isinf(tasx) & tasx>-200 & tasx<200 & TAS>40);
tasx1 = interp1(kk1,tasx(kk1),[1:numel(tasx)]','linear',0);
kk1 = find(~isnan(tasy) & ~isinf(tasy) & tasy>-200 & tasy<200 & TAS>40);
tasy1 = interp1(kk1,tasy(kk1),[1:numel(tasx)]','linear',0);
kk1 = find(~isnan(tasz) & ~isinf(tasz) & tasz>-200 & tasz<200 & TAS>40);
tasz1 = interp1(kk1,tasz(kk1),[1:numel(tasx)]','linear',0); 

uwf = zeros(size(TAS));
vwf = zeros(size(TAS));
wwf = zeros(size(TAS));
% Filter
uwf(~isnan(tasx1)) =filter(b1,1,tasx1(~isnan(tasx1))); 
vwf(~isnan(tasy1)) =filter(b1,1,tasy1(~isnan(tasy1))); 
wwf(~isnan(tasz1)) =filter(b1,1,tasz1(~isnan(tasz1)));

% Do running variance for each 10 s block 
%
%
% Compute variances by summing x and x^2 over block 
% using "filter" to make running averages
%
nblock=rate*10; % point blocks (10 sec)
b=ones(nblock,1);
a=1;
tas1 = decimateByFactors(TAS,rate,'FIR');


sx=filter(b,a,uwf);
sx2=filter(b,a,uwf.*uwf);
varu=sx2./nblock-(sx./nblock).^2;
j=find(~isnan(varu) & ~isinf(varu) &  ~isinf(-varu));
varu=interp1(j,varu(j),1:numel(uwf),'linear',0)';

sy=filter(b,a,vwf);
sy2=filter(b,a,vwf.*vwf);
varv=sy2./nblock-(sy./nblock).^2;
j=find(~isnan(varv) & ~isinf(varv) &  ~isinf(-varv));
varv=interp1(j,varv(j),1:numel(vwf),'linear',0)';

sx=filter(b,a,wwf);
sx2=filter(b,a,wwf.*wwf);
varw=sx2./nblock-(sx./nblock).^2;
j=find(~isnan(varw) & ~isinf(varw) &  ~isinf(-varw));
varw=interp1(j,varw(j),1:numel(wwf),'linear',0)';
%
nroll=nblock/rate/2;
varhatu=decimateByFactors((varu),rate,'FIR');
varhatv=decimateByFactors((varv),rate,'FIR');
varhatw=decimateByFactors((varw),rate,'FIR');
varhatu = circshift(varhatu,-nroll);
varhatv = circshift(varhatv,-nroll);
varhatw = circshift(varhatw,-nroll);

tas1(tas1<0) = .1;
% Use Feng Xia MS (2001) eqn 2.20 
I=[f1.^(-2/3)-f2.^(-2/3)].*(tas1./(2.*pi)).^(2/3);

varhatu(find(varhatu<=0 ))=0.001;
varhatv(find(varhatv<=0))=0.001;
varhatw(find(varhatw<=0))=0.001;

% Use Feng Xia MS (2001) eqn 2.20 
I=[f1.^(-2/3)-f2.^(-2/3)].*(tas1./(2.*pi)).^(2/3);

A=1.6;
Clong = 36*A/55;
Clat = 24*A/55;
coefs=[Clong,Clat];
epsiux=(varhatu./(Clong.*mean(I))).^(3/2);
epsivy=(varhatv./(Clat.*mean(I))).^(3/2);
epsiwi=(varhatw./(Clat.*mean(I))).^(3/2);

minTas = 60;
ii=find(tas1<minTas | epsiux>1 | epsivy>1 | epsiwi>1 );
epsiux(ii) = 0.0001;
epsivy(ii) = 0.0001;
epsiwi(ii) = 0.0001;
 
