function get_varAV410RMS(X)
% AV RMS data structure
% GPSTime				seconds
% North_position_RMS_error	meters
% East_position_RMS_error	meters
% Down_position_RMS_error	meters
% North_velocity_RMS_error	meters
% East_velocity_RMS_error	meters 
% Down_velocity_RMS_error	meters
% Roll_RMS_error		    degree
% Pitch_RMS_error		    degree
% Heading_RMS_error		    degree

TT=datetime('now');% save processing start time

% Load time vector to reference length
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

% Get raw variables needed for this group
%
orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;


% AV post processed data is 1 Hz;
irate=1;
orate=1; % Always 1 Hz
[ninterp,ndecim]=interp_decim(irate,orate);
xlsfile='defines3.xlsx';

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS={'AV410RMS'};
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Load time vector to reference length
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

sbetfile=X.AVdata;
data=dataAV410(sbetfile);

% Read the rms data file 
AVrms=rmsAV410(X.AVrms);

% Get time in seconds from raw file
time=ncread(X.RawPath,rawTimeVar);

% *_raw.nc time units will look something like 
%  'seconds since 2021-01-01 00:00:00 +0000'

GPSunits=ncreadatt(X.RawPath,rawTimeVar,'units');
% string parse time format
GPSformat = ncreadatt(X.RawPath,rawTimeVar,'strptime_format'); 
G = aircraftTime2gpsTime(time,GPSunits,GPSformat);

% Create aircraft GPS time vector at 200 Hz
% Applanix system outputs time of week without leapsecond
%    or any week epoch rollover
% Syncronize Applanix with local data system

% Create aircraft tow that won't change weeks during flight
% and is not corrected with leapseconds
weekStart = G.week(1);
tow1 = G.gpsSeconds - weekStart * 604800;

deltat=1;
t_ac_gps = [(tow1(1):deltat:(tow1(end)+1-deltat)) - G.leapSeconds(1)]';
t01=t_ac_gps;  % aircraft GPS time

s = struct('name', [], 'value', [], 'units', []);
rmsData=struct('name', [], 'units', [],'value', []);
t00=unique(AVrms(1,:)'); % Applanix GPS time


% Get variable information
rmsData(1).name = "GPSTime";
rmsData(2).name = "nposrms";
rmsData(3).name = "eposrms";
rmsData(4).name = "dposrms";
rmsData(5).name = "nvelrms";
rmsData(6).name = "evelrms";
rmsData(7).name = "dvelrms";
rmsData(8).name = "rollrms";
rmsData(9).name = "pitchrms";
rmsData(10).name = "headrms";

rmsData(1).units =  'seconds';
rmsData(2).units =  'meter';
rmsData(3).units =  'meter';
rmsData(4).units =  'meter';
rmsData(5).units =  'meter/sec';
rmsData(6).units =  'meter/sec';
rmsData(7).units =  'meter/sec';
rmsData(8).units =  'degree';
rmsData(9).units =  'degree';
rmsData(10).units = 'degree';

% Load data into structure
for ii=1:numel(rmsData);
    % Syncronize aircraft and GPS times
    rmsData(ii).value = interp1(t00,AVrms(ii,:),t01,'nearest',0);
end

% Convert units
for ii=2:numel(rmsData)
    jj = find(contains(arcNames,rmsData(ii).name));
    units0 = ncreadatt(X.ncFINAL,arcNames(jj),'units');
    if(~isempty(units0))
        rmsData(ii).value = ...
            convertUnits(rmsData(ii).value,units0,rmsData(ii).units);
        ss = sprintf("%s=rmsData(ii).value;",arcNames(jj));
        eval(ss)
    end
end

ss1="'orate','Rate','rawfile','arcNames','Time'";
% Build list name for outputing to matfile 
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii}); 
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_AV410RMS.mat",X.BaseName))
delete(matfile)
ss=sprintf("save(matfile,%s);",ss1);eval(ss);
;
load_ncFINAL(X.ncFINAL,matfile);

TT1=datetime('now');
procSeconds = ceil(seconds(TT1-TT));
sprintf("procSeconds = %i",procSeconds)
save(matfile,'-append','procSeconds')

sprintf('Processed get_varAV410RMS.m for Project: %s',X.PROJ)