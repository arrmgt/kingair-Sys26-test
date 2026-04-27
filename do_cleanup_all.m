function do_all();

osType = lower(computer("arch"));
if contains(osType,'win64')
    Source='c:/Users/rodi/Github/kingair-Sys26/';
else
    Source = '/home/rodi/kingair-Sys26/';
end
%%%%%
outp = fullfile(Source,'output.txt');
delete(outp);
diary(outp);

projs_out={'20150630_arr','20171116c_arr','20180802_arr','20220412a_arr','20190820b_arr','20130517_arr' ...
    '20200917_raw_arr','20210313_arr','20170304_arr','20210723_arr','20220821_arr'};
rawnames={'20150630_raw.nc','20171116c_raw.nc','20180802_raw.nc','20220412a_raw.nc','20190820b_raw.nc','20130517_raw.nc' ...
    '20200917_raw.nc','20210313_raw.nc','20170304_raw.nc','20210723_raw.nc','20220821_raw.nc'};
projs={'pecan15','searmar17','bbflux18','chacha22','cheesehead19','copemed13','dilbert20','dilbert21','snowie17','trans2am21','trans2am22'};
TT0=datetime('now');

for ii=1:numel(projs)
    proj=char(projs(ii));
    cd(fullfile(Source,proj))
    cleanup
end



TT1=datetime('now');
cd(Source);
sprintf(" Do_cleanup_all.m: elapsed time %0.1f minutes",round(seconds(TT1-TT0)))
% diary off
