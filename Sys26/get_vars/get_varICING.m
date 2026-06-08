function get_varICING(X)
% get the XX Hz Rosemount 871 icing data

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

TT=datetime('now');
C=phycon;

%
orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

% Get TASX from get_varTAS run previously
matTAS=fullfile(X.tempdir,sprintf("%s_TAS.mat", X.BaseName));
load(matTAS,'TASX','TEMPX','PSX');

% Raw data inputs
GROUPS = {'ICING'};
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Remove variables that don't exist in raw file;
info = ncinfo(X.RawPath);
ncVarNames = {info.Variables.Name};
rawNames = rawNames(ismember(rawNames, ncVarNames));

clear Var RIPEV VRIP
% find which event is the trip event
Var='RIPEV'

% RIP events
[irate,dims]=get_irate(X.RawPath,Var);
blurf = ncread(X.RawPath,Var);
RIPEV = blurf(:);
ii = ~isnan(RIPEV) & ~isinf(RIPEV);
jj = RIPEV<.05;
kk = find(or(ii,jj));
if(~isempty(kk))
    RIPEV = interp1(kk,RIPEV(kk),[1:numel(RIPEV)]','linear',0);
end
[ninterp,ndecim] = interp_decim(irate,orate);
RIPEV = changeRate(RIPE,irate,orate);

% Output voltage
Var='VRIP'
[irate,dims]=get_irate(X.RawPath,Var);
blurf = ncread(X.RawPath,Var);
VRIP = blurf(:);
kk = find(~isnan(VRIP) & ~isinf(VRIP) );
if(~isempty(kk))
    VRIP = interp1(kk,VRIP(kk),[1:numel(VRIP)]','linear',0);
end
[ninterp,ndecim] = interp_decim(irate,orate);
VRIP = changeRate(VRIP,irate,orate);

% process cumulative number of "trips" (variable rid_cycles)
jj=length(RIPEV);
nrip=zeros(jj,1);
kk=find(diff(RIPEV)>3);% beginning of trip cycle
nrip(kk)=1;
rid_cycles = cumsum(nrip);

DVRIP=gradient(VRIP,1/orate);
mm=length(DVRIP)

%
% x is accreted ice depth;SA=sample area ; 0.5 mm trip
% dm/dt = (SA)*(TAS)*(LWC)=(SA)*(dx/dt)*rhoi ; 
%     dV/dx= 8 = 4 V/0.5e-3 m; rhoi=density of ice is 930kg/m3.
% dx/dt=dV/dt / dV/dx = dV/dt ./ 8e3;
rlwc=DVRIP./8e3.*0.93e3.*1000./TASX;
kk=find(rlwc<0);RLWCXX(kk)=0;

% clamp RLWC to -1 during heating cycle
kk=find(RIPEV>.02);%tripping
rlwc(kk)=-1;
% turn off a low airspeed
kk=find(TASX<20);
rlwc(kk)=0;

ss1="'orate','Rate','rawfile','Time','arcNames','rawNames'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_ICING.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

load_ncFINAL(X.ncFINAL,matfile);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')


sprintf('Processed get_varICING.m for Project: %s',X.PROJ)

%C
%      IF (IVRIP .GT. 0) THEN
%       vrip = 0.
%       do i=1,irsdi(ivrip)
%         vrip = vrip + data(locat(2,ivrip)+lroff+(i-1)*nextloc(ivrip))
%         vripa(i) = data(locat(2,ivrip)+lroff+(i-1)*nextloc(ivrip))
%       enddo
%       VRIP = VRIP / IRSDI(IVRIP)
%       JRID=AND(TEVENT,O'100000')
%       IF(JRID.EQ.O'100000' .AND. JRID.NE.JRIDO) NRIPS=NRIPS+1
%       IF(JRID.EQ.O'100000'.AND.JRID.NE.JRIDO)
%     $      PEVENT=OR(PEVENT,O'10000')
%       JRIDO=JRID
%C  CALCULATE LIQUID WATER CONTENT FROM ROSEMOUNT ICING PROBE
%C  FLAG THAT PROBE IS IN DEICE CYCLE:  LARGE NEGATIVE LWC
%       IF(JRID.EQ.O'100000') VRIPO=1.E4
%C  CHANGE IN DEPTH OF ICE
%C  5 MM ICE CORRESPONDS TO VOLTAE CHANGE OF 4 V
%       CDICE=(VRIP-VRIPO)*0.0125
%       RLWC=9.3E5*CDICE/(TAS*100.)
%       if (date .ge. 900202. .and. date .le. 900228.)   ! WISP
%     $    rlwc = vrip   ! for WISP
%9355   VRIPO=VRIP
%      ELSE
%       RLWC = 0.
%      ENDIF
%Processing get_varICING.m     done

