function [Ptable, Ttable, keepGroups, gets] = isThereData(rawFile, dbFile, rawGROUPS, Ptable, Ttable)
%
%  1. Checks availability of specific processsing groups
%  2. Substitutes probe suffix templates for actual raw-data suffixes
%       in processing tables and database
%  3. Updates achive names 
%

info = ncinfo(rawFile);
rawNames0 = string({info.Variables.Name});
fieldNamesP = fieldnames(Ptable);
fieldNamesT = fieldnames(Ttable);

keepGroups = string;
gets = string;

% Connect to sqlite database
conn = sqlite(dbFile,'connect');

% Probe suffix configuration
    S = probeConfig();

% Keep only groups in rawGROUPS
keep = rawGROUPS;   % cell array of names
%      
vars = Ptable.Properties.VariableNames;
keepExisting = keep(ismember(keep, vars));
varsToKeep = ['arcname', keepExisting];
% remove columns not in varsToKeep
Ptable(:, ~ismember(vars, varsToKeep)) = [];

% Keep only rows whose group value is in keep
Ttable = Ttable( ismember(Ttable.group, keep), : );

for ii = 1:numel(rawGROUPS)
    GROUP = string(rawGROUPS(ii));
    % RAW variable templates for this group
    [arcNames, rawNames] = getVarsAndRawNames(Ptable, GROUP, Ttable);
    
    % get the raw suffix if it exists
    fn = char(GROUP);
    clear rawSuffix
    suffixGroup = false;
    if isfield(S, fn) && isfield(S.(fn), "rawSuffix")
        suffixGroup = true;
        rawTemplate = S.(fn).templateSuffix;
        outRate = S.(fn).outRate;
        rawSuffix = S.(fn).rawSuffix;    % e.g. returns string scalar "NRB"
        rawNames2 = extractBefore2_(rawNames',"_");
        rawNames2 = rawNames2 + "_" + rawSuffix;
    else
	    suffixGroup = false;
        rawNames2 = rawNames;
    end
        
    jdx = matches(rawNames0,rawNames2);
    fprintf('isThereData\? Trying group %s ... ',GROUP)
    if any(jdx)
        rawNamesX = extractBefore2_(rawNames0(jdx),'_');
        idx = contains(Ttable.rawname, rawNamesX);
        fprintf("OK\n");
        keepGroups(end+1) = GROUP;
        gets(end+1) = sprintf("get_var%s(X)",GROUP);
       
        % And also update the tables and database
        if suffixGroup
            fprintf("Updating suffixes for %s = %s  ... ",GROUP,suffixGroup);
            % Update to actual suffix label
            Ttable.rawname(idx) = ...
                replace(Ttable.rawname(idx), rawTemplate, rawSuffix);
    
            % Update archive variable labels
            Ttable.arcname(idx) = ...
                replace(Ttable.arcname(idx), rawTemplate, rawSuffix);

            % Rebuild pivot table
            Ptable = rebuildPivot(Ttable);
            
            %------------------------------------
            % determine output rate
            % ------------------
            k = find(jdx);
            rate = get_irate(rawFile,rawNames0{k(1)}); % Assumes all the same
        
            % -------------------------------------------------
            % update database OutputRate and suffix 
            % -------------------------------------------------
            sql = sprintf( ...
                "UPDATE variables SET value='%d' WHERE attribute='OutputRate' AND value='%s'", ...
                rate, outRate);
            exec(conn,sql);

            % Replace "name" template to real suffix in database
            oldSuffix = char(["_" + rawTemplate]);
            newSuffix = char(["_" + rawSuffix]);
            tablename = 'variables';
            replaceSuffix(conn, tablename, oldSuffix, newSuffix)
            fprintf('SUCCESS\n')
        end
    else
        fprintf("Eliminated\n");
        mask = ismember(Ttable.group,GROUP);
        Ttable(mask,:) = [];
    end
end

% Rebuild pivot table
Ptable = rebuildPivot(Ttable);
gets(gets == "") = [];

keepGroups(keepGroups == "") = [];

close(conn)
end

function replaceSuffix(conn, tableName, oldSuffix, newSuffix)
%
% Edit variable database with raw variable suffix values

% get column names from sqlite_master
q = sprintf("SELECT name FROM pragma_table_info('%s')", tableName);
cols = fetch(conn,q);

colNames = string(cols.name);

for k = 1:numel(colNames)

    col = colNames(k);

    sql = sprintf([ ...
        'UPDATE "%s" SET "%s" = REPLACE("%s","%s","%s") ' ...
        'WHERE "%s" LIKE "%%%s%%";'], ...
        tableName, col, col, oldSuffix, newSuffix, col, oldSuffix);

    exec(conn, sql);

end

end