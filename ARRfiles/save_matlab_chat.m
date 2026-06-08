s = clipboard("paste");            % get clipboard text (char)
writelines(string(s), "chat.txt"); % saves as UTF-8 text (R2022a+)
% OR for older releases:
fid = fopen("../chat.txt","w","n","UTF-8");
fprintf(fid, "%s", s);
fclose(fid);