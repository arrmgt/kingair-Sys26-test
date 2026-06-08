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
varNames = [ ...
    "Balance1011", "PRES1011", "Fla1101", "PRES1011", ...
    "PWM1011", "FLAG1011", "BoardTemp1011" ];
% Ensure column-wise mapping and valid names
varNames = string(varNames(:));               % 7x1
validNames = matlab.lang.makeValidName(varNames);

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
orate = X.procRate;

% Load the aircraft full time grid from Time processing
matfile = fullfile(X.tempdir, sprintf('%s_TIME.mat', X.BaseName));
load(matfile, 'datetimeAll');
fullTime = datetimeAll(:);

% Read instrument CSV records
if ~isfield(X,'SIMULATEBUCK')
    X.SIMULATEBUCK = true;
end

% Need these if available
needGROUPS = {'BUCK1011'};
mask = contains(X.rawGROUPS,needGROUPS);
%  Need TAS and temp and pressure groups
GROUPS = X.rawGROUPS(mask) ; % Pressures loaded previously
% Use pivot table and raw mapping table to get " + ...
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

SIMULATEBUCK = true;
if SIMULATEBUCK
    rawNames = [ ...
        "BuckDewPoint" 
        "BuckPressure"
        "BuckBoardTemp"
        "BuckMirrorFlag"
        "BuckDataFlag"]
    [DateTime,numMat,records] = simulateBuck(fullTime)
    %Balance(ii), MirrorT(ii), Flag(ii), Pressure(ii), PWM(ii), Mirror(ii), BoardT(ii), dateStr(ii,:), timeStr(ii,:));
    BuckDewPoint   = numMat(:,2);
    BuckPressure   = numMat(:,4);
    BuckBoardTemp  = numMat(:,7);
    BuckMirrorFlag = numMat(:,3);
    BuckDataFlag   = numMat(:,6);  
            Flag – Indicates the following:
            0 – normal operation
            1 – dew or frost point achieved on mirror
            2 – balance mode
end

% Write variables out to matfile
matfile = fullfile(X.tempdir, sprintf('%s_BUCK1011.mat', X.BaseName));
delete(matfile)

save(matfile, saveVars{:});

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')
;
load_ncFINAL(X.ncFINAL,matfile);
sprintf('Processed get_varBUCK1011.m for Project: %s',X.PROJ)

end


function [DateTime,numMat,records] = simulateBuck(fullTime)
 
% Temporary simulation: if user requests simulated BUCK data,
% synthesize CSV strings that match the aircraft full time grid.

 % Temporary simulation: if user requests simulated BUCK data or no records
% exist, synthesize CSV strings that match the aircraft full time grid.
% Set X.SIMULATEBUCK = true to force generation; user will remove this block
% when real data is available.
if (isfield(X,'SIMULATEBUCK') && X.SIMULATEBUCK) || isempty(records)
    n = numel(fullTime);
    % Constant/example numeric fields: Balance, MirrorT, Flag, Pressure, PWM, Mirror, BoardTemp
    Balance = repmat(14354, n, 1);
    MirrorT  = repmat(-14.23, n, 1);
    Flag     = zeros(n,1);
    Pressure = zeros(n,1);
    PWM      = repmat(-56, n, 1);
    Mirror   = zeros(n,1);
    BoardT   = repmat(33.00, n, 1);

    % Format date/time as MM/dd/yyyy and HH:MM:SS
    dateStr = upper(datestr(fullTime, 'mm/dd/yyyy'));
    timeStr = datestr(fullTime, 'HH:MM:SS');

    % Build CSV lines matching the BUCK layout
    simLines = strings(n,1);
    for ii=1:n
        simLines(ii) = sprintf('%d,%.2f,%d,%d,%d,%d,%.2f,%s,%s', ...
            Balance(ii), MirrorT(ii), Flag(ii), Pressure(ii), PWM(ii), Mirror(ii), BoardT(ii), dateStr(ii,:), timeStr(ii,:));
    end

    % Replace parsed records with simulated ones
    lines = simLines;
    records = strtrim(split(lines, ','));
    numMat = str2double(records(:,1:7));
    dateStrings = records(:,8);
    timeStrings = records(:,9);
    DateTime = datetime(dateStrings + " " + timeStrings, 'InputFormat', 'MM/dd/yyyy HH:mm:ss');
end

end