function get_varAV410PP(X)
% AV data structure
%  1 time                  seconds
%  2 latitude              radians
%  3 longitude             radians
%  4 altitude              meters
%  5 x velocity            meters/sec
%  6 y velocity            meters/sec
%  7 z velocity            meters/sec
%  8 roll                  radians
%  9 pitch                 radians
% 10 platform heading      radians
% 11 wander angle          radians
% 12 x body accel          meters/sec2
% 13 y body accel          meters/sec2
% 14 z body accel          meters/sec2
% 15 x body angular rate   radians/sec
% 16 y body angular rate   radians/sec
% 17 z body angular rate   radians/sec

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

% Get raw variables needed for this group
%
orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS = 'AV410PP';
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% AV post processed data is 200 Hz;
irate=200;
deltat=1/200;
orate=X.procRate;
Rate=orate;
[ninterp,ndecim]=interp_decim(irate,orate);

% Read the sbet data file and convert units
[imudata]=dataAV410(X.AVdata);
[mm,nn]=size(imudata);
nImuVar=mm;
GPSTime0=imudata(1,:)';
Lat0=imudata(2,:)'*180./pi;  
Lon0=imudata(3,:)'*180./pi;  
Ell0=imudata(4,:)';  
VX0=imudata(5,:)';
VY0=imudata(6,:)';
VZ0=imudata(7,:)';   
Roll0=imudata(8,:)'*180./pi;
Pitch0=imudata(9,:)'*180./pi;
PlatformHead0=imudata(10,:)'*180./pi;
WanderAngle0=imudata(11,:)'*180./pi;
Xaccel0=imudata(12,:)';
Yaccel0=imudata(13,:)';
Zaccel0=imudata(14,:)';
Xangr0=imudata(15,:)';
Yangr0=imudata(16,:)';
Zangr0=imudata(17,:)';

[mm,nn]=size(imudata);

% Get time in seconds from raw file
time=ncread(X.RawPath,rawTimeVar);

% *_raw.nc time units will look something like 
%  'seconds since 2021-01-01 00:00:00 +0000'

GPSunits=ncreadatt(X.RawPath,rawTimeVar,'units');
% string parse time format
GPSformat = ncreadatt(X.RawPath,rawTimeVar,'strptime_format'); 
G = aircraftTime2gpsTime(time,GPSunits,GPSformat);

% Create aircraft GPS time vector at 200 Hz
% Applanix system outputs time of week without leapsecond
%    or any week epoch rollover
% Syncronize Applanix with local data system

% Create aircraft tow that won't change weeks during flight
% and is not corrected with leapseconds
weekStart = G.week(1);
tow1 = G.gpsSeconds - weekStart * 604800;

deltat=1/200;
t_ac_gps = [(tow1(1):deltat:(tow1(end)+1-deltat)) - G.leapSeconds(1)]';
t01=t_ac_gps;  % aircraft GPS time
t00=imudata(1,:)'; % Applanix GPS time

% Syncronize aircraft and GPS times
Lat=interp1(t00,Lat0,t01,'nearest',0);
Lon=interp1(t00,Lon0,t01,'nearest',0);
Ell=interp1(t00,Ell0,t01,'nearest',0);
VX=interp1(t00,VX0,t01,'nearest',0);
VY=interp1(t00,VY0,t01,'nearest',0);
VZ=interp1(t00,VZ0,t01,'nearest',0);
Roll=interp1(t00,Roll0,t01,'nearest',0);
Pitch=interp1(t00,Pitch0,t01,'nearest',0);
PlatformHead=interp1(t00,PlatformHead0,t01,'nearest',0);
WanderAngle=interp1(t00,WanderAngle0,t01,'nearest',0);
Xaccel=interp1(t00,Xaccel0,t01,'nearest',0);
Yaccel=interp1(t00,Yaccel0,t01,'nearest',0);
Zaccel=interp1(t00,Zaccel0,t01,'nearest',0);
Xangr=interp1(t00,Xangr0,t01,'nearest',0);
Yangr=interp1(t00,Yangr0,t01,'nearest',0);
Zangr=interp1(t00,Zangr0,t01,'nearest',0);

% True heading and ground velocities from platform and wander angles
Head=PlatformHead-WanderAngle;
swa=sin(WanderAngle*pi/180.);
cwa=cos(WanderAngle*pi/180.);
VNorth=VX.*cwa-VY.*swa;
VEast=-VX.*swa-VY.*cwa;
VUp=VZ;

AV_lat=Lat;
AV_lon=Lon;
AV_Ell=Ell;
AV_Roll=Roll;
AV_Pitch=Pitch;
AV_Head=Head;
hh=find(AV_Head<0);
AV_Head(hh)=AV_Head(hh)+360;    
AV_vew=VEast;
AV_vns=VNorth;
AV_vz=VUp;
AV_pitchr=Yangr;
AV_rollr=Xangr;
AV_yawr=Zangr;
AV_longa=Xaccel;
AV_lata=Yaccel;
AV_norma=Zaccel;

nac=length(time);
nn=1:nac;
kkfill=find(AV_norma==0); %indices of filled values
kknotfill=setxor(nn,kkfill); % not filled 

AVewvel=decimateByFactors(Ninterp(AV_vew,ninterp,'linear',0),ndecim,'FIR',0);
AVnsvel=decimateByFactors(Ninterp(AV_vns,ninterp,'linear',0),ndecim,'FIR',0);
AVzvel=decimateByFactors(Ninterp(AV_vz,ninterp,'linear',0),ndecim,'FIR',0);

AVroll=decimateByFactors(Ninterp(AV_Roll,ninterp,'linear',0),ndecim,'FIR',0);
AVpitch=decimateByFactors(Ninterp(AV_Pitch,ninterp,'linear',0),ndecim,'FIR',0);

% wrapped variables treated differently
AVlat=changeRateWrapped(AV_lat,ninterp,ndecim,'degree');
LAT=AVlat;
LATC=AVlat;

AVlon=changeRateWrapped(AV_lon,ninterp,ndecim,'degree');
if(AVlon >180); % make -180:180
    AVlon=AVlon-360;
end
LON=AVlon;
LONC=AVlon;

AVthead=changeRateWrapped(AV_Head,ninterp,ndecim,'degree');

% Ellipsoid heihgt
AVzell=decimateByFactors(Ninterp(AV_Ell,ninterp,'linear',0),ndecim,'FIR',0);

% MSL Height
zgeoid=get_geoid(X.egm,AVlat,AVlon,0);
AVzmsl=AVzell-zgeoid;
AVzmsl(AVlat==0)=0;

kk = find(AVlat == 0);
AVewvel(kk) = 0;
AVnsvel(kk) = 0;

kkk1=find(AVewvel~=0);
% Track angle
AVtrack=0*ones(size(AVewvel));
AVtrack(kkk1)=atan2(AVewvel(kkk1),AVnsvel(kkk1)).*180/pi;
jj=find(AVtrack(kkk1)<0);AVtrack(kkk1(jj))=AVtrack(kkk1(jj))+360;

% Ground speed
AVgs=0*ones(size(AVewvel));
AVgs(kkk1)=sqrt(AVewvel(kkk1).^2+AVnsvel(kkk1).^2);

AVrollr=decimateByFactors(Ninterp(AV_rollr,ninterp,'linear',0),ndecim,'FIR',0);
AVpitchr=decimateByFactors(Ninterp(AV_pitchr,ninterp,'linear',0),ndecim,'FIR',0);
AVyawr=decimateByFactors(Ninterp(AV_yawr,ninterp,'linear',0),ndecim,'FIR',0);

AVlonga=decimateByFactors(Ninterp(AV_longa,ninterp,'linear',0),ndecim,'FIR',0);
AVlata=decimateByFactors(Ninterp(AV_lata,ninterp,'linear',0),ndecim,'FIR',0);
AVnorma=decimateByFactors(Ninterp(AV_norma,ninterp,'linear',0),ndecim,'FIR',0);

kkk2=find(AVlat~=0 & AVlon~=0);
AVxdist=0*ones(size(AVlat));
AVydist=0*ones(size(AVlat));

% Center coordinate for distances
glat0=ncreadatt(X.ncFINAL,'/','CenterCoordLat0');
glon0=ncreadatt(X.ncFINAL,'/','CenterCoordLon0');

MAP=X.MAP;
if(exist('MAP','var')==0)
MAP=0; % don't us mapping toolbox
end; % Default to MAP=0
%  Compute distances from center point.
if(MAP==0),%if matlab mapping toolbox not available
    ckmdeg=111.05; % convert deg to km
    MAPPROJ='simple';
    avxdist=(AVlat-glat0).*ckmdeg;
    AVydist=(AVlon-glon0).*ckmdeg.*cos(AVlatXX.*pi./180);
else
    MAPPROJ='eqaazim';
    geoid=almanac('earth','ellipsoid','kilometers');
    wgs84 = wgs84Ellipsoid("m");;
    % convert degrees to kilometers at glat0/glon0
    ckmdeg=distance(glat0-.5,glon0,glat0+.5,glon0,wgs84,'degrees')/1000.;
    % Compute x,y distances from center
    mstruct=defaultm(MAPPROJ);
    mstruct.origin=[glat0 glon0 0];
    mstruct.geoid=geoid;
    [AVxdist,AVydist]=projfwd(mstruct,AVlat,AVlon);
end;

AVtopo = zeros(size(AVroll));
AVzagl = zeros(size(AVroll));


ALTX=AVzmsl;
LATX=AVlat;
LONX=AVlon;
ncwriteatt(X.ncFINAL,'LATX','Sensor','Applanix post-processed');
ncwriteatt(X.ncFINAL,'LONX','Sensor','Applanix post-processed');
ncwriteatt(X.ncFINAL,'ALTX','Sensor','Applanix post-processed');

%  Get terrain height below aircraft
zfiles = fullfile(X.aster,'aster');
Dependencies = sprintf("%s,%s,%s",'LATX','LONX','ALTX');
ncwriteatt(X.ncFINAL,'AVtopo','Dependencies',Dependencies);
ncwriteatt(X.ncFINAL,'AVzagl','database','aster');
[AVtopo,AVzagl] = get_varTOPO(zfiles,LATX,LONX,ALTX);

%%%%%% Store store in output nc file
%%%%%% All angle variables are in radians at this point

ss1="'orate','Rate','rawfile','arcNames','rawNames','AVzell','AVzmsl','AVtrack','AVxdist','AVydist','Time'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        % Build list name for outputing to matfile 
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii}); 
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_AV410PP.mat",X.BaseName));
delete(matfile)
ss=sprintf("save(matfile,%s);",ss1);eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds')
load_ncFINAL(X.ncFINAL,matfile);

sprintf('Processed get_varAV410PP.m for Project: %s',X.PROJ)