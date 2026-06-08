function T = alias_old_to_new(fs_old,fs_new,f_phys)
f_phys=f_phys(:);

scale = fs_new / fs_old;
f_scaled = f_phys * scale; % frequencies on new sampling grid
f_mod = mod(f_scaled, fs_new); % reduce to [0, fs_new)
Nyq = fs_new/2;
f_alias = f_mod;
f_alias(f_mod > Nyq) = fs_new - f_mod(f_mod > Nyq); % fold above Nyquist

T = table(f_phys, f_scaled, f_mod, f_alias);
disp(T)