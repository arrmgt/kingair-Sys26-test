function [schema1 X]= make_schema(X)
%MAKE_SCHEMA Create NetCDF schema from 
%   variables database and variables spreadsheets
%   schema1 = make_schema(X) 

% Get variable names, suffixes, etc.
[arcNames,rawNames] = getVarsAndRawNames(X.Ptable,X.rawGROUPS,X.Ttable);

% NetCDF constants
    NC_GLOBAL = netcdf.getConstant('NC_GLOBAL');
    NC_CHAR   = netcdf.getConstant('NC_CHAR');
    NC_DOUBLE = netcdf.getConstant('NC_DOUBLE');
    NC_FLOAT  = netcdf.getConstant('NC_FLOAT');
    NC_INT    = netcdf.getConstant('NC_INT'); % equiv to int32
    NC_INT64  = netcdf.getConstant('NC_INT64');
    
    % Create NetCDF4 output file
    fprintf('make_schema: trying ...')
    ncid = netcdf.create(X.ncFINAL, ...
            bitor( ...
           netcdf.getConstant("NETCDF4"), ...
           netcdf.getConstant("CLOBBER")) ...
           );
    fprintf('Working...')

    % Close netcdf ncid on exit
    cleanupObj = onCleanup(@() safeClose(ncid)); % saveClose is in this file
    
    % Define time dimension
    timedim = get_spsdim(ncid, 'time', X.time_len);

    % Copy global attributes from raw file
    NC = ncinfo(X.RawPath);
    for i = 1:numel(NC.Attributes)
        try
            netcdf.putAtt(ncid, NC_GLOBAL, NC.Attributes(i).Name, NC.Attributes(i).Value);
        catch ME
            warning('Failed to copy attribute %s: %s', NC.Attributes(i).Name, ME.message);
            netcdf.close(ncid);
            error("Aborted.");
        end
    end

    % Add extra global attributes from optional file
    if exist(X.localGlobalAtts, 'file') == 2
        GAtts = readtable(X.localGlobalAtts);
        % Remove semicolon from values
        GAtts{:,2} = replace(GAtts{:,2}, ";", "");
        for i = 1:height(GAtts)
            AttName  = string(GAtts{i,1});
            AttValue = string(GAtts{i,2});
            parts = split(AttValue,',');
            value = str2double(strtrim(parts)); % NaN if not numeric
            if ~isnan(value)
                AttValue = value;
            end
            netcdf.putAtt(ncid, NC_GLOBAL, AttName, AttValue);
        end
    end

    % Add flags
    netcdf.putAtt(ncid, NC_GLOBAL, 'TempUsed',  X.TempUsed);
    netcdf.putAtt(ncid, NC_GLOBAL, 'PressUsed', X.PressUsed);
    netcdf.putAtt(ncid, NC_GLOBAL, 'DP1Used', X.DP1Used);

    % Scrolling through variablesXX-1.txt
    for k = 1:numel(arcNames)  
        name = arcNames(k);
        [name1, TYPE, OutputRate, anames, atts] = ...
            readAttributesDB(X.varDB,name, X.procRate);
        spsName = sprintf('sps%d', OutputRate);
        spsdim = get_spsdim(ncid, spsName, OutputRate);
        if(isempty(spsdim))
            %%%{'make_schema:' name,OutputRate,spsdim}
        end
        % Check for vector dimension
        vecIdx = find(strcmpi(anames, 'VectorLength'));
        if ~isempty(vecIdx)
            VLength = str2double(atts{vecIdx});
            vecdim = get_spsdim(ncid, sprintf('vec%d', VLength), VLength);
            dims = [vecdim,spsdim,timedim];
        else
            if (OutputRate==1)
                dims = timedim; % e.g. (time)
            else
                dims = [spsdim, timedim]; % e.g. (sps25, time);
            end
        end

        % Define variable
        try
            switch TYPE
                case 'Char'
                    varid = netcdf.defVar(ncid, name1, NC_CHAR, dims);
                case 'Double'
                    varid = netcdf.defVar(ncid, name1, NC_DOUBLE, dims);
                case 'Float'
                    varid = netcdf.defVar(ncid, name1, NC_FLOAT, dims);
                case {'Integer64'}
                    varid = netcdf.defVar(ncid, name1, NC_INT64, dims);
                case {'Integer32'}
                    varid = netcdf.defVar(ncid, name1, NC_INT, dims);
                case {'Integer'}
                    varid = netcdf.defVar(ncid, name1, NC_INT, dims);
                otherwise
                    warning('Unknown type for variable %s. Skipping.', name);
                    continue;
            end
        catch ME
            warning('Could not define variable %s: %s', name, ME.message);
            netcdf.close(ncid);
            schema1 = -1;
            return;
        end

        if isempty(varid) || varid < 0
            warning('Invalid varid for variable %s. Skipping.', name);
            continue;
        end

        % Apply attributes
        netcdf.defVarFill(ncid, varid, false, X.FillValue);
        for jj = 1:numel(anames)
            aname = string(anames{jj});
            try
            att   = string(atts{jj});
            catch
                {name}
            end
            attval = str2double(att); % NaN if not numeric
            if ~isnan(attval) % Numeric
                netcdf.putAtt(ncid, varid, aname, attval);
            else % Character string
                netcdf.putAtt(ncid, varid, aname, att);
            end
        end
    end

    % Finalize NetCDF definition
    try
        netcdf.endDef(ncid);
        fprintf('SUCCESS!\n')
    catch ME
        warning("Problem with defines (make_schema.m): %s", ME.message);
        netcdf.close(ncid);
        cleanupObj = onCleanup(@() netcdf.close(ncid));
        clear cleanupObj;    % prevents double-close warnings (optional)
        schema1 = -1;
        return;
    end

    netcdf.close(ncid);
    cleanupObj = onCleanup(@() netcdf.close(ncid));

    % Return schema info
    schema1 = ncinfo(X.ncFINAL);
end

function safeClose(ncid)
    try, netcdf.endDef(ncid); end
    try, netcdf.close(ncid); end
end