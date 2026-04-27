function Ptable = rebuildPivot(Ttable)

groups = unique(Ttable.group);
arcList = unique(Ttable.arcname);

M = false(numel(arcList),numel(groups));

for k = 1:height(Ttable)
    r = find(arcList == Ttable.arcname(k));
    c = find(groups  == Ttable.group(k));
    M(r,c) = true;
end

Ptable = array2table(M,'VariableNames',cellstr(groups));
Ptable.arcname = arcList;
Ptable = movevars(Ptable,'arcname','Before',1);

end