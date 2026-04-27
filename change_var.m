function change_var(src, dst, oldName, newName)
% CHANGE_VAR  Copy a NetCDF file to a new file, renaming one variable.
%   change_var(src, dst, oldName, newName)
%
% Example:
%   change_var('in.nc', 'out.nc', 'old_var', 'new_var')

% Open source
srcid = netcdf.open(src, 'NC_NOWRITE');
try
    [numdims, numvars, numgatts, ~] = netcdf.inq(srcid);

    % Create destination (overwrite if exists)
    dstid = netcdf.create(dst, 'CLOBBER');

    % Map source dimids -> destination dimids
    dimids_map = zeros(1, numdims);
    for d = 0:numdims-1
        [dname, dlen] = netcdf.inqDim(srcid, d);
        % If dimension is unlimited in source, set length to 0 in defDim to make it unlimited
        if dlen == 0
            dimids_map(d+1) = netcdf.defDim(dstid, dname, netcdf.getConstant('NC_UNLIMITED'));
        else
            dimids_map(d+1) = netcdf.defDim(dstid, dname, dlen);
        end
    end

    % Copy global attributes in define mode
    for a = 0:numgatts-1
        aname = netcdf.inqAttName(srcid, netcdf.getConstant('NC_GLOBAL'), a);
        aval = netcdf.getAtt(srcid, netcdf.getConstant('NC_GLOBAL'), aname);
        % Determine attribute type and write accordingly
        netcdf.putAtt(dstid, netcdf.getConstant('NC_GLOBAL'), aname, aval);
    end

    % Define variables in destination and copy variable attributes (still in define mode)
    varid_map = zeros(1, numvars);
    var_info = struct('name', cell(1,numvars), 'xtype', [], 'vdims', [], 'natts', []);
    for v = 0:numvars-1
        [vname, xtype, vdims, natts] = netcdf.inqVar(srcid, v);
        var_info(v+1).name = vname;
        var_info(v+1).xtype = xtype;
        var_info(v+1).vdims = vdims;
        var_info(v+1).natts = natts;

        if strcmp(vname, oldName)
            outname = newName;
        else
            outname = vname;
        end

        outDimIDs = dimids_map(vdims + 1);   % convert to MATLAB indices
        dstVarID = netcdf.defVar(dstid, outname, xtype, outDimIDs);
        varid_map(v+1) = dstVarID;

        % copy variable attributes while in define mode
        for a = 0:natts-1
            aname = netcdf.inqAttName(srcid, v, a);
            aval = netcdf.getAtt(srcid, v, aname);
            netcdf.putAtt(dstid, dstVarID, aname, aval);
        end
    end

    % End define mode before writing data
    netcdf.endDef(dstid);

    % Copy variable data. Use block-wise copy for large variables.
    for v = 0:numvars-1
        srcVarID = v;
        dstVarID = varid_map(v+1);

        % Get variable info
        [~, xtype, vdims, ~] = netcdf.inqVar(srcid, srcVarID);
        dimlens = zeros(1, numel(vdims));
        for k = 1:numel(vdims)
            [~, dlen] = netcdf.inqDim(srcid, vdims(k));
            dimlens(k) = dlen;
        end

        % If variable has zero total size (empty), skip
        if any(dimlens == 0) && ~isempty(dimlens)
            % For unlimited dims with zero length, skip writing data.
            continue;
        end

        % Decide whether to copy in one call or chunked:
        totalElems = prod(dimlens);
        maxElemsPerCall = 1e7; % adjust as needed (about 10M elements)
        if totalElems <= maxElemsPerCall
            data = netcdf.getVar(srcid, srcVarID);
            netcdf.putVar(dstid, dstVarID, data);
        else
            % Chunk along the fastest-varying dimension (last one returned by inqVar)
            % Build start/count arrays and loop
            chunkSize = floor(maxElemsPerCall / max(1, prod(dimlens(1:end-1))));
            if chunkSize < 1
                chunkSize = 1;
            end
            dimOrder = numel(dimlens);
            lastDimLen = dimlens(end);
            start = zeros(1, dimOrder);
            count = dimlens;
            for s = 0:chunkSize:lastDimLen-1
                count(end) = min(chunkSize, lastDimLen - s);
                start(end) = s;
                data = netcdf.getVar(srcid, srcVarID, start, count);
                netcdf.putVar(dstid, dstVarID, start, count, data);
            end
        end
    end

    % Close destination and source
    netcdf.close(dstid);
    netcdf.close(srcid);

catch ME
    % Attempt to close open files on error
    try, netcdf.close(dstid); end %#ok<TRYNC>
    try, netcdf.close(srcid); end %#ok<TRYNC>
    rethrow(ME)
end
end
