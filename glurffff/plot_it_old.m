clear NAME ext zz1000 stitle 

RawPath = "P:\MATLAB-DATA2\kingair_data\cheesehead19\work\20190820b_raw.nc";
RawPath = "P:\MATLAB-DATA2\kingair_data\bbflux18\work\20180802_raw.nc"

RawPath = "P:\MATLAB-DATA2\kingair_data\cheesehead19\work\20190820b_raw.nc";
RawPath = "P:\MATLAB-DATA2\kingair_data\test26\work\20260408b_raw.nc"

RawPath = "P:\MATLAB-DATA2\kingair_data\copemed13\work\20130517_raw.nc"
RawPath = "P:\MATLAB-DATA2\kingair_data\test26\work\20260408b_raw.nc"
RawPath = "P:\MATLAB-DATA2\kingair_data\test26\work\20260408a_raw.nc"

[filepath,NAME,ext] = fileparts(RawPath)
info = ncinfo(RawPath);
RAWNAMES = {info.Variables.Name};  
irate=get_irate(RawPath,'DPA');
orate=1000;
clear raw zz1000
if contains(NAME,[ "201808", "201908",  "201305"]) 
    raw.AIAS=gdata(RawPath,'AIAS'); %DPR = change_rate(blurf,1000,orate);
elseif contains(NAME,['20260408a' '20260408b'])
    raw.PSA=gdata(RawPath,'PSA'); %PSA = change_rate(blurf,1000,orate);
    raw.PSB=gdata(RawPath,'PSB'); %PSB = change_rate(blurf,1000,orate);
    raw.DP1=gdata(RawPath,'DP1'); %DP1 = change_rate(blurf,1000,orate);
    raw.DP2=gdata(RawPath,'DP2'); %DP2 = change_rate(blurf,1000,orate);
    raw.DPN=gdata(RawPath,'DPN'); %DPN = change_rate(blurf,1000,orate);
end
raw.DPA=gdata(RawPath,'DPA'); %DPB = change_rate(blurf,1000,orate);
raw.DPB=gdata(RawPath,'DPB'); %DPB = change_rate(blurf,1000,orate);
raw.DPR=gdata(RawPath,'DPR'); %DPR = change_rate(blurf,1000,orate);
raw.TROSE=gdata(RawPath,'TROSE'); %TROSE = change_rate(blurf,1000,orate)+273.15;
if mean(raw.DPA)<0
    raw.DPA = - raw.DPA;
end
if contains(NAME,'20260408a')
    zz1000=1.04e7:1.14e7;
    stitle = sprintf("TEST26: %s%s 1000 Hz",NAME,ext);
elseif contains(NAME,'20260408b')
    zz1000=5.8e6:7.4e6;
    stitle = sprintf("TEST26: %s%s  1000 Hz",NAME,ext); 
elseif contains(NAME,'201808')
    zz1000=0.9e7:1.15e7;
    stitle = sprintf("BBFLUX18: %s%s  1000 Hz",NAME,ext);
elseif contains(NAME,'20190820b')
    zz1000=4e6:6e6;
    stitle = sprintf("CHEESEHEAD19: %s%s  1000 Hz",NAME,ext);
elseif contains(NAME,'201305')
    zz1000=1e6:1.6e6;
    stitle = sprintf("COPEMED13: %s%s  1000 Hz",NAME,ext);
end

if(isempty(zz1000)); 'zz1000 is empty';return,end

stitle = strrep(stitle,'_','\_');

fs = 1000;
fout = 25;
fc         = fout / 2;        % passband edge AT output Nyquist
transWidth = fout / 2;        % transition band: fout/2 --> fout
Ap         = 0.01;
Ast        = 40;              % filtfilt doubles -> ~80 dB effective
 
b = kaiser_lp(fs, fc, transWidth, Ap, Ast);
a = 1;

M = [2^13,2^14,1/1000];
close all
nn=0;
nn=nn+1;
figure(nn)
kk = zz1000(1:4000);
var = 'DPA';
plot([1:numel(kk)]/1000,raw.(var)(kk),'.')
title(stitle,"fontsize",15,'FontWeight','bold');
xlabel('Time [sec]',"fontsize",15,'FontWeight','bold');
ylabel(sprintf("%s",var),"fontsize",15,'FontWeight','bold');
ss=sprintf('figs/%s-%s-tseries.jpg',NAME,var);
grid
exportgraphics(gcf,ss)

nn=nn+1;
figure(nn)
kk = zz1000(1:4000);
var = 'TROSE';
plot([1:numel(kk)]/1000,raw.(var)(kk),'.')
title(stitle,"fontsize",15,'FontWeight','bold');
xlabel('Time [sec]',"fontsize",15,'FontWeight','bold');
ylabel(sprintf("%s",var),"fontsize",15,'FontWeight','bold');
ss=sprintf('figs/%s-%s-tseries.jpg',NAME,var);
grid
exportgraphics(gcf,ss)

nn=nn+1;
figure(nn)
var='DPA';
x0 = raw.(var);
x = x0(zz1000);
xf = filtfilt(b,a,x);
[pp,ff]=spec(x,xf,M);
loglog(ff,pp(:,1),ff,pp(:,2)),
legend("Raw","Filtered","fontsize",15,'FontWeight','bold');
xlabel('Frequency [Hz]','fontsize',15)
ylabel('PSD variance/freq unit','fontsize',15,'FontWeight','bold');
ss = sprintf("%s%s: %s 1000 Hz ",NAME,ext,var);
ss = strrep(ss,'_','\_');
title(stitle,'fontsize',15,'FontWeight','bold')
grid
v=axis;
v4 = 10^(ceil(log10(max(pp(:,1))))+1);
axis([v(1) v(2) 1e-10 v4])
text(v(1)*2,v4/2,sprintf('VAR = "%s"',var),'fontsize',15,'FontWeight','bold');
ss=sprintf('figs/%s-%s-spect.jpg',NAME,var);
exportgraphics(gcf,ss)

nn=nn+1;
figure(nn)
var='TROSE';
x0 = raw.(var);
x = x0(zz1000);
xf = filtfilt(b,a,x);
[pp,ff]=spec(x,xf,M);
loglog(ff,pp(:,1),ff,pp(:,2)),
legend("Raw","Filtered","fontsize",15,'FontWeight','bold');
xlabel('Frequency [Hz]','fontsize',15)
ylabel('PSD variance/freq unit','fontsize',15,'FontWeight','bold');
ss = sprintf("%s%s: %s 1000 Hz ",NAME,ext,var);
ss = strrep(ss,'_','\_');
title(stitle,'fontsize',15,'FontWeight','bold')
grid
v=axis;
v4 = 10^(ceil(log10(max(pp(:,1))))+1);
axis([v(1) v(2) 1e-10 v4])
text(v(1)*2,v4/2,sprintf('VAR = "%s"',var),'fontsize',15,'FontWeight','bold');
ss=sprintf('figs/%s-%s-spect.jpg',NAME,var);
exportgraphics(gcf,ss)

return



b=kaiser_lp(1000,12.5,10,.01,80);
a=1;
fields = fieldnames(raw);

nn=0;
figure(nn+1)





TYPES = ["NoTurbSL" "TurbLiteClimb"]

nn=0;
for j=1:numel(TYPES)
    clear TYPE 
    TYPE = TYPES(j);
    if contains(NAME,'20260408a')
        switch TYPE
            case "NoTurbSL"
                zz1000=1.04e7:1.14e7;% high level
                M = [2^12,2^13,1/1000];
            case "TurbLiteClimb"
                zz1000=1.7e6:1.9e6; %climb out
                M =[2^11,2^12,1/1000];
        end
    elseif contains(NAME,'20260408b')
        switch TYPE
            case "NoTurbSL"
                zz1000=5.8e6:7.4e6;% high level
                M = [2^12,2^13,1/1000];
            case "TurbLiteClimb"
                zz1000=0.95e6:1.1e6; %climb oNAut
                M =[(2^12)/11,2^10,1/1000];
        end
    end
    
    for i = 1:numel(fields);
        figure(i+nn)
        x0 = raw.(fields{i});
        x = x0(zz1000);
        xf = filtfilt(b,a,x);
        [pp,ff]=spec(x,xf,M);
        loglog(ff,pp(:,1),ff,pp(:,2)), grid
        PP.(fields{i})=pp;
        FF.(fields{i})=ff;
        legend("Raw","Filtered","fontsize",15,'FontWeight','bold');
        xlabel('Frequency [Hz]','fontsize',15)
        ylabel('PSD variance/freq unit','fontsize',15,'FontWeight','bold');
        ss = sprintf("%s%s: %s 1000 Hz %s",NAME,ext,fields{i},TYPE);
        ss = strrep(ss,'_','\_');
        title(ss,'fontsize',15,'FontWeight','bold')
        v=axis;
        axis([v(1) v(2) 1e-10, 5e-2])
        ss=sprintf('figs/%s-%s-%s.jpg',NAME,fields{i},TYPE);
        exportgraphics(gcf,ss)
    end
    nn=nn+10;
end

return

TDPK = -40*ones(size(TROSE))+273.15;
PMB = PSA;
pcorc=0;
qq = solve858(DP1,DPA,DPB,'dpr',DPR);
Atrose = airdata(PMB-pcorc,PMB-pcorc+qq,TROSE,0.97,TDPK);
trose = Atrose.Ts;


[pp,ff]=spec(DPA(zz50),DPB(zz50),[256,1024,1/orate]);
loglog(ff,pp(:,1),ff,pp(:,2))
xlabel('Frequency [Hz]','fontsize',15)
ylabel('PSD variance/freq unit','fontsize',15,'FontWeight','bold');
title('cheesehead: 20190820b (50Hz)','fontsize',10,'FontWeight','bold');
grid
v=axis;
axis([v(1) v(2) 5e-7 5e-3])
legend('TRF','TROSE','fontsize',15,'FontWeight','bold')
exportgraphics(gcf, 'trf-trose.png', 'Resolution', 300);

