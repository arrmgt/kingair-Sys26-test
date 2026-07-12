function [tStart, tStop, utcOffset, Tref]  = aircraftDateTime(timeData, units)
% read time values and units attribute
% timeData:  numeric (seconds)
% units: e.g. "seconds since 2026-01-01 00:00:00 +0000"
% timeData = ncread('file.nc','time');         
% units = ncreadatt('file.nc','time','units'); 
% full_script_Tref_format.m
% Read netCDF time variable and produce Tref_str like "2026-01-01 00:00:00 +0000"

% Parse units: accept +HHMM, +HH:MM, or Z
tokens = regexp(units, '^\s*\w+\s+since\s+(?<epoch>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s*(?<tz>Z|[+\-]\d{2}:?\d{2})\s*$','names');
if isempty(tokens)
    error('Unexpected units string format: %s', units);
end

% Normalize timezone to +HH:MM or 'Z'
tz = tokens.tz;
if ~strcmpi(tz,'Z') && ~contains(tz,':')
    tz = [tz(1) tz(2:3) ':' tz(4:5)];   % +HHMM -> +HH:MM
end

% Build Tref datetime preserving original timezone
if strcmpi(tz,'Z')
    Tref = datetime(tokens.epoch, 'InputFormat','uuuu-MM-dd HH:mm:ss', 'TimeZone','UTC');
else
    Tref = datetime([tokens.epoch ' ' tz], 'InputFormat','uuuu-MM-dd HH:mm:ss XXX', 'TimeZone', tz);
end

% Ensure Tref displays full date+time by setting Format (shows timezone as +00:00)
Tref.Format = 'yyyy-MM-dd HH:mm:ss Z';

% Also produce a string exactly like "2026-01-01 00:00:00 +0000" (no colon in offset)
if strcmpi(tokens.tz,'Z')
    tzOut = '+0000';
else
    % tokens.tz may be "+HHMM" or "+HH:MM"; normalize to "+HHMM"
    tzRaw = tokens.tz;
    if ~contains(tzRaw,':')
        tzOut = tzRaw;
    else
        tzOut = strrep(tzRaw,':',''); % "+HH:MM" -> "+HHMM"
    end
end
Tref_str = sprintf('%s %s', char(datestr(Tref,'yyyy-mm-dd HH:MM:SS')), tzOut);

% UTC offset as signed duration
if strcmpi(tokens.tz,'Z')
    utcOffset = duration(0,0,0);
else
    % use normalized tz (with colon) to parse hours/minutes
    tzNorm = tz; % "+HH:MM"
    signChar = tzNorm(1);
    hh = str2double(tzNorm(2:3));
    mm = str2double(tzNorm(5:6));
    utcOffset = duration(hh, mm, 0);
    if signChar == '-'
        utcOffset = -utcOffset;
    end
end

% Epoch for epochtime conversion (expressed in UTC)
epochUTC = Tref;
epochUTC.TimeZone = 'UTC';

% Build datetime array (result in UTC)
t = datetime(timeData, 'ConvertFrom','epochtime', 'Epoch', epochUTC, 'TicksPerSecond', 1, 'TimeZone','UTC');

% Start and stop
tStart = t(1);
tStop  = t(end);

% Display results
disp(['Tref_str = ' Tref_str])
disp('Tref (datetime with Format) = '), disp(Tref)
disp(['utcOffset = ' char(utcOffset)])
disp(['tStart = ' char(tStart)])
disp(['tStop  = ' char(tStop)])
