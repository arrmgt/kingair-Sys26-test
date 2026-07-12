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

% Load time vector to reference lengt=h
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end
nTime = numel(Time);

% Get variables needed for this group
%
orate=X.procRate;
Rate=orate;

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

% Set variable names:
% AV* variables will be rate changed directly
% Others require special handling
imu_names = [ "t_ac_gps" "AVlat" "AVlon" "AVzell" "VX" "VY" "VZ" ...
              "AVroll" "AVpitch" "PlatformHead" "WanderAngle" ...
              "AVlonga" "AVlata" "AVnorma" "AVrollr" "AVpitchr" "AVyawr" ];

imu_units = {'seconds', 'radians', 'radians', 'meters', ...
            'meters/sec', 'meters/sec', 'meters/sec',  ...              
            'radians', 'radians', 'radians', 'radians', ...         
            'meters/sec^2', 'meters/sec^2', 'meters/sec^2',  ...  
            'radians/sec', 'radians/sec', 'radians/sec'};

% Read the sbet data file and convert units
[imudata]=dataAV410(X.AVdata);
[mm,nn]=size(imudata);
nImuVar=mm;

VAR   = struct;
UNITS = struct;
vals = cellstr(imu_units);
for i=1:numel(imu_names)
    name            = imu_names(i);
    VAR.(name)      = imudata(i,:).';
    UNITS.(name)    = vals{i};
end

% *_raw.nc time units will look something like 
%  'seconds since 2021-01-01 00:00:00 +0000'

% Get GPS time information from aircraft time [seconds]
GPSunits=ncreadatt(X.RawPath,rawTimeVar,'units');
GPSformat = ncreadatt(X.RawPath,rawTimeVar,'strptime_format'); 
G = aircraftTime2gpsTime(Time,GPSunits,GPSformat);

% Create aircraft GPS time vector at 200 Hz
% Applanix system outputs time of week without leapsecond
%    or any week epoch rollover
% Syncronize Applanix with local data system

% Create aircraft tow that won't change weeks during flight
% and is not corrected with leapseconds
weekStart = G.week(1);
tow1 = G.gpsSeconds - weekStart * 604800;

%  Create aircraft 200 Hz GPS time vector
PPrate = 200;
deltat = 1/200;
t_ac_gps = [(tow1(1):deltat:(tow1(end)+1-deltat)) - G.leapSeconds(1)]';

%  Get IMU variables from sbet imudata array [17x200]
S = imu2AircraftTime(t_ac_gps, imudata, imu_names);

% wrapped variables treated differently 
%   (eliminate 360 deg jumps before rate changing)
sin1        = changeRate(sin(S.AVlat), PPrate, X.procRate);
cos1        = changeRate(cos(S.AVlat), PPrate, X.procRate);
AVlat       = convertUnits(atan2(sin1,cos1),UNITS.AVlat,'degrees');

sin1        = changeRate(sin(S.AVlon), PPrate, X.procRate);
cos1        = changeRate(cos(S.AVlon), PPrate, X.procRate);
AVlon       = convertUnits(atan2(sin1,cos1),UNITS.AVlat,'degrees');
AVlon       = wrapTo180(AVlon);

% Heading: PlatformHeading is sometimes noisy
H0          = unwrap(S.PlatformHead-S.WanderAngle); %True Heading
[x,TFrm,TFoutlier] = rmoutliers(H0,'movmedian',100*PPrate); % 1/2 sec blocks
zz          = find(~TFoutlier);
H0          = interp1(zz,H0(zz),[1:numel(H0)]','pchip',0);
% Wrap to +- 2*pi
sin1        = changeRate(sin(H0), PPrate, X.procRate);
cos1        = changeRate(cos(H0), PPrate, X.procRate);
AVthead     = atan2(sin1,cos1);
AVthead     = wrapToPi(AVthead);

% Change rate on the others.
%    Keep "AVlata" but not "AVlat" and "PatformHead" 
%    which are already processed.
remove = ["AVlat","AVlon","AVthead","Platform"];
names = imu_names(~ismember(imu_names, remove));
for i = 1:numel(names)
    name = names(i); 
    x = changeRate(S.(name), PPrate, X.procRate) ;
    eval(sprintf('%s = x;', name)) ;
end

% Platform Heading and Wander Angle converts to True Heading
% 
swa         = sin(WanderAngle);
cwa         = cos(WanderAngle);
VNorth      =  VX.*cwa-VY.*swa;
VEast       = -VX.*swa-VY.*cwa;
VUp         = VZ;
AVewvel     = VEast;
AVnsvel     = VNorth;
AVzvel      = VUp; 

% aircraft coords, z down
AVzvel      =-AVzvel;

% MSL Height
% MSL Height
zgeoid      = get_geoid(X.egm,AVlat,AVlon,X.FillValue);
AVzmsl      = AVzell-zgeoid; % ellipsoid height - geoid of
AValt       = AVzmsl;
ALTX        = AVzmsl;

% Ground Speed
AVgs        =sqrt(AVnsvel.^2+AVewvel.^2);

% aircraft coords, z down
AVzvel      = -AVzvel;

kk = find(AVlat == 0);
AVewvel(kk) = 0;
AVnsvel(kk) = 0;

kkk1=find(AVewvel~=0);
% Track angle
AVtrack         =0*ones(size(AVewvel));
AVtrack(kkk1)   =wrapTo360(atan2(AVewvel(kkk1),AVnsvel(kkk1)).*180/pi);


% Ground speed
AVgs        =0*ones(size(AVewvel));
AVgs(kkk1)  =sqrt(AVewvel(kkk1).^2+AVnsvel(kkk1).^2);

% NCAR/EOL "ncplot" needs these to plot X-Y track
GALT        = AVzmsl;
GLON        = AVlon;
GLAT        = AVlat;

ALTX        = AVzmsl;
LONX        = AVlon;
LATX        = AVlat;

kkk2        =find(AVlat~=0 & AVlon~=0);
AVxdist     =0*ones(size(AVlat));
AVydist     =0*ones(size(AVlat));

% Center coordinate for distances
glat0       =ncreadatt(X.ncFINAL,'/','CenterCoordLat0');
glon0       =ncreadatt(X.ncFINAL,'/','CenterCoordLon0');

if license('test', 'map_toolbox');
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
else
    ckmdeg=111.05; % convert deg to km
    MAPPROJ='simple';
    avxdist=(AVlat-glat0).*ckmdeg;
    AVydist=(AVlon-glon0).*ckmdeg.*cos(AVlatXX.*pi./180);
end

AVtopo = zeros(size(AVroll));
AVzagl = zeros(size(AVroll));

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

AVpitch = AVpitch.*180/pi;
AVroll = AVroll.*180/pi;
AVthead = wrapTo2Pi(AVthead).*180/pi;

ss1="'orate','Rate','arcNames','rawNames','AVzell','AVzmsl','AVtrack','AVxdist','AVydist','Time'";
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
procSeconds=round(seconds(TT1-TT))
save(matfile,'-append','procSeconds')
load_ncFINAL(X.ncFINAL,matfile);

sprintf('Processed get_varAV410PP.m for Project: %s',X.PROJ)

end