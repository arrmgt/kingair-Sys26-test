function get_varNEVZOROV(X)

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

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS = {'NEVZOROV'};
[arcNames, rawNames, reverseMap] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);
TT=datetime('now');
C=phycon;
Tzero=C.Tzero;

% variables used in calcs
C=phycon;
Tzero=C.Tzero;

orate=X.procRate;
Rate=orate;

%  Needed from TAS group
matTAS=fullfile(X.tempdir,sprintf("%s_TAS.mat", X.BaseName));
load(matTAS,'TASX','TEMPX','PSX','dp1_boom','ias');
tas     = TASX; % m/s
tc      = TEMPX - C.Tzero; % C
pres    = PSX; % hPa
ias = convertUnits(ias,'knot','m/s'); % 

GROUPS={'NEVZOROV' };
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

rawfile=X.RawPath;
ncfile=X.ncFINAL;


% Get nevlwc, probe='L';
[nevlwc,vlwccol,vlwcref,ilwccol,ilwcref] = ...
get_nevzorov(rawfile,ncfile,Rate,'L',tas,tc,pres,ias);
if(find(nevlwc>0))
    ncwriteatt(ncfile,'nevlwc','Status','Calculated');
    ncwriteatt(ncfile,'nevtwc','Status','Calculated');
else
    ncwriteatt(ncfile,'nevlwc','Status','Not calculated');
    ncwriteatt(ncfile,'nevtwc','Status','Not calculated');
end


% Get nevtlwc, probe='T';
[nevtwc,vtwccol,vtwcref,itwccol,itwcref] = ...
get_nevzorov(rawfile,ncfile,Rate,'T',tas,tc,pres,ias);

ss1="'orate','Rate','rawfile','arcNames','Time'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_NEVZOROV.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')
;
load_ncFINAL(X.ncFINAL,matfile);

sprintf('Processed get_varNEVZOROV.m for Project: %s',X.PROJ)
