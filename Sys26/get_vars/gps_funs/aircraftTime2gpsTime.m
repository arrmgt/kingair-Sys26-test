function G = aircraftTime2gpsTime(time,units,format)
%DATETIME2GPSTIME Convert aircraft time to GPS time quantities
% Convert numeric seconds time array with CF-style units
% to GPS time quantities 
%
% INPUTS:
%   time   : numeric array (seconds)
%   units  : e.g. "seconds since 2022-01-01 00:00:00 +0000"
%   format : e.g. "seconds since %F %T %z"
%
% OUTPUT (struct G):
%   G.gpsSeconds   - GPS seconds since epoch
%   G.week         - GPS week number
%   G.tow          - Time of week (s)
%   G.day          - Day number since GPS epoch
%   G.rollover     - GPS rollover count (1024-week cycles)
%   G.leapSeconds  - GPS-UTC leap seconds

    arguments
        time (:,1) double
        units (1,1) string
        format (1,1) string
    end

    %--------------------------------------------------------------
    % 0. Normalize format 
    %--------------------------------------------------------------
    format = replace(format, "%F", "yyyy-MM-dd");
    format = replace(format, "%T", "HH:mm:ss");
    format = replace(format, "%z", "Z");

    %--------------------------------------------------------------
    % 1. Reference UTC datetime
    %--------------------------------------------------------------
    refTimeStr = extractAfter(units, "since ");
    dtFormat   = extractAfter(format, "since ");

    if strlength(refTimeStr) == 0
        error('Units string must contain "since"');
    end

    refTime = datetime(refTimeStr, ...
        'InputFormat', dtFormat, ...
        'TimeZone', 'UTC');

    %--------------------------------------------------------------
    % 2. UTC time array (vectorized, monotonic or not)
    %--------------------------------------------------------------
    tUTC = refTime + seconds(time);

    % Ensure UTC
    if isempty(tUTC.TimeZone)
        tUTC.TimeZone = 'UTC';
    else
        tUTC = datetime(tUTC,'TimeZone','UTC');
    end

    % GPS epoch
    gpsEpoch = datetime(1980,1,6,0,0,0,'TimeZone','UTC');

    % Leap seconds table (UTC dates when leap second became effective)
    leapDates = datetime( ...
        [1981 6 30;
         1982 6 30;
         1983 6 30;
         1985 6 30;
         1987 12 31;
         1989 12 31;
         1990 12 31;
         1992 6 30;
         1993 6 30;
         1994 6 30;
         1995 12 31;
         1997 6 30;
         1998 12 31;
         2005 12 31;
         2008 12 31;
         2012 6 30;
         2015 6 30;
         2016 12 31], ...
        'TimeZone','UTC');

    % Leap second count
    leapSeconds = sum(tUTC > leapDates.', 2);

    % GPS seconds since epoch
    gpsSeconds = seconds(tUTC - gpsEpoch) + leapSeconds;

    % GPS week and TOW
    week = floor(gpsSeconds / 604800);
    tow  = gpsSeconds - week * 604800;

    % Day number
    day = floor(gpsSeconds / 86400);

    % GPS rollover
    rollover = floor(week / 1024);

    % Output struct
    G = struct( ...
        'gpsSeconds', gpsSeconds, ...
        'week', week, ...
        'tow', tow, ...
        'day', day, ...
        'rollover', rollover, ...
        'leapSeconds', leapSeconds );
end