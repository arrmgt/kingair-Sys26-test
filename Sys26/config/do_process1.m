function X=do_process1(X)

ZZZ = datetime('now');

sprintf('Begin processing all:')

orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

% Run the get_var*scripts
gets = X.get_vars;
for ii=1:numel(gets)
    try
        eval(gets{ii});
    catch ME
        sprintf('Problem with running %s %s\n %s',gets{ii},X.PROJ,ME.message)
        error(ME.identifier)
    end
end

ZZZ1 = datetime('now');
do_process1_procSeconds=seconds(ZZZ1-ZZZ);
sprintf('End processing all: %.1f minutes', do_process1_procSeconds./60)
