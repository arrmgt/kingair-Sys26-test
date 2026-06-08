function Venu = bodyFRD_to_ENU(att, Vbody)
% bodyFRD_to_ENU_Nx3  Convert body FRD velocities to ENU (rows: samples).
%   Venu = bodyFRD_to_ENU_Nx3(att, Vbody)
%   att:  Nx3 [roll, pitch, heading_true] (heading = clockwise-from-north)
%   Vbody: Nx3 [x_forward, y_right, z_down]
%   Venu:  Nx3 [East, North, Up]
%
%   Notes:
%   - Angles may be in radians or degrees. If any abs(angle) > 2*pi, degrees assumed.
%   - Converts heading (clockwise-from-north) -> yaw = -heading (CCW from north).
%   - Uses ZYX order (angle2dcm: yaw, pitch, roll) to build DCM mapping body->nav.
%   - Requires Aerospace Toolbox for angle2dcm. If not present, let me know for a pure-MATLAB replacement.

% Validate sizes
if size(att,2) ~= 3 || size(Vbody,2) ~= 3
    error('att and Vbody must be Nx3 arrays (rows = samples).');
end
if size(att,1) ~= size(Vbody,1)
    error('att and Vbody must have the same number of rows (samples).');
end

N = size(att,1);

% Convert to column vectors (Nx1)
roll_v  = att(:,1);
pitch_v = att(:,2);
hdg_v   = att(:,3);   % true heading (clockwise from north)

% Detect degrees
if any(abs([roll_v; pitch_v; hdg_v]) > 2*pi)
    roll_v  = deg2rad(roll_v);
    pitch_v = deg2rad(pitch_v);
    hdg_v   = deg2rad(hdg_v);
end

% Convert heading convention to mathematical yaw (CCW from north)
yaw_v = -hdg_v;   % Nx1

% Build DCMs using Aerospace Toolbox angle2dcm (inputs must be column)
% angle2dcm expects arguments yaw, pitch, roll and returns 3x3xN (body->nav)
DCM = angle2dcm(yaw_v, pitch_v, roll_v, 'ZYX');   % 3x3xN

% Prepare body velocities as 3x1xN for pagemtimes (convert rows->columns)
Vb3 = permute(reshape(Vbody.', [3,1,N]), [1,2,3]);   % 3x1xN

% Apply DCMs: resulting navigation vectors are in NAV frame consistent with angle2dcm
Vnav3 = pagemtimes(DCM, Vb3);   % 3x1xN

% Interpret angle2dcm nav axes: yaw measured CCW from north -> nav axes are [North; East; Up/Down]
% angle2dcm with body->nav using ZYX typically produces NED if body z is down; to produce ENU, convert.
% Here we assume navigation vector from DCM is in NED ordering: [North; East; Down]
% Convert NED -> ENU: [E; N; U] = [E; N; -D] where D is down
% So mapping matrix P (3x3): P * [N; E; D] = [E; N; U]
P = [0 1 0;
     1 0 0;
     0 0 -1];

% Apply P per page
P3 = repmat(P, [1,1,N]);               % 3x3xN
Venu3 = pagemtimes(P3, Vnav3);         % 3x1xN

% Convert back to Nx3 rows
Venu_mat = squeeze(Venu3);             % 3xN
Venu = Venu_mat.';                     % Nx3
end
