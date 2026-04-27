function sqlite2xlsx(dbFile, xlsFile)
% Convert sqlite db to xlsx file

% Create a connection to the SQLite database
conn = sqlite(dbFile, 'readonly');

% Specify the table you want to export
% Execute a query to get the table names
tableNames = fetch(conn, ...
    'SELECT name FROM sqlite_master WHERE type="table";');
% Convert to cell array of character vectors
tableName = char(cellstr(tableNames.name)); 

% Read data from the table
data = fetch(conn, ['SELECT * FROM ', tableName,';']);

numChars = strlength(data{:,4});
zz = find(numChars<=1);
data{zz, 4}(strcmp(data{zz, 4}, ' ')) = {'NA'};

% Close the database connection
close(conn);

% Write the data to a CSV file
writetable(data, xlsFile);

disp(['Data exported to ', xlsFile]);
