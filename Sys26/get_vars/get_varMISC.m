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
        name = lower(NAME);
        try
            units0 = ncreadatt(X.RawPath,NAME,'units');
            units1 = ncreadatt(X.ncFINAL,name,'units');
            x = convertUnits(x,units0,units1);
        end
        eval(sprintf("%s = x;",name))
    catch 
        error(sprintf("get_varMISC: %s not found",NAME))
    end
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
