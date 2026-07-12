function varTable = listNetCDFVariables(ncFile)
%LISTNETCDFVARIABLES Inspect a NetCDF file and list its variables.
%
%   varTable = listNetCDFVariables(ncFile) returns a table with columns
%   Name, Size, Dimensions, Class describing every variable in ncFile.
%   Used to populate the input/output dropdowns in ncRegressionApp, and
%   is handy on its own for exploring an unfamiliar dataset:
%
%       t = listNetCDFVariables('sample.nc')
%
% See also: ncinfo, ncRegressionApp, streamFitCorrection

info = ncinfo(ncFile);
nv = numel(info.Variables);

names = strings(nv,1);
sizes = strings(nv,1);
dims  = strings(nv,1);
clss  = strings(nv,1);

for k = 1:nv
    v = info.Variables(k);
    names(k) = string(v.Name);
    sizes(k) = string(mat2str(v.Size));
    if isempty(v.Dimensions)
        dims(k) = "";
    else
        dims(k) = strjoin(string({v.Dimensions.Name}), " x ");
    end
    clss(k) = string(v.Datatype);
end

varTable = table(names, sizes, dims, clss, ...
    'VariableNames', {'Name','Size','Dimensions','Class'});

end
