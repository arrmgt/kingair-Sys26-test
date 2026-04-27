function [uwind,vwind,wwind,wdir,wmag,wwindf,ux,vy,VG,VA]=calc_winds(rate,att0,vair,vearth)
%
% Calculate 3D wind components
%
%   Inputs
%       rate        Output rate (/sec)
%       att0        Attitude [roll,pitch,true heading] (radians)
%       vair        True airspeed data variables (structure)
%       vearth      Earth relative data variables (stucture)
%   Outputs
%       uwind       East wind component (m/s)
%       vwind       North wind component (m/s)
%       wwind       Vertical wind component (m/s)
%       wdir        Wind direction (degrees)
%       wmag        Wind magnitude (m/s)
%       wwindf      Vertical wind component (mean removed (m/s)
%       ux          Longitudinal heading relative horizontal wind component (m/s)
%       vy          Lateral heading relative horizontal wind component (m/s)
%       va          Aircraft relative airspeed (x,y,z) components (m/s)
%       vg          Earth relative airspeed components (east,north,up) (m/s)
   
% Retrieve inputs from structures
VEW=vearth.ew;
VNS=vearth.ns;
VZ=vearth.z;
track=vearth.track;

PITCH=att0.pitch;
ROLL=att0.roll;
THEAD=att0.thead;
rolloff=att0.rolloff;
pitoff=att0.pitoff;
hedoff=att0.hedoff;

TAS=vair.tas;
BETA=vair.beta;
ALPHA=vair.alpha;
afactor=vair.afactor;
bfactor=vair.bfactor;
OMEGA=vair.omega;
arm=vair.arm;

att0=[ROLL,PITCH,THEAD]';

% VG are TAS component is earth coordinates
% VA are TAS components in aircraft coordinates 
[VG,VA]=get_vg(  ...
    BETA,ALPHA,TAS,att0,OMEGA,arm,bfactor,afactor,rolloff,pitoff,hedoff);

UWIND = VG(:,1) - VEW;
VWIND = VG(:,2) - VNS;
WWIND = VG(:,3) - VZ;

% calcuclate horizontal wind componets relative to aircraft heading
cthead=cos(THEAD);
sthead=sin(THEAD);
UX=UWIND.*sthead+VWIND.*cthead;
VY=-UWIND.*cthead+VWIND.*sthead;

%High pass filter vertical wind to >1 min period (~60 km)
tPeriod=1.*60;
fny=rate./2;
[bb,aa]=butter(4,1/tPeriod/fny,'high');
zz = find(~isinf(WWIND) & ~isnan(WWIND) ...
    & abs(gradient(WWIND))<5  & TAS>30);
WWIND = interp1(zz,WWIND(zz),[1:numel(WWIND)]','linear',0);
WWINDF=filtfilt(bb,aa,WWIND);

WDIR=atan2(-UWIND,-VWIND).*180./pi; % Wind "from"
hkk=find(WDIR<0.);
WDIR(hkk)=WDIR(hkk)+360.;
WMAG=sqrt(UWIND.^2+VWIND.^2);

uwind=UWIND;
vwind=VWIND;
wwind=WWIND;
wwindf=WWINDF;
ux=UX;
vy=VY;
wdir=WDIR;
wmag=WMAG;
'blurf'
;
