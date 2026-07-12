function x = repairOne(x, kk)
%REPAIRONE Interpolate x over gaps using known-good samples at kk
%indices, and constant-extrapolate before the first / after the last kk
%index. x stays FULL LENGTH (this does not subset/shrink the array).
%
%   x = repairOne(x, kk)
%
%   Ported directly from the user's helper of the same name. Typical use:
%   compute a rough in-flight index set kk (e.g. from a simple pressure
%   threshold condition), then repair every channel with it BEFORE
%   computing the real/final kk selection -- this fills short
%   non-qualifying dips within the flight via linear interpolation
%   between neighboring in-flight samples, and flattens anything before
%   takeoff / after landing to the nearest in-flight boundary value,
%   rather than simply leaving those samples untouched or dropping them.
%   The final kk (possibly a different, more refined condition) is then
%   evaluated on this repaired data -- see loadFlightDataFromMat's
%   repairKkFcn (drives this repair) vs kkFcn (final selection,
%   evaluated after repair).
%
%   NOTE on the `if all(kk > 10)` guard: ported from the original, with
%   one fix -- MATLAB's all([]) returns TRUE (vacuously) for an empty
%   array, so the original guard would let an EMPTY kk fall through into
%   interp1(kk, x(kk), ...) and error deep inside interp1 trying to index
%   kk(1)/kk(end) ("Index exceeds array bounds"). An explicit
%   ~isempty(kk) check was added so an empty kk instead skips repair (x
%   returned unchanged) with a warning -- which usually means your rough
%   in-flight condition (repairKkFcn) matched zero samples and is worth
%   checking.
%
% See also: loadFlightDataFromMat

x = x(:);
kk = kk(:);
allSamples = (1:numel(x))';
if ~isempty(kk) && all(kk > 10)
    x = interp1(kk, x(kk), allSamples, 'linear', NaN);
    x(allSamples < kk(1)) = x(kk(1));
    x(allSamples > kk(end)) = x(kk(end));
elseif isempty(kk)
    warning('repairOne:emptyKk', ...
        'kk is empty -- skipping repair for this channel (returned unchanged). Check your rough in-flight condition (repairKkFcn).');
end
end
