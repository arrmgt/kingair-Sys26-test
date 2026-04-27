args = {'20220821_raw.nc','PROJ','trans2am22','BaseOut','20220821_arr','Rate',25};

% Submit job: tell batch that do_batch25 returns 1 output
j = batch(@do_batch25, 1, args, ...
    'CurrentFolder', pwd, ...
    'AttachedFiles', {'do_batch25.m'} ...
);

% Wait until finished (or poll j.State)
wait(j);

% Check for task errors
if any(~cellfun(@isempty, {job.Tasks.Error}))
    % show first error report
    error(getReport(job.Tasks(find(~cellfun(@isempty,{job.Tasks.Error}),1)).Error,'extended'));
else
    'SUCCESS'
end

% Retrieve outputs: fetchOutputs returns a 1-by-1 cell for one output
data = fetchOutputs(j);
X = data{1};

% Optional: view worker output
%diary(j);

% Clean up job data and handle
%delete(j);
%clear j;
