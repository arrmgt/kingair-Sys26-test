function mask = detectOutliers(x, method, threshold)
%DETECTOUTLIERS Return a logical "keep" mask (true = not an outlier).
%
%   mask = detectOutliers(x, method, threshold)
%
%   method    - 'mad' (default, robust median-absolute-deviation test) |
%               'zscore' (mean/std test, less robust to outliers than
%               'mad', but more familiar) | 'none' (only NaN/Inf removed)
%   threshold - number of scaled-MAD or std deviations allowed
%               (default 5)
%
%   mask is false for NaN/Inf values and for points beyond `threshold`
%   robust deviations from the center of x.
%
% See also: loadFlightData

if nargin < 2 || isempty(method), method = 'mad'; end
if nargin < 3 || isempty(threshold), threshold = 5; end

x = x(:);
finiteMask = isfinite(x);

switch lower(method)
    case 'mad'
        m = median(x(finiteMask));
        devs = abs(x - m);
        madRobust = 1.4826 * median(devs(finiteMask));
        if madRobust == 0, madRobust = eps; end
        keep = devs <= threshold * madRobust;
    case 'zscore'
        mu = mean(x(finiteMask));
        sd = std(x(finiteMask));
        if sd == 0, sd = eps; end
        keep = abs(x - mu) <= threshold * sd;
    case 'none'
        keep = true(size(x));
    otherwise
        error('detectOutliers:badMethod', ...
            'method must be ''mad'', ''zscore'', or ''none'' (got ''%s'').', method);
end

mask = keep & finiteMask;

end
