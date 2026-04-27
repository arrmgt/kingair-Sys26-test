function get_varCPT(X)

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


% Raw data inputs
GROUPS = {'CPT'};
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Remove variables that don't exist in raw file;
info = ncinfo(X.RawPath);
ncVarNames = {info.Variables.Name};
rawNames = rawNames(ismember(rawNames, ncVarNames));

% Get raw data
for ii=1:numel(rawNames);
    VAR = rawNames{ii};
    [blurf,irate,nmiss,units0]=getdata(X.RawPath,VAR,"OutputRate",orate);
    ss = sprintf("%s = blurf(:);",VAR);
    eval(ss);
end

ps_CPT6140 = PRES6140;
ps_CPT9000 = PRES9000;
temp_CPT9000 = TEMP9000;

ss1="'orate','Rate','rawfile','Time','arcNames','rawNames'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_CPT.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')

load_ncFINAL(X.ncFINAL,matfile);


sprintf('Processed get_varCPT.m for Project: %s',X.PROJ)