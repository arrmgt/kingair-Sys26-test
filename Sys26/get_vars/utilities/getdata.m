function [x, irate, nmiss, units0] = getdata(ncfile, Var, varargin)
%GETDATA  Retrieve a NetCDF variable.
%   [x, irate, nmiss, units0] = GETDATA(ncfile, Var, orate, ...)
%
%   Inputs:
%       ncfile : path to NetCDF file
%       Var    : variable name
%   Optional name/value pairs:
%     OutputRate : output rate
%     UnitsOut  : desired output units (default "")
%     FillValue : fill value for missing data (default -32767)
%
%   Outputs:
%     x       : processed data (column vector)
%     irate   : input sample rate
%     nmiss   : number of missing values filled
%     units0  : original units read from file
%
%%   This function reads variables into their **working dimension order**
%%       and must be converted from the **netcdf dimension order**
%   Dimensions are time (nt), samples/sec (sps), and cell (vec)
%   kingair processing working variables are:  if nd = # of dimensions
%       nd = 1 →  X(nt,1)
%       nd = 2 →  X(nt*sps,1)       % "High Rate"
%       nd = 3 →  X(nt*sps, vec)    % "Cell" variables (spectra)
%   Working variable A(nt*sps,vec) is converted to A_nc for netcdf storage
%%     A_nc = reshape( permute(A,[2 1]), [vec, nch, nt] );
%   Netcdf onput variables have the follow dimensions **netcdf dimension order**
%       nd = 1 →  X(nt)
%       nd = 2 →  X(nt, sps)
%       nd = 3 →  X(nt, sps, vec)
%   Converting from netcdf back back to working
%     A = reshape( permute(A,[3 2 1], [nt,nch,vec] );

p = inputParser;
addParameter(p, "OutputRate",[], @(x)isnumeric(x)&&isscalar(x));
addParameter(p, "UnitsOut", "unknown", @(s)ischar(s)||isstring(s));
addParameter(p, "FillValue", -32767, @(x)isnumeric(x)&&isscalar(x));
parse(p, varargin{:});
Opts = p.Results;
orate = Opts.OutputRate;
fill = Opts.FillValue;
units1 = Opts.UnitsOut;

try
    units0 = ncreadatt(ncfile, Var, 'units');
catch
    units0 = 'unknown';
    warning('%s: no units attribute found.', Var);
end

% Get input rate and metadata
[irate, dims, frate,FillValue] = get_irate(ncfile, Var);
if isempty(orate);
    orate = irate;
end
% Read variable
blurf = ncread(ncfile, Var);
nd = numel(dims);
switch nd
    case {1,2}
        [sps,nt] = size(blurf);
        % netcdf: (vec, sps, time)
        % working: (time, sps, vec)
        blurf = blurf(:);
    case 3
        [vec,sps,nt] = size(blurf);
        % netcdf: (vec, sps, time)
        % working: (time, sps, vec)
        A = permute(blurf, [2 3 1]);
        blurf = reshape(A, [],vec);
        % Cell data is >=0;
        blurf(blurf<0)=0;
        % interp and decimate if needed
        if ~isempty(orate)
            [ninterp, ndecim] = interp_decim(irate, orate);
            for ch=1:vec
                x = Ninterp(blurf(:,ch), ninterp, 'linear');
                blurf = decimateByFactors(x, ndecim, 'FIR');
            end
        end
        x=blurf;
        nmiss = [];
        units0 = [];
        return        
    otherwise
        error('from_nc: unsupported nd=%d', nd);
end

% Convert units if needed
try
    y = convertUnits(blurf, units0, units1);
    if ~all(isnan(y)), blurf = y; end
catch
    warning('%s: failed to convert units (%s → %s).', Var, units0, units1);
end

% Fill missing data
kk = find(blurf ~= fill & ~isnan(blurf));
if numel(kk) < numel(blurf) & ~isempty(kk)
    blurf = double(blurf);
    blurf = interp1(kk, blurf(kk), 1:numel(blurf), 'spline', fill);
    nmiss = numel(blurf) - numel(kk);
else
    nmiss = 0;
end

% Unwrap angular data
if ~isempty(units0) && (contains(units0,'deg','IgnoreCase',true) || contains(units0,'rad','IgnoreCase',true))
    x = unwrap_wrap(blurf, 1, 1, fill, units0);
else
    x = blurf;
end

% Resample to output rate
if ~isempty(orate)
    [ninterp, ndecim] = interp_decim(irate, orate);
    x = Ninterp(x, ninterp, 'linear');
    x = decimateByFactors(x, ndecim, 'FIR');
    x = x(:); % ensure column vector
end

end
