function [arcNames, rawNames, reverseMap] = getVarsAndRawNames(Ptable, groupList, Ttable)

% Ensure strings
groupList = string(groupList);

% Validate groups exist
Vnames = string(Ptable.Properties.VariableNames);
missing = setdiff(groupList, Vnames);

if ~isempty(missing)
    sprintf("Missing functional groups: %s", strjoin(missing,", "))
    arcNames = strings(0,1);
    rawNames = strings(0,1);
    reverseMap = strings(0,1);
    return
end

% ---- 1. Determine which outputfs are required ----
arcAll = string(Ptable.arcname);
groupMatrix = logical(Ptable{:,groupList});
selectedRows = any(groupMatrix,2);
arcNames = unique(arcAll(selectedRows));

% ---- 2. Determine required raw measurements ----
rows = ismember(string(Ttable.arcname), arcNames);
rawNames = unique(string(Ttable.rawname(rows)));

% ---- 3. Build reverse map ----

reverseMap = struct();
for i = 1:numel(arcNames)
    v = arcNames(i);
    idx = strcmp(string(Ttable.arcname),v);
    reverseMap.(matlab.lang.makeValidName(v)) = unique(string(Ttable.group(idx)));
end

end