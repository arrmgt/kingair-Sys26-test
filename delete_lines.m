function delete_lines(in,tmp,pat)
close all
P = fopen(in,'r');
Q = fopen(tmp,'w');

while ~feof(P)
    t = fgets(P);
    if t == -1, break; end
    if ~contains(t, pat, 'IgnoreCase', true)   
        fprintf(Q, '%s', t);
    end
end

fclose(P);
fclose(Q);
copyfile temp.txt variablesXX-1.txt
