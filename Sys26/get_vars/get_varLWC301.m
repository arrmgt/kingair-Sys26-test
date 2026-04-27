function get_varLWC301(X)

TT=datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS = 'LWC301';
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

% This might be needed
clear ncinfo ncreadatt ncwriteatt

orate=X.procRate;
Rate=num2str(orate);

matfile=fullfile(X.tempdir,sprintf("%s_TAS.mat",X.BaseName));
load(matfile,'PSX','TEMPX','TASX','q_impact','alpha','beta','ias');

Var='LWC301'
[ninterp,ndecim,SampleRate]=get_dims(X.RawPath,Var,orate);
[blurf,irate,nmiss]=getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','watt');
ncwriteatt(X.ncFINAL,'lwc301power','MissingValues',nmiss);
ncwriteatt(X.ncFINAL,'lwc301power','SampleRate',SampleRate);
lwc301power=blurf;

[plwc4,dryp4,twire,coefs,fy4,R2,ci,kk] = ...
get_lwc301(orate,lwc301power,q_impact,TASX,alpha,beta,TEMPX,PSX,ias);
lwc301lwc=plwc4;
ncwriteatt(X.ncFINAL,'lwc301lwc','coefs',coefs);
ncwriteatt(X.ncFINAL,'lwc301lwc','twire',twire);
[mm,nn]=size(ci);
if(mm==2)
    ncwriteatt(X.ncFINAL,'lwc301lwc','R2',R2);
    ncwriteatt(X.ncFINAL,'lwc301lwc','conf_int95_A',ci(1,:));
    ncwriteatt(X.ncFINAL,'lwc301lwc','conf_int95_B',ci(2,:));
    ncwriteatt(X.ncFINAL,'lwc301lwc','method','Clear-air fit');
else
    ncwriteatt(X.ncFINAL,'lwc301lwc','method','Default');
end

Var='LWC301Cal'
[ninterp,ndecim,SampleRate]=get_dims(X.RawPath,Var,orate);
[blurf,irate,nmiss]=getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','gram/m3');
ncwriteatt(X.ncFINAL,'lwc301cal','MissingValues',nmiss);
ncwriteatt(X.ncFINAL,'lwc301cal','SampleRate',SampleRate);
eval(strcat(lower(Var),'=blurf',';'));

Var='LWC301Ave'
[ninterp,ndecim,SampleRate]=get_dims(X.RawPath,Var,orate);
[blurf,irate,nmiss]=getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','gram/m3');
ncwriteatt(X.ncFINAL,'lwc301ave','MissingValues',nmiss);
ncwriteatt(X.ncFINAL,'lwc301ave','SampleRate',SampleRate);
eval(strcat(lower(Var),'=blurf',';'));

ss1="'orate','Rate','Time','arcNames'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        % save name for outputing to matfile later
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii}); 
    end
end
% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_LWC301.mat",X.BaseName));
delete(matfile)
ss=sprintf("save(matfile,%s);",ss1);eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds')
;
;
load_ncFINAL(X.ncFINAL,matfile);

sprintf('Processed get_varLWC301.m for Project: %s',X.PROJ)