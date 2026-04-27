function index=cell_find(C,str);
% find str in cell variable C

[ii,jj]=size(C);
if(jj==1)
    C=C';
    [ii,jj]=size(C);
end
i = false(ii,jj);
for k = 1:jj
    %{C{1,k},str}
    i(:,k) = contains(C{1,k},str);
end
index=find(i);

