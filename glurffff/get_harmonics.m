% Parameters
RPM = 1700; blades = 5; fs_old = 1000; fs_new = 25;
rev_s = RPM/60;
f0 = blades*rev_s;
M = 5;                              % number of harmonics to check
k = (1:M).';
f_phys = k * f0;