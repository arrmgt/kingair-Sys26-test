function get_varMISC(X)

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

% the MISC output group are just transfered from the *_raw.nc file
% verbatim with maybe a unit change.
%
%
orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

% Get TASX from get_varTAS run previously
matTAS=fullfile(X.tempdir,sprintf("%s_TAS.mat", X.BaseName));
load(matTAS,'TASX','TEMPX','PSX');

% Raw data inputs
GROUPS = {'MISC'};
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Remove variables that don't exist in raw file;
info = ncinfo(X.RawPath);
ncVarNames = {info.Variables.Name};
rawNames = rawNames(ismember(rawNames, ncVarNames));

% get raw variables at X.procRate
for ii=1:numel(rawNames)
    NAME = rawNames{ii};
    % matlab_name and units comes from archive file template
    % matlab_name=ncreadatt(X.ncFINAL,name,'matlab_name');
    % output units, rate
    try
        [x,irate,nmiss,units0]=getdata(X.RawPath,NAME,"OutputRate",orate);       
        ss=sprintf('%s=x(:);',NAME)
        eval(ss)
    catch
        error(sprintf("get_varMISC: %s not found",NAME))
    end
end

% Scroll through archive names
% Radar altitude 1 (ship's) -- here "zrad" at X.procRate 
if exist('ZRAD','var') & any(ismember(arcNames,'ralt1'))
    orate1 = ncreadatt(X.ncFINAL,'ralt1','OutputRate');;
    [ninterp,ndecim]=interp_decim(X.procRate,orate1);
    ralt1 = decimateByFactors(Ninterp(ZRAD,ninterp),ndecim,'FIR');
    try
        units0 = ncreadatt(X.RawPath,'ZRAD','units');
        units1 = ncreadatt(X.ncFINAL,'ralt1','units');
        ralt1 = convertUnits(ralt1,units0,units1);
    end
else
    idx = arcNames == 'ralt1';   % logical index of exact matches
    arcNames(idx) = [];        % remove those elements
end

% Cabin pressure
if  exist('CABINP','var') & any(ismember(arcNames,'cabinp'))
    orate1 = ncreadatt(X.ncFINAL,'cabinp','OutputRate');
    [ninterp,ndecim]=interp_decim(X.procRate,orate1);
    cabinp = decimateByFactors(Ninterp(CABINP,ninterp),ndecim,'FIR');
    try
        units0 = ncreadatt(X.RawPath,'CABINP','units');
        units1 = ncreadatt(X.ncFINAL,'cabinp','units');
        cabinp = convertUnits(cabinp,units0,units1);
    end
else
    idx = arcNames == 'cabinp';   % logical index of exact matches
    arcNames(idx) = [];        % remove those elements
end

% MRI turbulence probe
if exist('TURB','var') &  any(ismember(arcNames,'turb'))
    orate1 = ncreadatt(X.ncFINAL,'turb','OutputRate');
    [ninterp,ndecim]=interp_decim(X.procRate,orate1);
    turb = decimateByFactors(Ninterp(TURB,ninterp),ndecim,'FIR');
    try
        units1 = ncreadatt(X.ncFINAL,'turb','units');
        units0 = ncreadatt(X.RawPath,'TURB','units');
        turb = convertUnits(turb,units0,units1);
    end
else
    idx = arcNames == 'turb';   % logical index of exact matches
    arcNames(idx) = [];        % remove those elements
end

ss1="'orate','Rate','rawfile','Time','arcNames','rawNames'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_MISC.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')

load_ncFINAL(X.ncFINAL,matfile);
sprintf('Processed get_varMISC.m for Project: %s',X.PROJ)
