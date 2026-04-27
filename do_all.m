function do_all();
close all
profile off
osType = lower(computer("arch"));
if contains(osType,'win64')
    Source='c:/Users/rodi/Github/kingair-Sys26-test/';
else
    Source = '/home/rodi/kingair-Sys26-test/';
end
%%%%%
outp = fullfile(Source,'output.txt');
delete(outp);
diary(outp);

RUNS =  [ ...
"X=do_batch26('20160830a_raw.nc','PROJ','radfire16','BaseOut','20160830a_arr','Rate',XX)"
"X=do_batch26('20200918_raw.nc','PROJ','flux20','BaseOut','2200918_arr','Rate',XX)" 
"X=do_batch26('20150630_raw.nc','PROJ','pecan15','BaseOut','20150630_arr','Rate',XX)" 
"X=do_batch26('20171116c_raw.nc','PROJ','searmar17','BaseOut','20171116c_arr','Rate',XX)" 
"X=do_batch26('20180802_raw.nc','PROJ','bbflux18','BaseOut','20180802_arr','Rate',XX)"  
"X=do_batch26('20220412a_raw.nc','PROJ','chacha22','BaseOut','20220412a_arr','Rate',XX)"  
"X=do_batch26('20190820b_raw.nc','PROJ','cheesehead19','BaseOut','20190820b_arr','Rate',XX)"  
"X=do_batch26('20130517_raw.nc','PROJ','copemed13','BaseOut','20130517_arr','Rate',XX)"  
"X=do_batch26('20200917_raw.nc','PROJ','dilbert20','BaseOut','20200917_raw_arr','Rate',XX)"  
"X=do_batch26('20210313_raw.nc','PROJ','dilbert21','BaseOut','20210313_arr','Rate',XX)"  
"X=do_batch26('20170304_raw.nc','PROJ','snowie17','BaseOut','20170304_arr','Rate',XX)"  
"X=do_batch26('20210723_raw.nc','PROJ','trans2am21','BaseOut','20210723_arr','Rate',XX)"  
"X=do_batch26('20220821_raw.nc','PROJ','trans2am22','BaseOut','20220821_arr','Rate',XX)"  
];

projRoot = pwd;
RATE = "25"
RUNS = strrep(RUNS,"XX",RATE);

fname = fullfile(Source,'do_batch_runs.txt');
delete fname
for ii=1:numel(RUNS)
    TTT0 = datetime('now');
    tok = regexp(RUNS(ii), '''PROJ'',''([^'']+)''', 'tokens', 'once');  % one token
    PROJ = '';
    if ~isempty(tok)
        PROJ = tok{1};   % 'flux20'
    end
    try
        cd(fullfile(Source,PROJ,'xlsfiles'));
        make_database('variablesXX-1.txt')
        cd(fullfile(Source,PROJ));
        cleanup;
        RUNS(ii)
        eval(RUNS(ii));
        fileID = fopen(fname, 'A');
        fprintf(fileID,'%s\n',RUNS(ii));
        fclose(fileID);
        cleanup;
    catch ME
        sprintf("PROJ %s",PROJ)
    end
end
TTT1=datetime('now');
cd(Source);
sprintf(" Do_all.m: elapsed time %0.1f minutes",round(minutes(TTT1-TTT0)))
diary off

