function get_varTAS(X)
% GET_VARTAS  Compute TAS-group variables and write to NetCDF + matfile.
%
%   GET_VARTAS(X) reads raw measurements from the project's *_RAW.nc file,
%    computes True Air Speed and  derived thermodynamic variables.
%   Results are written to a matfile which is merged
%    with other measurement group matfiles into the 
%    into the final NetCDF file.
%
%   Required fields of the input struct X are set in the 
%         main calling program do_batch26.m
%
%   Outputs: The list arcNames are variables saved to the matfile
%
%   Local helpers (defined below):
%     get_uvw:  gets hi-rate TAS components for the EDR calculation
%     repair_one:   clean up the end times before TO and after landing.

TT=datetime('now');
% Time attributes
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

C = phycon; % Physical constants
Tzero = C.Tzero;

% Need these if available
needGROUPS = {'TAS'};
mask = contains(X.rawGROUPS,needGROUPS);
%  Need TAS and temp and pressure groups
GROUPS = X.rawGROUPS(mask) ; % Pressures loaded previously
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_RAW.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Read in raw data and change rate as needed; 
%   Changing rate
info = ncinfo(X.RawPath);
RAWNAMES = {info.Variables.Name};   
isPresent = ismember(rawNames,RAWNAMES);

RAW = struct();
RATE = struct();
% Read in data from *_raw.nc, and do some sanity checking
for k = 1:length(rawNames)
    var1 = char(rawNames(k));
    if isPresent(k)
        [blurf,irate] = getdata(X.RawPath, var1);
        kk0=[1:numel(blurf)]';
        kk = find(~isnan(blurf));
        blurf = interp1(kk, blurf(kk), kk0, 'linear', NaN);
        % set left-of-first to first good point 
        %     and right-of-last to last good
        blurf(kk0 < kk(1))   = blurf(kk(1)); 
        blurf(kk0 > kk(end)) = blurf(kk(end));
        RAW.(var1 ) = blurf;
        RATE.(var1) = irate;
    end
end

%**********************TEST TEST TEST
TEST = false
if TEST
    trose1                  = changeRate(RAW.TROSE,RATE.TROSE,1);
    RAW.BuckDewPoint        = trose1 - 10;
    RAW.BuckPressure        = changeRate(RAW.PSA,RATE.PSA,1);
    RAW.BuckBoardTemp       = 33.*ones(size(Time));
    RAW.BuckMirrorFlag      = ones(size(Time));
    RAW.BuckDataFlag        = ones(size(Time));
    RAW.PRES9000            = changeRate(RAW.PSA,RATE.PSA,50);
    %%RAW.PRES6140            = changeRate(RAW.PSA,RATE.PSA,100);
    RATE.BuckDewPoint       = 1;
    RATE.BuckPressure       = 1;
    RATE.BuckBoardTemp      = 1;
    RATE.BuckMirrorFlag     = 1;
    RATE.BuckDataFlag       = 1;
    %%RATE.PRES6140           = 100;
    RATE.PRES9000           = 50;
end
%****** END TEST

% Is Buck TDP installed?
if any(contains(rawNames, "Buck", "IgnoreCase", true));
    %  Keep Buck 1011C status flags at 1 Hz (No rate-changing)
    BuckDataFlag = RAW.BuckDataFlag;
    BuckMirrorFlag = RAW.BuckMirrorFlag;
    tdpFlag = BuckDataFlag + 10*BuckMirrorFlag;
 
    % Remove BuckMirrorFlag and BuckDataFlag variables from rawNames
    RAW = rmfield(RAW,{'BuckMirrorFlag','BuckDataFlag'});
    rawNames = fieldnames(RAW);
end

%   Unpack struct fields to named locals  and change rate.
for i = 1:length(rawNames)
    rawName = strtrim(rawNames{i});
    if isfield(RAW, rawName)
        x = changeRate(RAW.(rawName), RATE.(rawName), X.procRate);
        eval(sprintf("%s = x;",rawName));
    end
end

%  Sanity check (attack angles are largely positive);
if mean(DPA)<0
    DPA = -DPA;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% Get static pressure corrections
%%%%%%%%%%    and remove outliers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% Maneuver results
% Get fcoef from 2005 trailing cone calibration flight
[~,ship_fcoef] = cone_pcor(DP1,DPB,DPA,DPR,PSA);
% Using foef, calculate pcor from 858 equations.
ship_pcor = pcor858(ship_fcoef,DP1,DPA,DPB,DPR,PSA); %pcor858(fcoef,DP1,DPA,DPB,DPR,PSA)
%  Assume PSB-boom_pcor = PSA-ship_pcor, and estimate boom_pcor.
boom_pcor = PSB - PSA + ship_pcor;
if exist('PRES6140','var')
    PRES6140_ship = PRES6140 - ship_pcor;
end
if exist('PRES9000','var')
    PRES9000_ship = PRES9000 - ship_pcor;
end
    

%  Fix segements before takeoff and after landing
[pitoff,rolloff,hedoff,bfactor,afactor,PSfactor] =  ...
        AV410_factors(X.ncFINAL);
accepted = DP1 > 10 & DP1 < 85 & DP2 > 10 & DP2 < 85;
kk = find(accepted);
ship_pcor  = repair_one(ship_pcor, kk) + PSfactor;
boom_pcor  = repair_one(boom_pcor, kk) + PSfactor;
ship_fcoef = repair_one(ship_fcoef, kk);

% Variables to be used in TAS etc.
PressUsed   = X.PressUsed;
TempUsed    = X.TempUsed;
DP1Used     = X.DP1Used;
QUsed       = X.QUsed;
Pcor_used   = X.PcorUsed;

ncwriteatt(X.ncFINAL,'/','PressUsed',PressUsed);
ncwriteatt(X.ncFINAL,'/','TempUsed',TempUsed);
ncwriteatt(X.ncFINAL,'/','DP1Used',DP1Used);
ncwriteatt(X.ncFINAL,'/','QUsed',QUsed);

% Get raw variables needed for tas group
%
orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

%  Get Zgps if available from prevvious get_varAV410RT.m
Zgps = getdata(X.RawPath,'AALT','OutputRate',X.procRate); %Ellipsoid height
if isempty(Zgps)
    Zgps = zeros(size(PTB));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%% Dewpoint (TDPEDGE or Buck 1011C  or ??
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if exist('BuckDewPoint')
    tdp = BuckDewPoint;
    % Frost point?? Then convert to dew point
    kk=find(tdp<0); 
    % Assume Frost Point sensed if tdp<0 C
    if(~isempty(kk))
        tdp(kk) = dew(tdp(kk)); % Frost point is sensed
        % tdp1(kk) = frostpoint_to_dewpoint(tdp1(kk));
    end
    TDPK = tdp + Tzero;
else
    tdp     = -40.*ones(size(DPA));
    TDPK    = tdp + Tzero;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% R858 noseboom variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output variables
%   DPA     --> dpa             "alpha A1 - A2"
%   DPB     --> dpb             "beta  B1 - B2"
%   DPR     --> dpr_beta        "reference P1 - B1"
%   DPN     --> dpr_alpha       "reference P1 - A1"
%   DP1     --> dp1_ship        "P1 - ship static pressure"
%   DP2     --> dp1_boom        "P1 - boom static pressure"
%   PSA     --> ps_ship         "static pressure - ship" 
%   PSB     --> ps_boom         "static pressure - boom"
%   PTB     --> ptotal_boom     "total pressure - boom"
%
correctedVars = string();
ship_pcor   = ship_pcor;
boom_pcor   = boom_pcor;
dp1_ship    = DP1 + ship_pcor;
dp1_boom    = DP2 + boom_pcor;
ps_ship     = PSA - ship_pcor;
ps_boom     = PSB - boom_pcor;
dpa         = DPA;
dpb         = DPB;
dpr_beta    = DPR;
dpr_alpha   = DPN;
[qimpact_ship, f_ship] = solve858(dp1_ship, DPA, DPB, 'dpr', DPR);
[qimpact_boom, f_boom] = solve858(dp1_boom, DPA, DPB, 'dpr', DPR); 
ptotal_boom = qimpact_boom + ps_boom;
ptotal_ship = qimpact_ship + ps_ship;
correctedVars(end+1) = "qimpact_ship";
correctedVars(end+1) = "qimpact_boom";
correctedVars(end+1) = "dp1_ship";
correctedVars(end+1) = "dp2_ship";
correctedVars(end+1) = "ps_ship";
correctedVars(end+1) = "ps_boom";
correctedVars(end+1) = "ptotal_ship";
correctedVars(end+1) = "ptotal_boom";

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Available pressures?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pressureVars = struct();
pressureVars.('ps_ship') = ps_ship; % Always exists
pressureVars.('ps_boom') = ps_boom; % Always exists
% CPT 6140
if exist('PRES6140','var')
    ps_CPT6140 = PRES6140 - ship_pcor;
    pressureVars.('ps_CPT6140') = RAW.PRES6140;
    correctedVars(end+1) = 'ps_CPT6140';
end
% CPT 9000 pressured
if exist('PRES9000','var')
    ps_CPT9000 = PRES9000 - ship_pcor;
    pressureVars.('ps_CPT9000') = ps_CPT9000;
    correctedVars(end+1) = 'ps_CPT9000';
end
% Which should be used (call it PSM)
PSM = pressureVars.(X.PressUsed); % corrected

temperatureVars = struct();
% Rosemount temperature
if exist('TROSE','var')
    units = ncreadatt(X.RawPath,'TROSE','units');
    if contains(lower(units),'celsius')
        TROSE = TROSE + Tzero;
    end
    temperatureVars.('TROSE') = RAW.TROSE ;
end

% Reverse flow temperature
if exist('TRF','var')
    units = ncreadatt(X.RawPath,'TRF','units');
    if contains(lower(units),'celsius')
        TRF = TRF + Tzero;
    end
    temperatureVars.('TRF') = RAW.TRF ;
end
% Which should be used (call it TEMPmeasK)
TEMPmeasK = temperatureVars.(X.TempUsed);

if exist('TEMP9000','var')
    temp_CPT9000=TEMP9000;
end

% Which DP1 = P1 - Pstatic to use
dp1Vars = struct();
dp1Vars.('dp1_ship') = dp1_ship;
dp1Vars.('dp1_boom') = dp1_boom;
% Which should be used (call it DP1X);
DP1X = dp1Vars.(X.DP1Used);
correctedVars(end+1) = 'DP1X';

% CPT 9000 temperature
if exist('TEMP9000','var') 
    temp_CPT9000=TEMP9000;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Calculate 858 variables
%%%%%%   DP1 and DP2 without pressure correction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
M = getDerivedVariablesR858( ...
    DPB, DPA, DPR, DPN, ...
    DP1, DP2, PSA ,  PSB );

% All these variables are now pressure corrected as needed
ta_alpha    = M.ta_alpha;
ta_beta     = M.ta_beta;
tb_alpha    = M.tb_alpha;
tb_beta     = M.tb_beta;
fq_alpha    = M.fq_alpha;
fq_beta     = M.fq_beta;

q_ship_alpha = M.ship.q_alpha;
q_ship_beta  = M.ship.q_beta;
q_boom_alpha = M.boom.q_alpha;
q_boom_beta  = M.boom.q_beta;

f_ship_alpha = M.ship.f_alpha ;
f_ship_beta  = M.ship.f_beta;
f_boom_alpha = M.boom.f_alpha;
f_boom_beta  = M.boom.f_beta;


% Which pcor should be used (call it PCORX) -- set in do_batch26
pcorVars = struct();
pcorVars.('ship_pcor') =  ship_pcor;
pcorVars.('boom_pcor') =  boom_pcor;
% Which should be used (call it PCORX);
PCORX = pcorVars.(X.PcorUsed);

% QimpactX is the recommended impact pressure (corrected)
qVars = struct;
qVars.q_ship = qimpact_ship ; % corrected
qVars.q_boom = qimpact_boom ; % corrected
QimpactX = qVars.(X.QUsed);
q_impact = QimpactX;
q_boom = qimpact_boom;
q_ship = qimpact_ship;
correctedVars(end+1) = "QimpactX";
correctedVars(end+1) = "qimpact_ship";
correctedVars(end+1) = "qimpact_boom";
correctedVars(end+1) = "q_ship";
correctedVars(end+1) = "q_boom";

%  Used in calculations  (corrected)
PSX = PSM;
f_ship = f_ship_beta;
f_boom = f_boom_beta;
% Total pressure
pTotal = QimpactX + PSX; % 
PTOTALX = pTotal;
correctedVars(end+1) = "PSX";
correctedVars(end+1) = "PTOTALX";
correctedVars(end+1) = "pTotal";

% 
% Mixing Ratio:
vaporPressure=sat_vapor_pressure_GG(TDPK); % Use Goff-Gratch
if exist('BuckPressure','var')
    mr=(C.Mv./C.Md).*vaporPressure./(BuckPressure - vaporPressure); % g/g
else
    mr=(C.Mv./C.Md).*vaporPressure./(PSX - vaporPressure); % g/g
end

% Attack and Sideslip angles 
units = ncreadatt(X.ncFINAL,'alpha','units');
alpha = convertUnits(atan(ta_beta),'radian',units);
units = ncreadatt(X.ncFINAL,'beta','units');
beta  = convertUnits(atan(tb_beta),'radian',units);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% Air data (TAS and derived variables)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Compute moist-air thermodynamic and airspeed quantities using measured:
%   - Ps_meas  : Measured static pressure (hPa)PSX
%   - Pt       : Pitot (total) pressure (hPa)
%   - Tm       : Measured probe temperature (K)
%   - r        : Probe recovery factor (dimensionless, required)
%   - Td       : Dewpoint temperature (K)
% Static-pressure correction (name,value pair)
%   "dPs_corr", pcor
% q_impact is impact (stagnation) pressure 
% q_dyn = dynamic pressure = 1/2*rho*V^2;
% q_dyn = q_impact if incompressible.

% Note:  The static pressure correction has already been applied
%       to the input variables here, so no further static correction
%       will be madein airdata.m. To change this, set *_pcor 
%       to zero and 
%       add "dPs_corr", boom_pcor  or
%           "dPs_corr", boom_pcor  to the ardata run string.
% Compute airspeed and other derived variables

if exist("TRF","var")   %%%%%%%%%  Using TRF temperature 
    %recovery factor
    r=0.6425;
    Tmeas = TRF; % Uncorrected
    ADatTRF = airdata(PSX, pTotal, TRF, r, TDPK ...
        , "Z_gps", Zgps); 
%%%        , "dPs_corr", boom_pcor, "Z_gps", Zgps);     
    if X.TempUsed == 'TRF'
        ADat = ADatTRF;
        TEMPX = ADat.Ts; % Corrected
        TASX = ADat.TAS;
    end
    units=ncreadatt(X.ncFINAL,'trf','units');
    trf=convertUnits(ADatTRF.Ts,ADatTRF.units.Ts,units);
end
if exist("TROSE","var") %%%%%%%%%% Using TROSE temperature
    %recovery factor
    r=0.97;
    Tmeas = TROSE + C.Tzero; % Uncorrected
    ADatTROSE = airdata(PSX, pTotal, TROSE, r, TDPK ...
        , "Z_gps", Zgps);
%%%        , "dPs_corr", boom_pcor, "Z_gps", Zgps);
    if X.TempUsed == 'TROSE'
        ADat = ADatTROSE;
        TEMPX = ADat.Ts; % Corrected
        TASX = ADat.TAS;
    end
    units=ncreadatt(X.ncFINAL,'trose','units');
    trose=convertUnits(ADatTROSE.Ts,ADatTROSE.units.Ts,units);
end

correctedVars(end+1) = "TASX";
correctedVars(end+1) = "TEMPX";
correctedVars(end+1) = "TASX";

if ~exist('ADat','var')
    error('ADat has not been generated')
end

% Airdata remains continuous on the ground; flag the flight-useful interval.
inflight = single(TASX > 30);

% Indicated airspeed (knots)
ias = convertUnits(ADat.Vi,'meter/sec','knots');
ncwriteatt(X.ncFINAL,'ias','DP1 used',X.DP1Used);
ncwriteatt(X.ncFINAL,'ias','Units','knots');

units=ncreadatt(X.ncFINAL,'tas','units');
tas = convertUnits(TASX,ADat.units.TAS,units);

% Pressure altitude
PALT = ADat.Zp;
    units=ncreadatt(X.ncFINAL,'PALT','units');
    PALT = convertUnits(PALT,ADat.units.Zp,units);
% Relative Humidity 
    rh = ADat.RH; % fraction
    units=ncreadatt(X.ncFINAL,'rh','units');
    if units == 'percent' & ADat.units.RH == "1"
        rh = rh.*100;
    end
% Mixing Ratio: leave as kg/kg  for  now
    mr = ADat.w; % kg/kg
    units=ncreadatt(X.ncFINAL,'mr','units');
    mr = convertUnits(mr,ADat.units.w,'kg/kg');
% Dry theta
    thetad = ADat.thetad;
    units=ncreadatt(X.ncFINAL,'thetad','units');
    thetad = convertUnits(thetad,ADat.units.thetad,'Kelvin');
% Thetae
    thetae = ADat.theta_e;
    units=ncreadatt(X.ncFINAL,'thetae','units');
    thetae = convertUnits(thetae,ADat.units.theta_e,'Kelvin');
% Lifted Condensation Level LCL temp and pressure
    TLCL = ADat.TLCL;
    units=ncreadatt(X.ncFINAL,'TLCL','units');
    TLCL = convertUnits(TLCL,ADat.units.TLCL,'Kelvin');
    PLCL = ADat.PLCL;
    units=ncreadatt(X.ncFINAL,'PLCL','units');
    PLCL = convertUnits(PLCL,ADat.units.PLCL,'hPa');
   
% Hydrostatic height [m]
Zhydro = ADat.Zhydro;

% Hydrostatic difference between Zhyps and Zgps
diffGPShydro = (Zhydro - Zgps).* ADat.rho .* C.g0 ./100; % hPa

% Static pressure corrections in attributes
for i = 1:numel(correctedVars)
    try % some may not be in the output list
        ncwriteatt(X.ncFINAL, correctedVars(i), "Static pressure error", "Corrected");
    end
end

ncwriteatt(X.ncFINAL,'tas','TempUsed',X.TempUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'tas','PressUsed',X.PressUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'TASX','TempUsed',X.TempUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'TASX','PressUsed',X.PressUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'inflight','units','1','Datatype','char');
ncwriteatt(X.ncFINAL,'inflight','flag_values',single([0 1]));
ncwriteatt(X.ncFINAL,'inflight','flag_meanings', ...
    'not_inflight inflight','Datatype','char');
ncwriteatt(X.ncFINAL,'thetad','PressUsed',X.PressUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'thetae','TempUsed',X.TempUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'thetae','PressUsed',X.PressUsed,'Datatype','char');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% Eddy Dissipation Rate from TAS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get TAS components at high-rate from RAW.nc file
if numel(RAW.DPA) > 10*60*1000 % 10 minutes
    fs  = 60;
    fny = fs/2;
    f1  = fny/10;
    f2  =  fny;
    [tasx,tasy,tasz] = get_uvw(X,fs,RAW,RATE,'dPsCorr', ship_pcor); % aircraft-relative TAS components
    Tas = rssq([tasx,tasy,tasz],2); % root sum of squares
    [~,~,epsiwi] = ...
    EddyDissipationRate(Tas,tasx,tasy,tasz,f1,f2,fs);
    edrTAS = epsiwi.^.333;
    if any(ismember(arcNames,'edrTAS'))
        ncwriteatt(X.ncFINAL,'edrTAS','BandWidth(Hz)',[f1,f2]);
    end
else
    edrTAS = zeros(size(Time));
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% Output data to matfile
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Rate=X.procRate;Sps_hads_a=sprintf('sps%i',Rate);
time=ncread(X.RawPath,rawTimeVar);

Rate=X.procRate;
SPS=sprintf('sps%i',Rate);
time=ncread(X.RawPath,rawTimeVar);

ss1="'orate','Rate','rawfile','arcNames','rawNames','TEMPX','PSX','Time','ss1'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_TAS.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')
;
load_ncFINAL(X.ncFINAL,matfile);
sprintf('Processed get_varTAS.m for Project: %s',X.PROJ)

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Calculate TAS components in aircraft coords at 50 Hz
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [compx,compy,compz] = get_uvw(X,rate,RAW,RATE,varargin) % Helpers below
p = inputParser;
addParameter(p, 'dPsCorr', [], @(x)isnumeric(x)); 
parse(p, varargin{:});
Opts = p.Results;

pcorc = Opts.dPsCorr;
TempUsed = X.TempUsed;
PressUsed = X.PressUsed;
QUsed = X.QUsed;
PcorUsed = X.PcorUsed;
PSUsed = extractBefore(PcorUsed,'_');

% upsample dPSCorr if necessary
if ~isempty(Opts.dPsCorr)
    pcorc = Opts.dPsCorr;
    pcorc = changeRate(pcorc,X.procRate, rate);
else
    pcorc = zeros(rate,1);
end

if contains(X.PressUsed,'ship')
    Ps_meas     = changeRate(RAW.PSA, RATE.PSA,rate);
else
    Ps_meas     = changeRate(RAW.PRES9000, RATE.PRES9000,rate);
end

[~,~,TA,TB] = solve858(RAW.DP1,RAW.DPA,RAW.DPB, ...
    'dpr',RAW.DPR);

TA      = changeRate(TA,RATE.DP1,rate);
TB      = changeRate(TB,RATE.DP1,rate);

TDP             = RAW.BuckDewPoint + 273.15;
TDPrate         = RATE.BuckDewPoint;
Tdp             = changeRate(TDP,      TDPrate,  rate);
DP1             = changeRate(RAW.DP1,  RATE.DP1, rate);
if contains(X.TempUsed, 'TROSE')
    T_meas      = changeRate(RAW.TROSE,RATE.TROSE, rate) +273.15;
    recovf      = 0.97;
else
    T_meas      = changeRate(RAW.TRF,RATE.TRF, rate) +273.15;
    recovf      = 0.64; 
end
Pt_meas         = DP1 + Ps_meas;

kk = find(~isnan(DP1) & DP1>20 & DP1<90);

OUT     = airdata(Ps_meas(kk), Pt_meas(kk), T_meas(kk), recovf, Tdp(kk) ...
    ,'dPs_corr', pcorc(kk));
TAS     = OUT.TAS;
VA      = zeros(size(T_meas,1),3);
VA(kk,:)  = tas2va(TAS,atan(TA(kk)),atan(TB(kk)));

VA = fillmissing(VA, 'constant',0);

compx = VA(:,1);
compy = VA(:,2);
compz = VA(:,3);

end

%%%%%%%%% Helper %%%%%%%%%%%
%%% Clean up before TO and after Landing
function x = repair_one(x, kk)
allSamples = (1:numel(x))';
if(kk>10)
    x = interp1(kk, x(kk), allSamples, 'linear', NaN);
    x(allSamples < kk(1)) = x(kk(1));
    x(allSamples > kk(end)) = x(kk(end));
end
end


