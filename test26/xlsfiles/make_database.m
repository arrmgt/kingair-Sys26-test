function make_database(textFile)
% make_database('variablesXX-1.txt');
%
% Converts the aircraft variable text file to a sqlite database
% textFile    Text file name (e.g. variablesXX-1.txt)
% 

% configDir is where to put the zip file of tables
%%% 

dbFile = 'variablesXX.db'; % Created db file (e.g. variablesXX.db)
tableName = 'variables'; % Table name (e.g. 'variables');
configDir = pwd; % Set the configuration directory for file paths

%% Parse file into a table T (multiple variable blocks supported)
txt = fileread(fullfile(configDir,textFile));
lines = regexp(txt, '\r?\n', 'split');

name = {};
type = {};
attribute = {};
value = {};

curType = '';
curName = '';

for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line) || startsWith(line, '%')
        continue
    end

    % Variable definition, e.g., "Float aias;"
    defMatch = regexp(line, '(\w+)\s+(\w+);', 'tokens', 'once');
    if ~isempty(defMatch)
        curType = defMatch{1};
        curName = defMatch{2};
        continue
    end

    % Attribute lines: quoted first, then unquoted
    attrMatch = regexp(line, '(\w+):(\w+)\s*=\s*"(.*?)"\s*;', 'tokens', 'once');
    if isempty(attrMatch)
        attrMatch = regexp(line, '(\w+):(\w+)\s*=\s*(.*?)\s*;', 'tokens', 'once');
    end
    if ~isempty(attrMatch)
        nm  = attrMatch{1};
        att = attrMatch{2};
        val = strtrim(attrMatch{3});
        if startsWith(val,'"') && endsWith(val,'"')
            val = val(2:end-1);
        end
        name{end+1,1}      = nm;
        type{end+1,1}      = curType;
        attribute{end+1,1} = att;
        value{end+1,1}     = val;
    end
end

T = table(string(name), string(type), string(attribute), string(value), ...
          'VariableNames', {'name','type','attribute','value'});

%% === Write to SQLite ===

% Helper: create table DDL as TEXT columns (you can tweak types later)
createSQL = sprintf([ ...
    'CREATE TABLE IF NOT EXISTS %s (', ...
    'name TEXT NOT NULL, ', ...
    'type TEXT NOT NULL, ', ...
    'attribute TEXT NOT NULL, ', ...
    'value TEXT);' ...
], tableName);

% Try Database Toolbox path first
hasDBToolbox = license('test','Database_Toolbox');

dbFile=fullfile(configDir,dbFile);
if hasDBToolbox
    if(exist(dbFile,'file'))
        delete(dbFile)
    end
    try
        conn = sqlite(dbFile, 'create');              % Database Toolbox/SQLite interface
        exec(conn, createSQL);                        % Ensure table exists
        % sqlwrite will create the table if needed, but we pre-create to fix column order/types
        sqlwrite(conn, tableName, T);                 % Append rows
        close(conn); 
        fprintf('Wrote %d rows to SQLite: %s (table: %s)\n', height(T), dbFile, tableName);
    catch ME
        warning('Database Toolbox path failed: %s', ME.message);
        hasDBToolbox = false; % fall through to system sqlite3
    end
end

% Fallback: generate .sql and invoke system sqlite3 if available
if ~hasDBToolbox
    % Check for sqlite3 on PATH
    [status,~] = system('sqlite3 -version');
    if status ~= 0
        error(['No Database Toolbox and no system sqlite3 found.', newline, ...
               'Either install Database Toolbox or install sqlite3 CLI and ensure it is on PATH.']);
    end

    % Build an INSERT script (escape single quotes)
    insLines = strings(height(T),1);
    for i = 1:height(T)
        v = T{i, :};
        esc = @(s) strrep(s, '''', '''''');  % SQL escape single quote
        insLines(i) = sprintf( ...
            "INSERT INTO %s (name,type,attribute,value) VALUES ('%s','%s','%s','%s');", ...
            tableName, esc(v.name), esc(v.type), esc(v.attribute), esc(v.value));
    end

    % Write script and run it
    sqlScript = 'load_metadata.sql';
    fid = fopen(sqlScript,'w');
    fprintf(fid, '%s\n', createSQL);
    fprintf(fid, '%s\n', strjoin(cellstr(insLines), newline));
    fclose(fid);

    cmd = sprintf('sqlite3 "%s" ".read %s"', dbFile, sqlScript);
    [status,out] = system(cmd);
    if status ~= 0
        error('sqlite3 failed: %s', out);
    end
    fprintf('Wrote %d rows to SQLite via sqlite3: %s (table: %s)\n', height(T), dbFile, tableName);
end

%% Example: read back with sqlite (if you have DB Toolbox)
% conn = sqlite(dbFile, 'readonly');
% Q = fetch(conn, sprintf('SELECT * FROM %s WHERE name = "aias";', tableName));
% close(conn);

% Remake the tables.tar (PROCESSED-VARS.xlsx,RAW-VARS.xlsx,variablesXX.db
tarName=fullfile(configDir,"tables.tar");
fclose('all');
pause(0.5);
delete(tarName)
names = tar(tarName,{'PROCESSED-VARS.xlsx','RAW-VARS.xlsx','variablesXX.db'});
end