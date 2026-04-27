ncfile = fullfile('P:/MATLAB-DATA2','kingair_data','groundtest26','work','20101125_184107_raw.nc');
info = ncinfo(ncfile);
NAMES = {info.Variables.Name}
