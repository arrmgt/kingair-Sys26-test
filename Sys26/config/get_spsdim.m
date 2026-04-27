function spsdim = get_spsdim(ncid, spsName, Rate)
%GET_SPSDIM Find or define a NetCDF dimension with a specific length.
%
%   spsdim = GET_SPSDIM(ncid, spsName, Rate)
%   Attempts to find a dimension with length == Rate.
%   If found, returns its ID. Otherwise, defines a new dimension with name
%   spsName and length Rate.
    try
        spsdim = netcdf.inqDimID(ncid, spsName);
    catch
        % So make one
        if(~isempty(Rate))
            spsdim = netcdf.defDim(ncid, spsName, Rate);
        else
            spsdim = [];
        end
        return
    end
    
end