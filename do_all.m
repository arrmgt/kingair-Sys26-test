function do_all(varargin)
profile off
p = inputParser; % Defaults are shown if not set in commmand line
addParameter(p, "PROJ", "test26", @(s)ischar(s)||isstring(s));
addParameter(p, "baseName", "arr", @(s)ischar(s)||isstring(s));
if ispc
    addParameter(p, "Repo", "c:/users/alfre/Github/kingair-Sys26-test", @(s)ischar(s)||isstring(s));
else
    addParameter(p, "Repo", "/home/rodi/kingair-Sys26-test", @(s)ischar(s)||isstring(s));
end
addParameter(p, "RATE", 10, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.parse(varargin{:});
RATE        = num2str(p.Results.RATE);
osType      = lower(computer("arch"));
baseName    = p.Results.baseName;
PROJ        = p.Results.PROJ;
REPO        = p.Results.Repo;
%%%%%

cd(fullfile(REPO,PROJ))
RUNS =  [ ...
"X=do_batch26('20260408a_raw.nc','PROJ','ZZ','BaseOut','20260408a_YY','Rate',XX,'Repo','WW')"
"X=do_batch26('20260408b_raw.nc','PROJ','ZZ','BaseOut','20260408b_YY','Rate',XX,'Repo','WW')"
"X=do_batch26('20260624_raw.nc','PROJ','ZZ','BaseOut','20260624_YY','Rate',XX,'Repo','WW')"
"X=do_batch26('20260626_raw.nc','PROJ','ZZ','BaseOut','20260626_YY','Rate',XX,'Repo','WW')"
"X=do_batch26('20260831_raw.nc','PROJ','ZZ','BaseOut','20260831_YY','Rate',XX,'Repo','WW')"
];

projRoot = pwd;
RUNS = strrep(RUNS,"WW",REPO);
RUNS = strrep(RUNS,"XX",RATE);
RUNS = strrep(RUNS,"YY",baseName);
RUNS = strrep(RUNS,"ZZ",PROJ);
fname = fullfile(REPO,'do_batch_runs.txt');
delete fname

TTT0 = datetime('now');
for ii=1:numel(RUNS)
    tok = regexp(RUNS(ii), '''PROJ'',''([^'']+)''', 'tokens', 'once');  % one token
    PROJ = '';
    if ~isempty(tok)
        PROJ = tok{1};   
    end
    try
        xlsdir = fullfile(REPO,PROJ,'xlsfiles')
        cd(xlsdir);
        make_database('variablesXX-1.txt')
        cd(fullfile(REPO,PROJ));
        cleanup;
	'HELLO'
        RUNS(ii)
	    try
            eval(RUNS(ii));
	    catch ME
		    display(getReport(ME,'extended'));
            catchME(ME)
	    end
        cleanup;
    catch ME
	    display(getReport(ME,'extended'));
        catchME(ME)
    end
end