function S = imu2AircraftTime(ac_gps_time, imudata, names)
% IMU2AIRCRAFTTIME  Interpolate IMU/POSPAC data onto aircraft GPS-time samples.
%
%   S = imu2AircraftTime(ac_gps_time, imudata, names)
%
%   INPUTS
%     ac_gps_time : Aircraft GPS seconds 
%     imudata     : Always 200 Hz. [17x200] 
%     names       : Assigned names to the 17 imu variables (arbitrary)
%
%   OUTPUT
%     S : 1x1 struct with one field per entry in `names` 

p = inputParser;
addRequired(p, 'ac_gps_time');
addRequired(p, 'imudata');
addRequired(p, 'names');
parse(p, ac_gps_time, imudata, names);

ac_gps_time = ac_gps_time(:).';     % force row vector
nVars = size(imudata,1);

% imudata gps time base (always 200 Hz): 
% sort time + remove duplicates if exist  (sanity)
gpsTimeRow = 1;
t = imudata(gpsTimeRow, :);
[t, sortIdx] = sort(t);
[t, uniqIdx] = unique(t, 'stable');
sortIdx = sortIdx(uniqIdx);
Y = imudata(:, sortIdx);

% interpolate every non row onto ac_gps_time 
interpVals = interp1(t, Y(1:nVars, :).', ac_gps_time, 'linear', NaN).'; 

% Convert imudata vectors to structure S
fieldNames = matlab.lang.makeValidName(names);   % sanitize for struct fields

S = struct();
for i = 1:nVars
    S.(fieldNames{i}) = interpVals(i, :).';
end

end