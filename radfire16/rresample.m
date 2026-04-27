function [y] = rrsample(x,FsIn, FsOut)
r = FsOut / FsIn;
[P,Q] = rat(r,1e-12);   % P=2, Q=3
y = resample(x,P,Q);    % anti-aliased fractional downsample
