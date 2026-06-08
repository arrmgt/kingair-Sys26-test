function Vfrd = enu2frd(att, Venu)
%ENU_TO_FRD Convert earth ENU velocity to aircraft body FRD.
%
% Inputs
%   att   [3 x N] : [roll; pitch; trueheading] in radians
%                    roll        positive right wing down
%                    pitch       positive nose up
%                    trueheading clockwise from true north
%
%   Venu  [N x 3] : [east, north, up]
%
% Output
%   Vfrd  [N x 3] : [forward, right, down]
%
% Notes
%   Earth frame is local ENU.
%   Aircraft/body frame is FRD = [forward, right, down].
%   This is the inverse of bodyFRD_to_ENU(...).

    % checks
    if size(att,1) ~= 3
        error('att must be 3 x N = [roll; pitch; trueheading].');
    end
    if size(Venu,2) ~= 3
        error('Venu must be N x 3 = [east, north, up].');
    end
    if size(att,2) ~= size(Venu,1)
        error('att is 3xN, so Venu must be Nx3 with the same N.');
    end

    % attitude
    roll    = att(1,:).';   % Nx1
    pitch   = att(2,:).';
    heading = att(3,:).';

    % ENU components
    E = Venu(:,1);
    N = Venu(:,2);
    U = Venu(:,3);

    % convert ENU -> NED
    Vn = N;
    Ve = E;
    Vd = -U;

    % trig
    cphi = cos(roll);
    sphi = sin(roll);
    cth  = cos(pitch);
    sth  = sin(pitch);
    cpsi = cos(heading);
    spsi = sin(heading);

    % NED -> FRD  (transpose of FRD -> NED)
    F =  cth .* cpsi .* Vn ...
       + cth .* spsi .* Ve ...
       - sth .* Vd;

    R = (sphi .* sth .* cpsi - cphi .* spsi) .* Vn ...
       + (sphi .* sth .* spsi + cphi .* cpsi) .* Ve ...
       +  sphi .* cth .* Vd;

    D = (cphi .* sth .* cpsi + sphi .* spsi) .* Vn ...
       + (cphi .* sth .* spsi - sphi .* cpsi) .* Ve ...
       +  cphi .* cth .* Vd;

    Vfrd = [F, R, D];
end