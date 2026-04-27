function [talt,zagl] = get_varTOPO(zfiles,LATX,LONX,ALTX);

TT=datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all


% the MISC output group are just transfered from the *_raw.nc file
% verbatim with maybe a unit change.
%
%

% Initialize the array of terrain heights and geo altitudes
FillValue = 0;
talt = FillValue * ones(size(LATX));
zagl = FillValue * ones(size(LONX));

% Look for missing positions
zzz    = find(LATX>-90 & LATX<90 ...
    & LONX>-180 & LONX<360);
%clip a few points off each end
nclip=100;
zzz = zzz(nclip:end-nclip);

if ~ isempty(zzz)
  % Set the limits of the area to get
  lats = [ min(LATX(zzz))-.1, max(LATX(zzz))+.1 ];
  lons = [ min(LONX(zzz))-.1, max(LONX(zzz))+.1 ];
end
% Get the topography for each point on the flight trackr
% taltXX can be archived

% Get the 1 or 3 second SRTM data
try
    talt(zzz) = srtmHeights(zfiles,LATX(zzz),LONX(zzz));
catch
    talt(zzz) = 0;
    zagl(zzz) = 0;
    'get_varTOPO:  no terrain height available'
    return
end


% Initialize the array of height above ground
zagl = FillValue * ones(size(ALTX));
% Calculate the height above the ground
zagl(zzz) = ALTX(zzz) - talt(zzz);


