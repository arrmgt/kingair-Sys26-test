function [Pxlsx,Ptable,Txlsx,Ttable,rawnames] = build_groups(X)
%
% Configure processing list based on measurements recorded in *_raw.nc
%
%% ------------------------------------------------------------------------
% 1. Configuration information
% -------------------------------------------------------------------------

xlsraw = X.xlsraw; % Raw measurement groups
xlsarc = X.xlsarc; % Output variables for groups

%% ------------------------------------------------------------------------
% 2. Read spreadsheets
% -------------------------------------------------------------------------

TrawOriginal = readtable(xlsraw);
TarcOriginal = readtable(xlsarc);

%% ------------------------------------------------------------------------
% 3. Stack RAW spreadsheet (long format)
% --------------------------------------TarcOriginal = readtable(xlsarc, Range='A1:U50');-----------------------------------

TrawLong = stack(TrawOriginal, ...
    TrawOriginal.Properties.VariableNames, ...
    'NewDataVariableName','rawname_template', ...
    'IndexVariableName','group');

TrawLong.rawname_template = string(TrawLong.rawname_template);
TrawLong.group = string(TrawLong.group);

% Remove empty entries safely
TrawLong = TrawLong(strlength(strtrim(TrawLong.rawname_template)) > 0, :);

%% ------------------------------------------------------------------------
% 4. Stack ARCHIVE spreadsheet (long format)
% -------------------------------------------------------------------------

TarcLong = stack(TarcOriginal, ...
    TarcOriginal.Properties.VariableNames, ...
    'NewDataVariableName','arcname_template', ...
    'IndexVariableName','group');

TarcLong.arcname_template = string(TarcLong.arcname_template);
TarcLong.group = string(TarcLong.group);

TarcLong = TarcLong(strlength(strtrim(TarcLong.arcname_template)) > 0, :);

%% ------------------------------------------------------------------------
% 5. Join on group only
% -------------------------------------------------------------------------

Ttable = innerjoin(TrawLong, TarcLong, 'Keys','group');

%% ------------------------------------------------------------------------
% 6. Apply config-driven suffix replacement
% -------------------------------------------------------------------------

Ttable.rawname = Ttable.rawname_template;
Ttable.arcname = Ttable.arcname_template;

%% ------------------------------------------------------------------------
% 7. Keep only necessary columns
% -------------------------------------------------------------------------

Ttable = Ttable(:, {'group','rawname','arcname'});

%% ------------------------------------------------------------------------
% 8. Build logical pivot table
% -------------------------------------------------------------------------

groupList = unique(string(TrawOriginal.Properties.VariableNames));
arcList = unique(Ttable.arcname);

% remove eddy dissipation rates from winds calculations
%   if processing rate <20
if(X.procRate<20)  
    arcList = arcList(~contains(arcList,["AVedr", "avEDR"]));
end
M = false(numel(arcList), numel(groupList));

for k = 1:height(Ttable)

    r = find(arcList == Ttable.arcname(k));
    c = find(groupList == Ttable.group(k));

    if ~isempty(r) && ~isempty(c)
        M(r,c) = true;
    end
end

Ptable = array2table(M, ...
    'VariableNames', cellstr(groupList));

Ptable.arcname = arcList;
Ptable = movevars(Ptable, 'arcname', 'Before', 1);

%% ------------------------------------------------------------------------
% 9. Export
% -------------------------------------------------------------------------

Pxlsx = 'Ptable.xlsx';
Txlsx = 'Ttable.xlsx';

writetable(Ptable, Pxlsx);
writetable(Ttable, Txlsx);

%% ------------------------------------------------------------------------
% 10. Return rawnames list
% -------------------------------------------------------------------------

rawnames = unique(Ttable.rawname);

end