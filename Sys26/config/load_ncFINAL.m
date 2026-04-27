function load_ncFINAL(ncFINAL, matfile)
%LOAD_NCFINAL  Write processed MAT variables into NetCDF using
%              dimension information from the NetCDF schema itself.
%
%   Dimension Handles  
%       time = time dimension; 
%       nps = samples/sec; 
%       ncell = cells;
%   Working variables prior to being loaded
%      - 1-Hz variables:      [time]
%      - High-rate variables: [time x nps]
%      - Cell/spectral vars:  [time x nps × ncell]
%   When loaded into output netcdf file, dimensions are changed here to
%      - 1-Hz variables:      [time]
%      - High-rate variables: [nps x time]
%      - Cell/spectral vars:  [cell x nps x time]

%% ------------------------------------------------------------------------
% Load metadata from MAT file
%% ------------------------------------------------------------------------
S      = load(matfile, 'Time', 'arcNames');
ntime  = numel(S.Time);
% Convert arcNames to char
arcNames = S.arcNames(~cellfun('isempty', S.arcNames));
arcNames = cellfun(@char,   arcNames, 'UniformOutput', false);
arcNames = cellfun(@strtrim, arcNames, 'UniformOutput', false);

%% ------------------------------------------------------------------------
% Load NC schema
%% ------------------------------------------------------------------------
% Close netcdf ncid on exit
cleanupObj = onCleanup(@() safeClose(ncid));

info   = ncinfo(ncFINAL);
NAMES  = {info.Variables.Name};

% Keep only names that exist in the NetCDF file
arcNames = intersect(arcNames, NAMES, 'stable');

%% ------------------------------------------------------------------------
% Loop over variables
%% -------------------------wh-----------------------------------------------
fclose('all')
ncid = netcdf.open(ncFINAL,'NC_WRITE');
for ii = 1:numel(arcNames)
    name = arcNames{ii};
    % Locate matching NC variable
    idx = find(strcmp(NAMES, name), 1);
    if isempty(idx)
        fprintf('(skipped — not in NC)\n');
        continue;
    end

    vinfo = info.Variables(idx);
    dimStruct = vinfo.Dimensions;
    nd = numel(dimStruct);

    % Load variable from MAT
    M = load(matfile, name);
    A = M.(name);  % Extract from matfile
    
    %  Cull inf or nan or single>max(int16)
    if(matches(class(A),'single'))
        kk = find(~isinf(A) & ~isnan(A) & A<=intmax('int16'));
    elseif(matches(class(A),'double') | matches(class(A),'int32'))
        kk = find(~isinf(A) & ~isnan(A) & abs(A)< 10^12);
    end

    if(numel(kk) < numel(A))
        A = interp1(kk, A(kk), [1:numel(A)]','linear',0);
    end
                
    switch nd  % number of dimensions
        case 1
            % 1-D variables: (time)
            A_nc = A(:);
        case 2
            nch = dimStruct(1).Length;
            nt = dimStruct(2).Length;
            % 2-D variables: (time, sps)
            assert(numel(A) == nch*nt);
            A_nc = reshape(A,nch,nt);
        case 3
            vec = dimStruct(1).Length;
            nch = dimStruct(2).Length;
            nt = dimStruct(3).Length;
            % 3-D variables: (time, sps, vec)
            % A is [nt*nch, vec]
            assert(numel(A) == vec*nch*nt);
            A_nc = reshape(permute(A,[2 1]),[vec,nch,nt]);
        otherwise
            error('Unsupported nd=%d', nd);
    end
    
    fprintf('Writing %s ... ', name);
    varid = netcdf.inqVarID(ncid,name);

    try
        netcdf.putVar(ncid, varid,A_nc);  % write the variable
        % pause(1); % not sure why this seems to be needed
    catch ME
        error("load_ncFINAL: error writing %s to %s",name,matfile)
    end
    %ncwrite(ncFINAL, name, A_nc);
    fprintf("OK\n");
end
netcdf.close(ncid);
sprintf('load_ncFINAL: Finished loading matfile %s',matfile)

end
