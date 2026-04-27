% Save workspace or important state
save('matlab_restart_backup.mat');

% Build command
matlabExe = fullfile(matlabroot,'bin','matlab'); % on Windows this is matlab.exe
startupCmd = 'disp(''Restarted'');';            % command to run in new session (escape quotes)
cmd = sprintf('"%s" -r "%s" &', matlabExe, startupCmd);

% Launch new MATLAB process (use system for Linux/macOS; on Windows the & still works in background)
if ispc
    system(cmd);   % launches background process on Windows
else
    system([cmd ' >/dev/null 2>&1 &']); % detach on Unix
end

% Exit this MATLAB session
exit