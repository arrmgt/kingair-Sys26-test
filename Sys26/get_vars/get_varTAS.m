function get_varTAS(X)

TT=datetime('now');
% Make sure ncFINAL exists
try
    test=ncinfo(X.ncFINAL);
catch
    error('get_varTAS:  X.ncFINAL does not exist'); 
end

orate = X.procRate;

TEST = true;
if(TEST)
    %%%%%%%%%%%%%%%%%%%%%%
    %%%%%%% TEST Sys26 using old data
    %%%%%%%%%%%%%%%%%%%%%%

    DPA = getdata(X.RawPath,'DPA',"OutputRate",X.procRate);
    DPB = getdata(X.RawPath,'DPB',"OutputRate",X.procRate);
    if mean(DPA)<0
        DPA = -DPA;
    end
    if mean(DPB)>0
        DPB = -DPB;
    end    
    DPR = getdata(X.RawPath,'DPR',"OutputRate",X.procRate);
    AIAS = getdata(X.RawPath,'AIAS',"OutputRate",X.procRate);
    TA = tanAlpha(DPA,DPB,DPR);
    TB = tanBeta(DPB,DPR);
    FQ = fqCalc(DPA,DPB,DPR);
    DPN = dpr_alpha1(FQ,TA,TB);
    DP1 = AIAS;
    DP2 = AIAS;
    TROSE = getdata(X.RawPath,'TROSE',"OutputRate",X.procRate);
    
    % HADS
    clear PSA PSB
    try
        HADSA_VT = getdata(X.RawPath,'HADSA_VT',"OutputRate",X.procRate);
        HADSA_VR = getdata(X.RawPath,'HADSA_VR',"OutputRate",X.procRate);
        HADSA_PER = getdata(X.RawPath,'HADSA_PER',"OutputRate",X.procRate);
        PSA = get_hads(X,'A',HADSA_VT,HADSA_VR,HADSA_PER);
        PSB = PSA;
        dpa         = DPA;
        dpb         = DPB;
        dpr_beta    = DPR;
        dpr_alpha   = DPN;
        dp1_ship    = DP1;
        dp1_boom    = DP2;
        ptotal_boom = PTB;
        ps_ship     = PSA;
        ps_boom     = PSB;
    catch
        try
            HADSB_VT = getdata(X.RawPath,'HADSB_VT',"OutputRate",X.procRate);
            HADSB_VR = getdata(X.RawPath,'HADSB_VR',"OutputRate",X.procRate);
            HADSB_PER = getdata(X.RawPath,'HADSB_PER',"OutputRate",X.procRate);
            PSB = get_hads(X,'B',HADSB_VT,HADSB_VR,HADSB_PER);
            PSA = PSB;
            [M, Mship, Mboom]= getDerivedVariablesR858(DPB, DPA, DPR, DPN, DP1, DP2,PSB,PSB);
        catch
            try
                PRES6140 = getdata(X.RawPath,'PRES6140','OutputRate',X.procRate);
                PSA = PRES6140;
                PSB = PSA;
                [M, Mship, Mboom]= getDerivedVariablesR858(DPB, DPA, DPR, DPN, DP1, DP2,PSB,PSB);
            catch
                error(sprintf("TEST:  No pressure data"))
            end
        end
        
    end
    % Or try CPT6140
    if ~exist('PSA','var') | ~isnumeric(PSA)
        try
            PSA = getdata(X.RawPath,'PRES6140',"OutputRate",X.procRate);
            PSB = PSA;
            [M, Mship, Mboom]= getDerivedVariablesR858(DPB, DPA, DPR, DPN, DP1, DP2,PBA,PSA);
        catch
            error('No pressure found');
        end
    end
    try
        TDPEDGE = getdata(X.RawPath,'TDPEDGE',"OutputRate",X.procRate);
    catch
        TDPEDGE = zeros(size(AIAS));
    end
    
    Q_IMPACT = Mboom.q_beta;
    PTB = Q_IMPACT + PSA;
        needGROUPS = {'TAS','CPT'};
        mask = contains(X.rawGROUPS,needGROUPS);
        %  Need TAS and temp and pressure groups
        GROUPS = X.rawGROUPS(mask) ; % Pressures loaded previously
        % Use pivot table and raw mapping table to get 
        % 1. variables to be calculated;
        % 2. raw measurements needed from *_raw.nc
        [arcNames,rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);
        q_impact = q_beta(DP2,DPA,DPB,DPR);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%   end test sys26
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
else % Real data!
    % Need these if available
    needGROUPS = {'TAS','CPT'};
    mask = contains(X.rawGROUPS,needGROUPS);
    %  Need TAS and temp and pressure groups
    GROUPS = X.rawGROUPS(mask) ; % Pressures loaded previously
    % Use pivot table and raw mapping table to get 
    % 1. variables to be calculated;
    % 2. raw measurements needed from *_raw.nc
    [arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

    % Read in raw data and change rate as needed; 
    %   Changing rate
    rawfile = X.RawPath;
    info = ncinfo(rawfile);
    RAWNAMES = {info.Variables.Name};   
    isPresent = ismember(rawNames,RAWNAMES);
    for k=1:length(rawNames)
        var1 = char(rawNames(k));
        if isPresent(k)
            blurf = getdata(rawfile,var1,"OutputRate",orate);
            j=find(~isnan(blurf) & ~isinf(blurf)); % Sanity check
            blurf=interp1(j,blurf(j),[1:numel(blurf)]','spline',0);
            eval(sprintf('%s=blurf;',var1));        
        end
    end
    addpath('c:/users/rodi/Github/kingair-Sys26/Sys26/get_vars/mfiles858')
    [M, Mboom, Mship] = getDerivedVariablesR858( ...
    DPB, DPA, DPR, DPN, DP1, DP2, PSA, PSB);
    fq = M.fq_beta;
    ta = M.ta_beta;
    tb = M.tb_beta;
    DPN_sim = dpra_sim(fq,ta,tb);
    %  Sanity check
    if mean(DPA)<0
        DPA = -DPA;
    end
    dpa         = DPA;
    dpb         = DPB;
    dpr_beta    = DPR;
    dpr_alpha   = DPN;
    dp1_ship    = DP1;
    dp1_boom    = DP2;
    ptotal_boom = PTB;
    ptotal_ship = PTB;
    ps_ship     = PSA;
    ps_boom     = PSB;
end

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

% Variables to be used in TAS etc.
PressUsed   = X.PressUsed;
TempUsed    = X.TempUsed;
DP1Used     = X.DP1Used;
QUsed       = X.QUsed;

% Physical constants structure
C=phycon;
Tzero=C.Tzero;

% Get raw variables needed for tas group
%
orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

%  Get Zgps if available
irate = get_irate(X.RawPath,'AALT');
if ~isempty(irate)
    Zgps = getdata(X.RawPath,'AALT',"OutputRate",X.procRate);
else
    Zgps = zeros(size(DPA));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Available pressures?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ZEROZ = zeros(size(DPA)); % dummy variable
Pressures = string;
try
    HADSA_VT = getdata(X.RawPath,'HADSA_VT',"OutputRate",X.procRate);
    HADSA_VR = getdata(X.RawPath,'HADSA_VR',"OutputRate",X.procRate);
    HADSA_PER = getdata(X.RawPath,'HADSA_PER',"OutputRate",X.procRate);
    ps_hads_a = get_hads(X,'A',HADSA_VT,HADSA_VR,HADSA_PER);
    Pressures(end_1) = ps_hads_a;
catch
    ps_hads_a = ZEROZ;
    try
        HADSB_VT = getdata(X.RawPath,'HADSB_VT',"OutputRate",X.procRate);
        HADSB_VR = getdata(X.RawPath,'HADSB_VR',"OutputRate",X.procRate);
        HADSB_PER = getdata(X.RawPath,'HADSB_PER',"OutputRate",X.procRate);
        ps_hads_b = get_hads(X,'B',HADSB_VT,HADSB_VR,HADSB_PER);
        Pressures(end_1) = ps_hads_b;
    catch
        ps_hads_b = ZEROZ;
    end
end
if exist('PSA','var') & ~isempty(PSA)
    ps_ship=PSA;
    Pressures(end+1) = 'ps_ship';
else
    ps_ship = ZEROZ; 
end
if exist('PSB','var') & ~isempty(PSB)
    ps_boom=PSB;
    Pressures(end+1) = 'ps_boom';
else
    ps_boom = ZEROZ; 
end
if exist('PTB','var') & ~isempty(PSB)
    ptotal_boom=PTB;
    Pressures(end+1) = 'ptotal_boom';
    ptotal_ship = PTB;
    Pressures(end+1) = 'ptotalship';
else
    ptotal_boom = ZEROZ; 
    ptotal_ship = ZEROZ;
end
% CPT 6140
if exist('PRES6140','var') & ~isempty(PRES6140)
    ps_CPT6140=PRES6140;
    Pressures(end+1) = 'ps_CPT6140';
else
    ps_CPT6140 = ZEROZ; 
end
% CPT 9000 pressure
if exist('PRES9000','var') & ~isempty(PRES9000)
    ps_CPT9000=PRES9000;
    Pressures(end+1) = 'ps_CPT9000';
else
    ps_CPT9000 = ZEROZ;
end
% WESTON pressure
if exist('WDPM','var') & ~isempty(WDPM)
    ps_weston=WDPM;
    Pressures(end+1) = 'ps_weston';
else
    ps_weston = ZEROZ;
end
Pressures = Pressures(Pressures ~= "");

if exist('TEMP9000','var') & ~isempty(TEMP9000)
    temp_CPT9000=TEMP9000;
else
    temp_CPT9000 = ZEROZ;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%% Dewpoint (TDPEDGE or Buck 1011C  or ??
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if(cell_find(arcNames,'tdp'))
    try
        tdp=TDPEDGE; % in centigrade
        ncwriteatt(X.ncFINAL,'tdp','Sensor','Edgetech');
    catch
        try % OK, try this
            blurf=ncread(X.RawPath,'TDP');TDP=blurf(:);
            tdp=TDP; %  EG&G
            ncwriteatt(X.ncFINAL,'tdp','Sensor','Buck1011c');
        catch
            "getvarTAS: No depoint found"
            tdp = -40.*ones(size(DPA));
        end
    end
    % Frost point?? Then convert to dew point
    kk=find(tdp<0); 
    tdp0=tdp;
    tdp1=tdp;
    % Assume Frost Point sensed if tdp<0 C
    if(~isempty(kk))
        tdp(kk) = dew(tdp(kk)); % Frost point is sensed
        % tdp1(kk) = frostpoint_to_dewpoint(tdp1(kk));
    end
    TDPK = tdp + Tzero;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% R858 noseboom variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

dpa         = DPA;
dpb         = DPB;
dpr_beta    = DPR;
dpr_alpha   = DPN;
dp1_ship    = DP1;
dp1_boom    = DP2;
ptotal_boom = PTB;
ps_ship     = PSA;
ps_boom     = PSB;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% derived variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% *_beta variables use DPR and *_alpha variables use DPN.
% 
[M, Mboom, Mship] = getDerivedVariablesR858( ...
    dpb, dpa, dpr_beta, dpr_alpha, dp1_ship, dp1_boom, ps_ship, ps_boom);
ta_alpha = M.ta_alpha;
ta_beta  = M.ta_beta;
tb_alpha = M.tb_alpha;
tb_beta  = M.tb_beta;

dp1_boom = DP1;
dp1_ship = DP2;

q_ship_alpha = Mship.q_alpha;
q_ship_beta = Mship.q_beta;
q_boom_alpha = Mboom.q_alpha;
q_boom_beta = Mboom.q_beta;

f_ship_alpha = Mship.f_alpha;
f_ship_beta = Mship.f_beta;
f_boom_alpha = Mboom.f_alpha;
f_boom_beta = Mboom.f_beta;

fq_alpha = M.fq_alpha;
fq_beta = M.fq_beta;

dpr_alpha = DPN;
dpr_beta = DPR;


% Which should be used (call it PSM)
varUsed=[];
jj = find(matches(Pressures,X.PressUsed));
ss=sprintf("PSM = %s;",Pressures(jj));
eval(ss);

% which DP1 to use (call it DP1X)
ss = sprintf("DP1X = %s;",DP1Used);
eval(ss)

% which q to use (call it QimpactX)
ss = sprintf("QimpactX = %s;",X.QUsed);
eval(ss)

alpha=atan(ta_beta); % radians
beta=atan(tb_beta);

% R858 flow angle calibration factors
[pitoff,rolloff,hedoff,bfactor,afactor,Qfactor] = AV410_factors(X.ncFINAL);
% 
% Mixing Ratio:
mr=ZEROZ;
vaporPressure=sat_vapor_pressure_GG(TDPK); % Use Goff-Gratch
%  Iteration needed for higher humi
% dity levels
%     since mr needed for boom_pcor
for jj=1:3
    boom_pcor = cone_pcor(DP1X,dpb,dpa,dpr_beta,PSM,mr);
    mr=(C.Mv./C.Md).*vaporPressure./(PSM - boom_pcor - vaporPressure); % g/g
end
[boom_pcor,qc0,tbx,tax,fcoef] = cone_pcor(DP1X,dpb,dpa,dpr_beta,PSM,mr);
q_impact = qc0 * (1+Qfactor);  % This is a residual residual static error

% Apply pressure corrections
for jj=1:numel(Pressures);
    if(exist(Pressures{jj}))
        ss = sprintf("%s = %s - boom_pcor;",Pressures{jj},Pressures{jj});
        eval(ss)
        ss = sprintf([ 'ncwriteatt(X.ncFINAL,''%s'',' ...
        '''Static Defect'',''Corrected'',''Datatype'',''char'');\n' ],Pressures(jj));
        eval(ss)
    end
end


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
PSX = PSM - boom_pcor;

% Total pressure 
%  Pt = q_impact + Ps;
pTotal = ptotal_boom + boom_pcor; 

clear TASX
% Get moist air properties and airspeeds 
if exist("TRF","var")   %%%%%%%%%  Using TRF temperature 
    %recovery factor
    r=0.6425;
    Tmeas = TRF + Tzero; % Uncorrected
    ADatTRF = airdata(PSM, pTotal, Tmeas, r, TDPK ...
        , "dPs_corr", boom_pcor, "Z_gps", Zgps);    
    trf = ADatTRF.Ts;
    if X.TempUsed == 'trf'
        ADat = ADatTRF;
        TEMPX = trf;
        TASX = ADat.TAS;
    end
    units=ncreadatt(X.ncFINAL,'trf','units');
    trf=convertUnits(trf,ADat.units.Ts,units);
end
if exist("TROSE","var") %%%%%%%%%% Using TROSE temperature
    %recovery factor
    r=0.97;
    Tmeas = TROSE + Tzero; % Uncorrected
    ADatTROSE = airdata(PSM, pTotal, Tmeas, r, TDPK ...
        , "dPs_corr", boom_pcor, "Z_gps", Zgps);
    trose = ADatTROSE.Ts;
    if X.TempUsed == 'trose'
        ADat = ADatTROSE;
        TEMPX = trose;
        TASX = ADat.TAS;
    end
    units=ncreadatt(X.ncFINAL,'trose','units');
    trose=convertUnits(trose,ADat.units.Ts,units);
end

% Indicated airspeed (knots)
ias = convertUnits(ADat.Vi,'meter/sec','knots');
ncwriteatt(X.ncFINAL,'ias','DP1 used',X.DP1Used);
ncwriteatt(X.ncFINAL,'ias','Units','knots');

% Sanity check
if ~exist("TASX")
    error("get_varTAS:  No TempUsed variable found")
end

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

ncwriteatt(X.ncFINAL,'tas','TempUsed',X.TempUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'tas','PressUsed',X.PressUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'TASX','TempUsed',X.TempUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'TASX','PressUsed',X.PressUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'thetad','PressUsed',X.PressUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'thetae','TempUsed',X.TempUsed,'Datatype','char');
ncwriteatt(X.ncFINAL,'thetae','PressUsed',X.PressUsed,'Datatype','char');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% Eddy Dissipation Rate from TAS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get TAS components @ 50 Hz from raw.nc file
fs50 = 50;
fs1000 = 1000;
fny=fs50/2;
f1 = fny/2;
f2 = fny;
if(TEST)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% test version
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    info = ncinfo(X.RawPath);
    namez = {info.Variables.Name};
    if any(contains(namez,'PRES6140'))
        irate = get_irate(X.RawPath,'PRES6140');
        P = getdata(X.RawPath,'PRES6140','OutputRate',fs1000);
    elseif any(contains(namez,'HADSA'))
        irate = get_irate(X.RawPath,'HADSA_VT');
        HADSA_VT = getdata(X.RawPath,'HADSA_VT','OutputRate',fs1000);
        HADSA_VR = getdata(X.RawPath,'HADSA_VR','OutputRate',fs1000);
        HADSA_PER = getdata(X.RawPath,'HADSA_PER','OutputRate',fs1000);
        P = get_hads(X,'A',HADSA_VT,HADSA_VR,HADSA_PER);
    elseif any(contains(namez,'HADSB'))
        irate = get_irate(X.RawFile,'HADSB_VT');
        HADSB_VT = getdata(X.RawPath,'HADSB_VT','OutputRate',fs1000);
        HADSB_VR = getdata(X.RawPath,'HADSB_VR','OutputRate',fs1000);
        HADSB_PER = getdata(X.RawPath,'HADSB_PER','OutputRate',fs1000);
        P = get_hads(X,'B',HADSB_VT,HADSB_VR,HADSB_PER);
    end
    if any(contains(namez,'TRF'))
        irate = get_irate(X.RawPath,'TRF');
        TK = getdata(X.RawPath,'TRF','OutputRate',fs1000) + Tzero;
    elseif any(contains(namez,'TROSE'))
        irate = get_irate(X.RawPath,'TROSE');
        TK = getdata(X.RawPath,'TROSE','OutputRate',fs1000) + Tzero;
    end
    if any(contains(namez,'AIAS'))
        irate = get_irate(X.RawPath,'AIAS');
        DP0 = getdata(X.RawPath,'AIAS','OutputRate',fs1000);
    end
    
    kk0 = [1:numel(P)]';
    kk=find( ~isnan(P) & ~isinf(P) & P>200 & P<1200);
    P = interp1(kk,P(kk),kk0,'spline',500);
    kk=find( ~isnan(TK) & ~isinf(TK) & TK>200 & TK<400 );
    TK = interp1(kk,TK(kk),kk0,'spline',273);
    kk=find( ~isnan(DP0) & ~isinf(DP0) & abs(DP0)<200);
    DP0 = interp1(kk,DP0(kk),kk0,'spline',273);
    
    [tasx,tasy,tasz] = get_uvw(X,fs50,P,TK,DP0); 
%%%%%%%%%%%%%%%%%%%%%% end test version
else  %  NOT TEST
    [tasx,tasy,tasz] = get_uvw(X,fs50); % aircraft-relative TAS components

end  % TEST
%%%%%%%%%%%%%%%%%%%%%  END TEST %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Tas = rssq([tasx,tasy,tasz],fs50); % root sum of squares
[epsiux,epsivy,epsiwi,varhatu,varhatv,varhatw,uwf,vwf] = ...
   EddyDissipationRate(Tas,tasx,tasy,tasz,f1,f2,fs50);
edrTAS=epsiwi.^.333;

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
function [compx,compy,compz] = get_uvw(X,rate,varargin)

if nargin > 2 %  T, P, DP provided
    blurf = ncread(X.RawPath,'DPA'); DPA = blurf(:);
    blurf = ncread(X.RawPath,'DPB'); DPB = blurf(:);
    blurf = ncread(X.RawPath,'DPR'); DPR = blurf(:);
    DPA = decimateByFactors(DPA,1000/rate,'FIR');
    DPB = decimateByFactors(DPB,1000/rate,'FIR');
    DPR = decimateByFactors(DPR,1000/rate,'FIR');
    TEMPK = decimateByFactors(varargin{2},1000/rate,'FIR');
    PMB = decimateByFactors(varargin{1},1000/rate,'FIR');
    DP1X = decimateByFactors(varargin{3},1000/rate,'FIR') ;
    TEST = true;
    TempUsed = TEMPK;
    PressUsed = PMB;
    DP1used = DP1X;
    DPR = getdata(X.RawPath,'DPR',"OutputRate",rate);
    q_impact = q_beta(DP1X,DPA,DPB,DPR);
    [pcorc,q_impact,tb,ta] = cone_pcor(DP1X,DPB,DPA,DPR,PMB);
    TEST = true;
else
    TEST = false;
    RawPath=X.RawPath;
    TempUsed = X.TempUsed;
    PressUsed = X.PressUsed;
    DP1used = X.DP1Used
    % 1000 Hz variable
    TEMPK = getdata(RawPath,upper(X.TempUsed),"OutputRate",rate)+273.15;
    dp1used = extractBefore(X.DP1Used,'_');
    DP1X = getdata(RawPath,upper(dp1used),"OutputRate",rate);
    switch PressUsed
        case 'ps_CPT6140'
            PMB = getdata(RawPath,'PRES6140',"OutputRate",rate);

        case 'ps_ship'
            PMB = getdata(RawPath,'PSA',"OutputRate",rate);

        case 'ps_boom'
            PMB = getdata(RawPath,'PSB',"OutputRate",rate);
    
        otherwise
            'blurf'
    end
    boom_pcor = zeros(size(TEMPK));
end

ii=find(PMB>=300 & PMB < 1200 & ~isnan(PMB));
PMB = interp1(ii,PMB(ii),[1:numel(PMB)]','spline',300);

DPA = getdata(X.RawPath,'DPA',"OutputRate",rate);
DPB = getdata(X.RawPath,'DPB',"OutputRate",rate); 
DPR  = getdata(X.RawPath,'DPR',"OutputRate",rate);
if mean(DPA < 0)  % attack angle mainly positive on average
    DPA = -DPA;
end
q_impact = q_beta(DP1X,DPA,DPB,DPR);
TA = ta_beta(DPA,DPB,DPR);
TB = tb_beta(DPB,DPR);

%%%%%%%%%%%%%%
%%%%%%Remove for Sys26
%%%%%%%%%%%%%%%
if(TEST)
    if mean(DPB > 0)
        DPB = -DPB;
    end
end
%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%


[TasHR]=tasf(q_impact,PMB,TEMPK); % m/s
ii=find(TasHR>=50 & ~isnan(TasHR));
TasHR = interp1(ii,TasHR(ii),[1:numel(TasHR)]','spline',10);

va=tas2va(TasHR,atan(TA),atan(TB));

compx = va(:,1);
compy = va(:,2);
compz = va(:,3);

end