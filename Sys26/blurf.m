files = dir('c:/users/rodi/Github/kingair-Sys26/**/do_batch25.m');

names={files.name};
folders={files.folder}
ii = find(contains({files.name},'do_batch25.m'))

for j=ii
    name0 = string(fullfile(folders(j),names(j)))
    name1 = string(fullfile(folders(j),'do_batch26.m'))
    movefile(name0,name1);
end
