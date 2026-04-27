function get_varAVWINDPP(X)


TT=datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

% Load time vector to reference length
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

[pitoff,rolloff,hedoff,bfactor,afactor,Qfactor] = AV410_factors(X.ncFINAL);

matTAS=fullfile(X.tempdir,sprintf("%s_TAS.mat", X.BaseName));
load(matTAS,'TASX','alpha','beta');
matAV410PP=fullfile(X.tempdir,sprintf("%s_AV410PP.mat",X.BaseName));
load(matAV410PP);

TT=datetime('now');% save processing start G
;
ProbeSuffix=[];
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS={'AVWINDPP'};
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

kk=find(TASX>30);

% Moment arm from IMU to boom tip
IMU2NBarm = ncreadatt(X.ncFINAL,'/','AWinds.MomentArm');


vearth.ew=AVewvel(kk);
vearth.ns=AVnsvel(kk);
vearth.z=AVzvel(kk);
vearth.track=AVtrack(kk);

att0.pitch=AVpitch(kk).*pi./180.;
att0.roll=AVroll(kk).*pi./180.;
att0.thead=AVthead(kk).*pi./180.;
att0.rolloff=rolloff;
att0.pitoff=pitoff;
att0.hedoff=hedoff;

OMEGA=[AVrollr,AVpitchr,AVyawr];
vair.tas=TASX(kk);
vair.alpha=alpha(kk);% matlab has functions named alpha and beta
vair.beta=beta(kk);
vair.afactor=afactor;
vair.bfactor=bfactor;
vair.omega=OMEGA(kk,:);
vair.arm=IMU2NBarm;

zeroz = zeros(size(TASX));
AVuwind = zeroz;
AVvwind = zeroz;
AVwwind = zeroz;
AVwdir = zeroz;
AVwmag = zeroz;
AVwwindf = zeroz;
AVux = zeroz;
AVvy = zeroz;

[uwind,vwind,wwind,wdir,wmag,wwindf,ux,vy,VG,VA]= ...
calc_winds(orate,att0,vair,vearth);

AVuwind(kk)=uwind;
AVvwind(kk)=vwind;
AVwwind(kk)=wwind;
AVwdir(kk)=wdir;
AVwmag(kk)=wmag;
AVwwindf(kk)=wwindf;
AVux(kk)=ux;
AVvy(kk)=vy;

% Recommended values
WDIRX=AVwdir;
WMAGX=AVwmag;
WWX=AVwwind;
ncwriteatt(X.ncFINAL,'WDIRX','Sensor','Applanix post-processed');
ncwriteatt(X.ncFINAL,'WMAGX','Sensor','Applanix post-processed');
ncwriteatt(X.ncFINAL,'WWX','Sensor','Applanix post-processed');

% select frequency band, with respect to fny
fs50 = 50;
fny = fs50/2;
f1=fny/2;
f2= fny;
[epsiux,epsivy,epsiwi,sighatu,sighatv,sighatw,uwf,vwf]= ...
    EddyDissipationRate(TASX,AVux,AVvy,AVwwind,f1,f2,X.procRate);
AVedr = epsiwi.^(1/3);

ss1="'orate','Rate','rawfile','arcNames','rawNames','Time','vair','vearth','att0'";
for ii=1:numel(arcNames);
    ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_AVWINDPP.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')
;
load_ncFINAL(X.ncFINAL,matfile);


sprintf('Processed get_varAVWINDPP.m for Project: %s',X.PROJ)
