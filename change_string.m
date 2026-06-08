rootDir="c:/Users/rodi/GitHub/kingair-Sys26-work/";

string1="decimate1";
string2="changeRate";

% Call the function with the desired directory path
x=dir(fullfile(rootDir,'**/*'));
names={x.name};
%eliminate change_string.m
names=names(find(~contains(names,'change_string.m')));
folders={x.folder};
[xpath,xname,xext]=fileparts(names);
% Eliminate .git* folders and empty files
ii=~contains(xext,'.git') &  ~cellfun(@isempty,xext);
names=names(find(ii));
folders=folders(find(ii));

for i=1:numel(names);
    file=fullfile(folders{i},names{i});
    replaceStringInFile(file,string1,string2);
end

function replaceStringInFile(filePath, string1, string2)
    % Open the file, read its content, replace string1 with string2, and save it back
    try
        % Read the file content as text
        fileID = fopen(filePath, 'r');
        if fileID == -1
            fprintf('Could not open file %s for reading.\n', filePath);
            return;
        end
        
        fileContent = fread(fileID, '*char')';
        fclose(fileID);

        % Replace occurrences of string1 with string2
        updatedContent = strrep(fileContent, string1, string2);

        % Write the updated content back to the file
        fileID = fopen(filePath, 'w');
        if fileID == -1
            fprintf('Could not open file %s for writing.\n', filePath);
            return;
        end

        fwrite(fileID, updatedContent);
        fclose(fileID);
        fprintf('Updated file: %s\n', filePath);
    catch ME
        fprintf('Error updating file %s: %s\n', filePath, ME.message);
    end
end

function isText = isTextFile(filePath)
    % Check if the file is a *.m file based on its extension
    [~, ~, ext] = fileparts(filePath);
    textExtensions = {'.m'};
    isText = any(strcmpi(ext, textExtensions));
end