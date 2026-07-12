function plot_windbarb(x, y, u, v, fs, interval_s, convertToKnots)
% do_plot_windbarb Plot wind vectors along a track, sampled every interval_s
%   x, y    : track coordinates (same length as u,v). Can be lon/lat or X/Y
%   u, v    : wind components (m/s) in track coordinate system (east/north)
%   fs      : sampling frequency (Hz), e.g., 25
%   interval_s : desired time interval between plotted arrows (s), e.g., 10
%   convertToKnots : (optional) logical. true -> convert m/s to knots for arrow length
%
% Example:
%   do_plot_windbarb(lon, lat, u, v, 25, 10, true)

if nargin < 7, convertToKnots = false; end

n = numel(u);
assert(numel(x)==n && numel(y)==n && numel(v)==n, 'All inputs must be same length.');
step = round(interval_s * fs);
if step < 1, step = 1; end

idx = 1:step:n;        % indices to plot (every interval_s seconds)
xq = x(idx);
yq = y(idx);
uq = u(idx);
vq = v(idx);

% Optionally convert units (m/s -> knots)
mps_to_kn = 1/0.514444444444444; % ≈1.9438444924406
if convertToKnots
    uq = uq * mps_to_kn;
    vq = vq * mps_to_kn;
    unitLabel = 'knots';
else
    unitLabel = 'm/s';
end

% Plot track
figure;
plot(x, y, '-', 'Color', [0.6 0.6 0.6]); hold on;
plot(xq, yq, 'ko', 'MarkerFaceColor','k','MarkerSize',3); % sample points

% Quiver scaling: pick scale so typical arrow length is visually reasonable
% autoscale by median wind magnitude and desired arrow length in data units
windMag = hypot(uq, vq);
medMag = median(windMag(~isnan(windMag)));
if medMag == 0 || isnan(medMag), medMag = 1; end

% Desired arrow length in axis units (tweak 0.02 as needed)
ax = gca;
xl = xlim(ax); yl = ylim(ax);
diagRange = hypot(diff(xl), diff(yl));
desiredLenFrac = 0.04; % fraction of diag for a median wind vector
desiredLen = desiredLenFrac * diagRange;

% quiver scale parameter: scale = (actual length units) / (display arrow length)
% MATLAB quiver usage: quiver(X,Y,U,V,scale) scales arrows by 1/scale.
% We compute scale such that median magnitude -> desiredLen
scale = medMag / desiredLen ;
if ~isfinite(scale) || scale == 0, scale = 1; end

% Plot quiver (using filled arrows for better visibility)
hq = quiver(xq, yq, uq, vq, 1/scale, 'b', 'LineWidth', 1);
% If you prefer no automatic scaling, use quiver(xq,yq,uq,vq,0,...)

% Improve appearance
axis equal;
xlabel('X'); ylabel('Y');
title(sprintf('Wind vectors every %d s (%s)', interval_s, unitLabel));
grid on;

% Add legend/annotation for reference vector
% Reference arrow at top-left of axis
xpos = xl(1) + 0.05*(xl(2)-xl(1));
ypos = yl(2) - 0.08*(yl(2)-yl(1));
refVal = median(windMag);
if convertToKnots
    refTextVal = sprintf('%.1f %s', refVal, unitLabel);
else
    refTextVal = sprintf('%.1f %s', refVal, unitLabel);
end
quiver(xpos, ypos, refVal, 0, 1/scale, 'r', 'LineWidth', 1.5, 'MaxHeadSize', 2);
text(xpos, ypos - 0.03*diff(yl), ['Ref = ' refTextVal], 'Color','r');

hold off;

end
