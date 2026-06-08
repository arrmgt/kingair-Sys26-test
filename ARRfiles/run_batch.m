function run_batch(args);

% Submit job: tell batch that do_batch25 returns 1 output
j = batch(@do_batch25, 1, args, ...
    'CurrentFolder', pwd, ...
    'AttachedFiles', {'do_batch25.m'}, ...
    'CaptureDiary', true ...
);

% assume j is your finished job
if ~strcmp(j.State,'finished')
    wait(j);
end

% Confirm state
disp(j.State)    % should show 'finished'

% Write the job diary into output.txt (creates or appends)
diary(j, 'output.txt');

% Check for task errors
if any(~cellfun(@isempty, {j.Tasks.Error}))
    % show first error report
    error(getReport(j.Tasks(find(~cellfun(@isempty,{j.Tasks.Error}),1)).Error,'extended'));
else
    'SUCCESS'
end

% Retrieve outputs: fetchOutputs returns a 1-by-1 cell for one output
data = fetchOutputs(j);
X = data{1};
save('blurf.mat')

% Clean up job data and handle
delete(j);
clear j;
