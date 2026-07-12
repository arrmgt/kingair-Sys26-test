function [unused, allFiles] = unused_mfiles(root, entryPoints)
% UNUSED_MFILES  Find candidate unused .m files in a repo
%   [unused, allFiles] = unused_mfiles(root)
%   [unused, allFiles] = unused_mfiles(root, entryPoints)
%
%   root         - folder to search (default: pwd)
%   entryPoints  - cellstr or string array of entry point file paths (optional).
%                  If omitted, the function looks for common entry files:
%                  main.m, runTests.m, startup.m in root.
%
%   Returns:
%     unused    - string array of candidate unused .m files
%     allFiles  - string array of all .m files found (recursive)

if nargin < 1 || isempty(root)
    root = pwd;
end
root = char(root);

if nargin < 2
    % Default entry points: common names in repo root
    candidates = {'main.m','runAllTests.m','runTests.m','startup.m'};
    entryPoints = {};
    for k = 1:numel(candidates)
        p = fullfile(root, candidates{k});
        if isfile(p)
            entryPoints{end+1} = p; %#ok<AGROW>
        end
    end
else
    entryPoints = cellstr(entryPoints);
end

% Find all .m files recursively
d = dir(fullfile(root, '**', '*.m'));   % struct array
% Build full paths safely
folders = {d.folder}';
names   = {d.name}';
allFiles = string(fullfile(folders, names));

% Collect required files from entry points
required = string.empty;
for k = 1:numel(entryPoints)
    ep = entryPoints{k};
    if ~isfile(ep)
        warning('Entry point not found: %s', ep);
        continue;
    end
    try
        req = matlab.codetools.requiredFilesAndProducts(ep);
        required = [required; string(req(:))]; %#ok<AGROW>
    catch ME
        warning('Could not get dependencies for %s: %s', ep, ME.message);
    end
end
required = unique(required);

% Determine candidates not referenced
unused = setdiff(unique(allFiles), required);

% Optionally filter out common folders that are not project code (adjust patterns as needed)
ignorePatterns = ["\+","/private/","\private/","/tests/","\tests/","/thirdparty/","/vendor/"];
mask = false(size(unused));
for p = ignorePatterns
    mask = mask | contains(unused, p);
end
unused = unused(~mask);

end
