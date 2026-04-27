function [waterContent,vcol,vref,icol,iref] = ...
  get_nevzorov(rawfile,ncfile,Rate,probe,tas,tc,pres,ias)

% GET_NEVZOROV process data from the Nevzorov total water content probe
%
%   [waterContent,vcol,vref,icol,iref] = get_nevzorov(NC,MC,Rate,probe)
%
% Resample analog channel to 'Rate' and calculate the water content
% for the Nevzorov probe
%
% Inputs
%   NC    - netcdf object from the netcdf toolbox for the raw data
%   MC    - netcdf object for the header
%   Rate  - output rate
%   probe - 'L' or 'T' for liquid or total water content
%   tas   - true airspeed [m/s]
%   tc    - air temperature [celsius]
%   pres  - static pressure [hPa]
%   ias   - indicated airspeed [m/s]
%
% Outputs
%   waterContent - the water content
%   vcol         - collector voltage
%   vref         - reference voltage
%   icol         - collector current
%   iref         - reference current

% Use VLWCREF or VTWCREF for rate and attributes

vrefvar = ['V' probe 'WCREF'];
try
    [irate,dims,frate,FillValue]=get_irate(rawfile,vrefvar);
    if(isempty(FillValue))
        FillValue-2^15;
    end
catch ME
    'get_nevzorov: no vrefvar found';
    waterContent = [];
    vcol         = [];
    vref         = [];
    icol         = [];
    iref         = [];
    return
end

vcol    = getdata(rawfile,['V' probe 'WCCOL'],'OutputRate',Rate);
vref    = getdata(rawfile,['V' probe 'WCREF'],'OutputRate',Rate);
icol    = getdata(rawfile,['I' probe 'WCCOL'],'OutputRate',Rate);
iref    = getdata(rawfile,['I' probe 'WCREF'],'OutputRate',Rate);

% Get needed attributes
try
    sa      = ncreadatt(rawfile,vrefvar,'SampleArea')*1e-4;
    tnev    = double(ncreadatt(rawfile,vrefvar,'temperature'));
    coefs   = ncreadatt(rawfile,vrefvar,'AdditionalCoefficients');
catch
    'get_nevzorov: not enough calibration information';
    waterContent=-2^15.*ones(size(vcol));
    return
end
    

% Add file revision to the global attributes in the header file.
%hdrname = name(MC)
% Open the header file for writing
%MC      = netcdf(hdrname,'write');

[ninterp,ndecim] = interp_decim(irate,Rate);


if isempty(vcol) | isempty(vref) | isempty(icol) | isempty(iref)
  waterContent = [];
  return
end

lw  = 4.218*(tnev - tc) + 1918.46 * ((tnev + 273.15) ./ (tnev + 239.24)) .^ 2;
k   = coefs(1).*pres + coefs(2).*ias + coefs(3);
pow = vcol .* icol - k .* vref .* iref;
waterContent = pow ./ tas ./ sa ./ lw;

% Fill water content values when instrument is off
waterContent(find(vref < 1)) = -2^15;

% Copy vref attributes to the water content variable in header
% and replace or delete as needed.
outvar = ['nev' lower(probe) 'wc'];
if ~isempty(outvar); 
    copyRawAtts( rawfile,vrefvar, ncfile,outvar );
    ncwriteatt(ncfile,outvar,'CalibrationDate','');
end

return
end




