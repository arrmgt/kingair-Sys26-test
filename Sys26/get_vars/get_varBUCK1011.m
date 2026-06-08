function get_varBUCK1011(X)
%
%  Input CSV values from Buck 1011C Dewpoint Hygrometer
%  
%  Data record:
%  Balance – number that indicates how close the servo 
%       is to being balanced and a 
%       dew/frost point being measured on the mirror.
%  MirrorT – temperature on the mirror surface.
%  Flag – Indicates the following:
%          0 – normal operation
%          1 – dew or frost point achieved on mirror
%          2 – balance mode
%  Pressure – pressure in mb if sensor installed
%  PWM - - 255 to + 255. Indicates how much 
%       heating (+) or cooling (-) being applied to the %  mirror
%  Mirror – Indicates the following:
%    0 – mirror normal
%    1 – mirror contaminated and will need cleaning soon
%  Board temp – temperature on main circuit board
%  Date – Date in month/day/year MM/DD/YYYY
%  Time – 24 hr time HH:MM:SS
%
%  Output 
%  TDPK1011 - Dewpoint [or frostpoint] temperature
%  PRES1011 - Cavity pressure
VarNames = [ ...
    "Balance1011", "PRES1011", "Fla1101", "PRES1011", ...
    "PWM1011", "FLAG1011", "BoardTemp1011" ];
TT=datetime('now');

% Output time Time attributes
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
needGROUPS = {'BUCK1011'};
mask = contains(X.rawGROUPS,needGROUPS);
%  Need TAS and temp and pressure groups
GROUPS = X.rawGROUPS(mask) ; % Pressures loaded previously
% Use pivot table and raw mapping table to get " + ...
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Read the BUCK string records
TDPstring = ncread(X.RawPath,'TDPBUCK');
lines = string(TDPstring(:));
lines = lines(lines ~= "");

% Split by comma and trim whitespace
C = strtrim(split(lines, ","));

% Expect 7 numeric values plus date/time columns
nVar = 7;
if size(C,2) < nVar + 2
    error('get_varBUCK1011:BadFormat', 'BUCK1011 CSV data must contain at least %d columns', nVar+2);
end

% Parse numeric fields
numMat = str2double(C(:,1:nVar));

% Build the timestamp strings and parse them
buckDate = C(:,nVar+1);
buckTime = C(:,nVar+2);
dtStrings = buckDate + " " + buckTime;
DateTime = datetime(dtStrings, 'InputFormat', 'MM/dd/yyyy HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');

% Remove invalid rows before interpolation or resampling
badRows = isnat(DateTime) | any(isnan(numMat), 2);
if any(badRows)
    warning('get_varBUCK1011:BadRows', 'Removing %d invalid BUCK1011 rows', sum(badRows));
    numMat(badRows,:) = [];
    DateTime(badRows) = [];
    buckDate(badRows) = [];
    buckTime(badRows) = [];
end

% Sort by BUCK timestamp so interpolation can work reliably
[DateTime, sortIdx] = sort(DateTime);
numMat = numMat(sortIdx,:);
buckDate = buckDate(sortIdx);
buckTime = buckTime(sortIdx);

% Convert raw file aircraft time axis to datetime if units exist
aircraftTime = [];
try
    timeUnits = ncreadatt(X.RawPath, rawTimeVar, 'units');
    refString = extractAfter(timeUnits, 'seconds since ');
    refString = strtrim(refString);
    try
        timeRef = datetime(refString, 'InputFormat', 'yyyy-MM-dd HH:mm:ss Z', 'TimeZone', 'UTC');
    catch
        timeRef = datetime(refString, 'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'TimeZone', 'UTC');
    end
    aircraftTime = timeRef + seconds(Time);
catch
    warning('get_varBUCK1011:TimeUnits', 'Unable to convert raw time units; BUCK data will remain on its own timestamp grid');
end

% Fill missing numeric values in the BUCK record sequence
buckEpoch = posixtime(DateTime);
for ii = 1:nVar
    if any(isnan(numMat(:,ii)))
        numMat(:,ii) = fillmissing(numMat(:,ii), 'linear', 'SamplePoints', buckEpoch);
        numMat(:,ii) = fillmissing(numMat(:,ii), 'nearest', 'SamplePoints', buckEpoch);
    end
end

% Resample onto aircraft time if available
if ~isempty(aircraftTime) && ~isempty(buckEpoch)
    aircraftEpoch = posixtime(aircraftTime);
    Balance1011      = interp1(buckEpoch, numMat(:,1), aircraftEpoch, 'nearest', NaN);
    MirrorT1011      = interp1(buckEpoch, numMat(:,2), aircraftEpoch, 'nearest', NaN);
    Flag1011         = interp1(buckEpoch, numMat(:,3), aircraftEpoch, 'nearest', NaN);
    PRES1011         = interp1(buckEpoch, numMat(:,4), aircraftEpoch, 'nearest', NaN);
    PWM1011          = interp1(buckEpoch, numMat(:,5), aircraftEpoch, 'nearest', NaN);
    MirrorStatus1011 = interp1(buckEpoch, numMat(:,6), aircraftEpoch, 'nearest', NaN);
    BoardTemp1011    = interp1(buckEpoch, numMat(:,7), aircraftEpoch, 'nearest', NaN);
    SyncTime = aircraftTime;
else
    Balance1011      = numMat(:,1);
    MirrorT1011      = numMat(:,2);
    Flag1011         = numMat(:,3);
    PRES1011         = numMat(:,4);
    PWM1011          = numMat(:,5);
    MirrorStatus1011 = numMat(:,6);
    BoardTemp1011    = numMat(:,7);
    SyncTime = DateTime;
end

% Quick parsing diagnostics
badNums = any(isnan(numMat), 2);
badDates = isnat(DateTime);

% Write variables out to matfile
saveVars = {'orate','Rate','rawfile','arcNames','rawNames', ...
            'SyncTime','Balance1011','MirrorT1011','Flag1011','PRES1011', ...
            'PWM1011','MirrorStatus1011','BoardTemp1011'};
for ii=1:numel(arcNames)
    if numel(arcNames{ii})>1 && exist(arcNames{ii},'var')
        saveVars{end+1} = arcNames{ii};
    end
end

matfile = fullfile(X.tempdir, sprintf('%s_BUCK1011.mat', X.BaseName));
delete(matfile)
save(matfile, saveVars{:});

TT1 = datetime('now');
procSeconds = seconds(TT1 - TT);
save(matfile, '-append', 'procSeconds', 'TT', 'TT1');
load_ncFINAL(X.ncFINAL, matfile);
sprintf('Processed get_varBUCK1011.m for Project: %s', X.PROJ)

end
