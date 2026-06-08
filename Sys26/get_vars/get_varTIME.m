function get_varTIME(X)

procName = 'get_varTIME';
TT=datetime('now');

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

dateProcessed=[datestr(now,31)];
DataType='Derived variables processed with matlab(TM)';
ncwriteatt(X.ncFINAL,'/','Date Processed',dateProcessed);
ncwriteatt(X.ncFINAL,'/','Date By',"U. Wyoming, Dept. Atmos. Sci.");
ncwriteatt(X.ncFINAL,'/','HeaderCreated',dateProcessed);

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS={'TIME'};
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Time attributes
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end
units=ncreadatt(X.RawPath,rawTimeVar,'units');
try
    standard_name=ncreadatt(X.RawPath,rawTimeVar,'standard_name');
    ncwriteatt(X.ncFINAL,'Time','standard_name',standard_name);
    strptime_format=ncreadatt(X.RawPath,rawTimeVar,'strptime_format');
    ncwriteatt(X.ncFINAL,'Time','strptime_format',strptime_format);
end
ncwriteatt(X.ncFINAL,'Time','long_name','System time')
ncwriteatt(X.ncFINAL,'Time','units',units);

% *_raw.nc time units will look something like 'seconds since 2021-01-01 00:00:00 +0000'
fmt=ncreadatt(X.RawPath,rawTimeVar,'units');
j=strfind(fmt,'+'); % is zone specified?
if(isempty(j))
    fmt = [fmt ' +0000'];
    j=strfind(fmt,'+'); % is zone specified?
end
Tzone=fmt(j:end); %time zone of time
Tfmt=extractAfter(fmt,'seconds since ');
Tparts0=split(Tfmt);
if(length(Tparts0)<3)
    Tparts{1,1}=Tparts0{1};
    Tparts{2,1}='0:0:0';
    Tparts{3,1}=Tparts0{2};
else
    Tparts=Tparts0;
end
utcOffset=Tparts{3};
startTime=[Tparts{1},' ',Tparts{2}];
newyear=Tparts{1};
TrefFlight=datetime(startTime,'InputFormat','yyyy-MM-dd HH:mm:s','TimeZone',utcOffset);
Tstart=TrefFlight+seconds(Time(1));
Tend=TrefFlight+seconds(Time(end));
% Create aircraft datetime array
deltat=1;
Tac=Tstart:seconds(1):Tend;

currentTime = datetime('now', 'TimeZone', 'UTC','InputFormat' ...
    ,'yyyy-MM-dd HH:mm:ss');
date_created=datestr(currentTime, 'dd-mmm-yyyy HH:MM:SS +0000');
start_time = datetime(Tac(1),  'InputFormat','yyyy-MM-dd HH:mm:ss +0000');
end_time   = datetime(Tac(end),'InputFormat','yyyy-MM-dd HH:mm:ss +0000');
% datestr format different thatn datetime(!)
tstart=datestr(Tac(1),'yyyy-mm-dd HH:MM:SS +0000'); 
tend=datestr(Tac(end),'yyyy-mm-dd HH:MM:SS +0000');

FileYear = year(TrefFlight);
FlightDate = datetime(Tac,'InputFormat','yyyy-MM-dd');
startt=datestr(Tac(1),'HH:MM:SS');
endt=datestr(Tac(end),'HH:MM:SS');
TimeInterval=sprintf('%s-%s',startt,endt);

ncwriteatt(X.ncFINAL,'/','date_created',date_created);
ncwriteatt(X.ncFINAL,'/','Date Processed',date_created);
ncwriteatt(X.ncFINAL,'/','time_coverage_start',tstart);
ncwriteatt(X.ncFINAL,'/','time_coverage_end',tend);
ncwriteatt(X.ncFINAL,'/','TimeInterval',TimeInterval);
FlightDate = datetime(Tac(1),'InputFormat','yyyy-MM-dd');

[HOUR,MINUTE,SECOND] = hms(Tac);
[yr,mo,da] = ymd(Tac);
DATE=(mod(yr,100).*10000+mo.*100+da)';
TIME=(HOUR.*10000+MINUTE.*100+SECOND)';
TIME14D=(yr.*10000000000+mo.*100000000.+da.*1000000.+HOUR.*10000.+MINUTE.*100.+SECOND)';

Time=int32(Time);
TIME=int32(TIME);
TIME14D=int64(TIME14D);
DATE = int32(DATE);
HOUR=int32(HOUR');
MINUTE=int32(MINUTE');
SECOND=int32(SECOND');


ss1="'arcNames','rawNames','Time'";
for ii=1:numel(arcNames);
    ss1=sprintf("%s,'%s'",ss1,arcNames{ii}); 
end; 

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_TIME.mat",X.BaseName));
delete(matfile)
ss=sprintf("save(matfile,%s);",ss1);eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds')

% Save all seconds in datetime variable
datetimeAll = Tac(:);
save(matfile,'-append','datetimeAll');

load_ncFINAL(X.ncFINAL,matfile);
;
ncwriteatt(X.ncFINAL,'TIME','long_name','UTC time encoded as HHMMSS');
ncwriteatt(X.ncFINAL,'TIME','units','HHMMSS');
ncwriteatt(X.ncFINAL,'TIME','format','HHMMSS');
ncwriteatt(X.ncFINAL,'TIME','OutputRate',1);

sprintf('Processed get_varTIME.m for Project: %s',X.PROJ)
