function enu = frd2enu(body, roll, pitch, heading, deg)
% frd2enu Convert FRD (forward,right,down) -> ENU (east,north,up)
% body: 3xN or Nx3 (columns are [f;r;d])
% roll,pitch,heading: scalar or 1xN/ Nx1 (same length N)
% deg: optional logical, true if angles are degrees (default false)

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

% Expand or validate angles
if isscalar(roll), roll = repmat(roll,1,N); end
if isscalar(pitch), pitch = repmat(pitch,1,N); end
if isscalar(heading), heading = repmat(heading,1,N); end

roll  = reshape(roll,1,[]);
pitch = reshape(pitch,1,[]);
heading= reshape(heading,1,[]);

if ~all([numel(roll), numel(pitch), numel(heading)]==[N,N,N])
    error('roll, pitch, heading must be scalars or length N vectors');
end

if deg
    roll = deg2rad(roll); pitch = deg2rad(pitch); heading = deg2rad(heading);
end

% Convert body down-positive to body z-up for standard math rotations
B(3,:) = -B(3,:);

% Preallocate output
E = zeros(3,N);

for k = 1:N
    cr = cos(roll(k)); sr = sin(roll(k));
    ct = cos(pitch(k)); st = sin(pitch(k));
    cp = cos(heading(k)); sp = sin(heading(k));
    Rx = [1  0   0;
          0 cr -sr;
          0 sr  cr];
    Ry = [ ct  0  st;
           0   1   0;
          -st  0  ct];
    Rz = [ cp -sp  0;
           sp  cp  0;
            0   0  1];
    R = Rz * Ry * Rx;
    E(:,k) = R * B(:,k);   % east; north; up
end

enu = E;
end
