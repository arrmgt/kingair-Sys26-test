function enu = frd2enu_vec(body, roll, pitch, heading, deg)
% frd2enu Vectorized FRD -> ENU without a for-loop
% enu = frd2enu(body, roll, pitch, heading)
% body: 3xN or Nx3 (columns are [forward; right; down])
% roll,pitch,heading: scalar or length-N vectors
% deg: optional logical (default false). If true, angles are degrees.
%
% Output enu is 3xN with rows [east; north; up].

if nargin<5, deg = false; end

% Normalize body to 3xN
if size(body,1)==3
    B = body;
elseif size(body,2)==3
    B = body.';
else
    error('body must be 3xN or Nx3');
end
N = size(B,2);

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

% Convert body down-positive to z-up for math rotations
B(3,:) = -B(3,:);

% Precompute trig functions (1xN)
cr = cos(roll); sr = sin(roll);
ct = cos(pitch); st = sin(pitch);
cp = cos(heading); sp = sin(heading);

% Compute DCM components for R = Rz(psi)*Ry(theta)*Rx(phi)
% r11 ... r33 are 1xN vectors
r11 =  cp.*ct;
r12 =  cp.*sr.*st - sp.*cr;
r13 =  cp.*cr.*st + sp.*sr;

r21 =  sp.*ct;
r22 =  sp.*sr.*st + cp.*cr;
r23 =  sp.*cr.*st - cp.*sr;

r31 = -st;
r32 =  ct.*sr;
r33 =  ct.*cr;

% Apply R to each column of B using elementwise operations
Bx = B(1,:); By = B(2,:); Bz = B(3,:);

E_x = r11.*Bx + r12.*By + r13.*Bz;   % east
E_y = r21.*Bx + r22.*By + r23.*Bz;   % north
E_z = r31.*Bx + r32.*By + r33.*Bz;   % up

enu = [E_x; E_y; E_z];
end
