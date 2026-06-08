function get_varAV410RT(X)

TT=datetime('now');
% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

% Load time vector to reference length
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time'
end
FillValue = X.FillValue;
C=phycon;
Tzero=C.Tzero;
time_len=X.time_len; %length of time array

% Get raw variables needed for this group
%
orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS={'AV410RT'};
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% All 410/RT raw values start with "A"
mask = startsWith(rawNames,"A");
rawNames = rawNames(mask);

% Check that they were recorded
for ii = 1:numel(rawNames)
    try
        x=ncinfo(X.RawPath,rawNames(ii));
        mask(ii)=1;
    catch
       mask(ii)=0;
    end
end
rawNames = rawNames(mask);

% Get raw variables and create output variables
%   Output variable name is just lowercase raw variable name
%   Also, change units to output variable units
for ii=1:numel(rawNames)
    var0=char(rawNames(ii));
    [rawRate,dims]=get_irate(X.RawPath,var0);
    x=ncinfo(X.RawPath,var0);
    % Rename some output variables
    switch var0
        case 'AHEAD'
            var1='avthead';
        case 'ADNVELRMS'
            var1='avzvelrms';
        case 'ADNVEL'
            var1='avzvel';
        case 'AHEADRMS'
            var1='avtheadrms';
        otherwise
            var1=['av' lower(var0(2:end))]; % e.g. AXXXX-->avXXXX
    end
    try
        units1 = ncreadatt(X.RawPath,var0,'units');
    catch
        units1 = 'unknown';
    end
    % Get the data
    ss=sprintf("blurf=ncread(X.RawPath,'%s');",var0);
        eval(ss)
    blurf=blurf(:); 
    
    % check and  gaps
    gg = find(~isnan(blurf) & blurf>FillValue);
    blurf = interp1(gg,blurf(gg),1:numel(blurf),'linear',0)';

    OutputRate = ncreadatt(X.ncFINAL,var1,'OutputRate');
    if(contains(units1,'deg') & contains(var0,'AHEAD'));
        sin1 = changeRate(sin(blurf.*pi/180),rawRate,OutputRate);
        cos1 = changeRate(cos(blurf.*pi/180),rawRate,OutputRate);
        blurf = atan2(sin1,cos1).*180/pi;
    else
        blurf = changeRate(blurf,rawRate,OutputRate);
    end
    
    % Get desired output units
    try
        ss=sprintf("units2=ncreadatt(X.ncFINAL,'%s','%s');",var1,'units');eval(ss)
        {var0 var1 units1 units2}; % debug
    catch
        units2='unknown';
    end
    if units1 ~= "unknown" && units2 ~= "unknown"
        blurf = convertUnits(blurf, units1, units2);
    end
    ss = sprintf('%s = blurf(:);',var1);
    eval(ss)
    blurf = convertUnits(blurf,units1,units2);
end 
avthead = wrapTo360(avthead);

% Ellipsoid height
avzell = avalt;

% MSL Height
zgeoid=get_geoid(X.egm,avlat,avlon,FillValue);
avzmsl=avzell-zgeoid; % ellipsoid height - geoid offset
kk = find( ~isnan(avzmsl) & ~isnan(zgeoid) & avzmsl>0);
avzmsl = interp1(kk, avzmsl(kk), [1:numel(avzmsl)]', 'linear', 0);

% Ground Speed
avgs=sqrt(avnsvel.^2+avewvel.^2);

% aircraft coords, z down
avzvel=-avzvel;

% NCAR/EOL "ncplot" needs these to plot X-Y track
GALT = avzmsl;
GLON = avlon;
GLAT = avlat;

% Center coordinate for distances
glat0=ncreadatt(X.ncFINAL,'/','CenterCoordLat0');
glon0=ncreadatt(X.ncFINAL,'/','CenterCoordLon0');

ALTX=avzmsl;
LATX=avlat;
LONX=avlon;
ncwriteatt(X.ncFINAL,'LATX','Sensor','Applanix real-time');
ncwriteatt(X.ncFINAL,'LONX','Sensor','Applanix real-time');
ncwriteatt(X.ncFINAL,'ALTX','Sensor','Applanix real-time');


%  Compute distances from center point.
MAP=X.MAP;
if(~exist('MAP','var'))
    % matlab mapping toolbox not available
    MAP=0;
    ckmdeg=111.05;
    avxdist=(avlat-glat0).*ckmdeg;
    avydist=(avlon-glon0).*ckmdeg.*cos(avlatXX.*pi./180);
else
    % use kilometers everywhere
    wgs84 = wgs84Ellipsoid("kilometer");
    % build a proper azimuthal equidistant mstruct
    mstruct = defaultm('eqdazim');    % 'eqdazim' is azimuthal equidistant
    mstruct.origin = [glat0 glon0 0];
    mstruct.geoid  = wgs84;           % same units as wgs84
    mstruct = defaultm(mstruct);      % fill remaining required fields
    % now project (outputs in kilometers)
    [avxdist, avydist] = projfwd(mstruct, avlat, avlon);
end
InputRate = numel(avlat)/numel(Time);
OutputRate = ncreadatt(X.ncFINAL,'avxdist','OutputRate');
[ninterp,ndecim]=interp_decim(InputRate,OutputRate);
avxdist = changeRate(avxdist,InputRate/OutputRate,OutputRate);
avydist = changeRate(avydist,InputRate/OutputRate,OutputRate);

ncFINAL=X.ncFINAL;

Rate=X.procRate;
SPS=sprintf('sps%i',Rate);

%  Get terrain height below aircraft
zfiles = fullfile(X.aster,'aster');
Dependencies = sprintf("%s,%s,%s",'LATX','LONX','ALTX');
ncwriteatt(X.ncFINAL,'avtopo','Dependencies',Dependencies);
ncwriteatt(X.ncFINAL,'avzagl','database','aster');
[avtopo,avzagl] = get_varTOPO(zfiles,LATX,LONX,ALTX);

ss1="'orate','Rate','rawfile','arcNames','rawNames','avzell','avzmsl','avtrack','avxdist','avydist','Time'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% fix units on av*rms variables (arc-min to 
j=cell_find(arcNames,'rms');
for i=j
    ss=sprintf("%s=%s.*60;",arcNames{i},arcNames{i});
    eval(ss)
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_AV410RT.mat",X.BaseName));
delete(matfile)
ss=sprintf("save(matfile,%s);",ss1);eval(ss);
;
load_ncFINAL(X.ncFINAL,matfile);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds')

sprintf('Processed get_varAV410RT.m for Project: %s',X.PROJ)
