 function get_varAVWINDRT(X)

TT = datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

% Load time vector to reference length
try
    Time = ncread(X.RawPath,'time');
    rawTimeVar  =  'time';
catch
    Time  =  ncread(X.RawPath,'Time');
    rawTimeVar  =  'Time';
end

% This might be needed
clear ncinfo ncreadatt ncwriteatt

% Get raw variables needed for this group
%
orate = X.procRate;
Rate = orate;
rawfile = X.RawPath;

matTAS = fullfile(X.tempdir,sprintf("%s_TAS.mat", X.BaseName));
load(matTAS,'TASX','alpha','beta');
matAV410RT = fullfile(X.tempdir,sprintf("%s_AV410RT.mat",X.BaseName));
load(matAV410RT);
clear vearth att0 vair

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.ncfill*onez
GROUPS = {'AVWINDRT'};
[arcNames, rawNames]  =  getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

fill = X.FillValue;


% Fill output variables with zeros
zeroz  =  zeros(size(TASX));
avuwind = zeroz;
avvwind = zeroz;
avwwind = zeroz;
avwwindf = zeroz;
avwdir = zeroz;
avwmag = zeroz;
avux = zeroz;
avvy = zeroz;

kk = find(TASX>30);

% Moment arm from IMU to boom tip
IMU2NBarm  =  ncreadatt(X.ncFINAL,'/','AWinds.MomentArm');

% Wind ajustment factors
[pitoff,rolloff,hedoff,bfactor,afactor,PStaticOffset] = AV410_factors(X.ncFINAL);

vearth.ew = avewvel(kk);
vearth.ns = avnsvel(kk);
vearth.z = avzvel(kk);
vearth.track = avtrack(kk);

att0.pitch = avpitch(kk).*pi./180.;
att0.roll = avroll(kk).*pi./180.;
att0.thead = avthead(kk).*pi./180.;
att0.rolloff = rolloff;
att0.pitoff = pitoff;
att0.hedoff = hedoff;

OMEGA = [avrollr,avpitchr,avyawr];
vair.tas = TASX(kk);
vair.alpha = alpha(kk)*pi/180;
vair.beta = beta(kk)*pi/180;
vair.afactor = afactor;
vair.bfactor = bfactor;
vair.psoffset = PStaticOffset;
vair.omega = OMEGA(kk,:);
vair.arm = IMU2NBarm;

[uwind,vwind,wwind,wdir,wmag,wwindf,ux,vy,vg,va] =  ...
    calc_winds(orate,att0,vair,vearth);
%
avuwind(kk) = uwind;
avvwind(kk) = vwind;
avwwind(kk) = wwind;
avwdir(kk) = wdir;
avwmag(kk) = wmag;
avwwindf(kk) = wwindf;
avux(kk) = ux;
avvy(kk) = vy;

% Save recommended variables to global attributes
WDIRX = avwdir;
WMAGX = avwmag;
WWX = avwwind;
ncwriteatt(X.ncFINAL,'WDIRX','Sensor','Applanix real-time');
ncwriteatt(X.ncFINAL,'WMAGX','Sensor','Applanix real-time');
ncwriteatt(X.ncFINAL,'WWX','Sensor','Applanix real-time');

% Eddy dissipatation rate
if X.procRate>20 % only if high-rate processing
    % Eddy Dissipation Rate calculation for orate  =  25 Hz
    fny = X.procRate/2;
    % select frequency band, with respect to fny
    f1 = fny/10;
    f2 =  fny;
    [~,~,epsiwi] =  ...
    EddyDissipationRate(TASX,avux,avvy,avwwind,f1,f2,X.procRate);
    avEDR  =  epsiwi.^(1/3);
else
    avEDR = zeros(size(Time));
end


ss1 = "'orate','Rate','rawfile','arcNames','rawNames','Time','vair','vearth','att0'";
for ii = 1:numel(arcNames);
    ss1 = sprintf("%s,'%s'",ss1,arcNames{ii});
end

% Write variables out to matfile
matfile = fullfile(X.tempdir,sprintf("%s_AVWINDRT.mat",X.BaseName));
delete(matfile)

ss = sprintf("save(matfile,%s);",ss1);eval(ss);

load_ncFINAL(X.ncFINAL,matfile);
TT1 = datetime('now');
procSeconds = seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')

sprintf('Processed get_varAVWINDRT.m for Project: %s',X.PROJ)

 end

