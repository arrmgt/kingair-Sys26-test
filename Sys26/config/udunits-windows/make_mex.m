% Unload and replace old MEX cleanly
clear mex_udunits2
clear functions
pause(0.5)

% Rename old file to release Windows file lock
if exist('mex_udunits2.mexw64', 'file')
    movefile('mex_udunits2.mexw64', 'mex_udunits2_old.mexw64');
end

mex -v mex_udunits2.c ...
    -I"udunits-2.2.28\lib" ...
    -I"expat-install\include" ...
    -L"udunits2-build\lib" -ludunits2 ...
    -L"expat-install\lib" -lexpat

% Clean up old file after successful build
if exist('mex_udunits2_old.mexw64', 'file')
    delete('mex_udunits2_old.mexw64');
end