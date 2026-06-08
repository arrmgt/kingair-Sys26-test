function frd = enu2frd(enu, roll, pitch, heading, deg)
% enu2frd Vectorized ENU -> FRD without a for-loop
% frd = enu2frd(enu, roll, pitch, heading)
% enu: 3xN or Nx3 (columns are [east; north; up])
% roll,pitch,heading: scalar or length-N vectors (same order as frd2enu)
% deg: optional logical (default false). If true, angles are degrees.
%
% Output frd is 3xN with rows [forward; right; down].

if nargin<5, deg = false; end

% Normalize enu to 3xN
if size(enu,1)==3
    E = enu;
elseif size(enu,2)==3
    E = enu.';
else
    error('enu must be 3xN or Nx3');
end
N = size(E,2);

% Expand angles to 1xN
if isscalar(roll),  roll = repmat(roll,1,N); end
if isscalar(pitch), pitch = repmat(pitch,1,N); end
if isscalar(heading), heading = repmat(heading,1,N); end

roll   = reshape(roll,1,[]);
pitch  = reshape(pitch,1,[]);
heading= reshape(heading,1,[]);

if any([numel(roll), numel(pitch), numel(heading)] ~= N)
    error('roll, pitch, heading must be scalars or length-N vectors');
end

if deg
    roll = deg2rad(roll); pitch = deg2rad(pitch); heading = deg2rad(heading);
end

% Precompute trig (1xN)
cr = cos(roll); sr = sin(roll);
ct = cos(pitch); st = sin(pitch);
cp = cos(heading); sp = sin(heading);

% DCM components R = Rz*Ry*Rx as in frd2enu
r11 =  cp.*ct;
r12 =  cp.*sr.*st - sp.*cr;
r13 =  cp.*cr.*st + sp.*sr;

r21 =  sp.*ct;
r22 =  sp.*sr.*st + cp.*cr;
r23 =  sp.*cr.*st - cp.*sr;

r31 = -st;
r32 =  ct.*sr;
r33 =  ct.*cr;

% Apply R^T (which maps ENU -> body_z_up coordinates)
Ex = E(1,:); Ey = E(2,:); Ez = E(3,:);

% R^T * E  => body_z_up components (x_b_up; y_b_up; z_b_up)
bx_up = r11.*Ex + r21.*Ey + r31.*Ez;
by_up = r12.*Ex + r22.*Ey + r32.*Ez;
bz_up = r13.*Ex + r23.*Ey + r33.*Ez;

% Convert body z-up to body down-positive (FRD): invert z
bz_down = -bz_up;

frd = [bx_up; by_up; bz_down];
end
