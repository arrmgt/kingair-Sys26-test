function [ninterp,ndecim,irate]=get_dims(ncfile,VAR,orate);

% Get the dimesions of variable VAR from netcdf file "ncfile"
info=ncinfo(ncfile);
NAMES={info.Variables.Name};
DIMS={info.Variables.Dimensions};
ii = find(matches(NAMES,VAR));
dimlen=[];
for i = ii
  x=NAMES{i};
  dimlen=DIMS{i};
  dims={dimlen.Length};
  irate=dims{1}; % Samples/sec
  nt = dims{2};  % time dimension
end
if(~isempty(irate) & irate < 2000 & nt > irate);
	[ninterp,ndecim]=interp_decim(irate,orate);
else
	error(sprintf('get_dims: %s not found',VAR));
end
return




