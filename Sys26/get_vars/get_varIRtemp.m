function get_varIRtemp(X)

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

orate=X.procRate
Rate=orate;
TT=datetime('now');
C=phycon;
Tzero=C.Tzero;

%  Needed for airspeed groups  from _raw.nc file
xlsfile='RAW-VARS.xlsx'; % raw variable name spreadsheet
GROUPS={'IRtemp' };
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

rawfile=X.RawPath;
ncfile=X.ncFINAL;

%1000 Hz Variable
irate=1000;
[ninterp,ndecim]=interp_decim(irate,orate);

% Get HEITRONICS IR temperature 
    Var='KT';
    blurf=getdata(X.RawPath,Var,"OutputRate",orate,"UnitsOut",'celsius');

% Check if low rate (1Hz) and over fires (kt > 50)
% If so, get the 1 HZ RS-232 values
% if orate==1 & max(blurf) > 50
%  blurf=getdata('KT1585',1,'UnitsOut','Celsius');
% end
%   evalin('caller',strcat(Var,Rate,'=blurf',';'));

rstb2 = blurf(:);

ss1="'orate','Rate','rawfile','Time','arcNames'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_IRtemp.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')
;
load_ncFINAL(X.ncFINAL,matfile);

sprintf('Processed get_varIRtemp.m for Project: %s',X.PROJ)
return
