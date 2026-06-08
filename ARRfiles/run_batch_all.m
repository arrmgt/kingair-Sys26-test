function run_batch_all
delete output.txt
j = batch(@do_all, 1, ...
    'CurrentFolder', pwd, ...
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
