% This is now to convert database file to txt file for editing
conn = sqlite('variablesXX.db');
data_table = sqlread(conn,'variables');
writetable(data_table,'blurf.csv');% temporary file
TXT=readtable('blurf.xlsx');

% To convert txt file back to database
opts = detectImportOptions('your_file.txt'); % Detect import options
opts.VariableNames = {'Column1Name', 'Column2Name', 'Column3Name'}; % Assign custom names
T = readtable('your_file.txt', opts); % Read with specified options