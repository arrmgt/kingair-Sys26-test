function get_varLWC100(X)

TT=datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS = 'LWC100';
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

orate=X.procRate;
Rate=num2str(orate);

C=phycon;

matfile=fullfile(X.tempdir,sprintf("%s_TAS.mat",X.BaseName));
load(matfile,'PSX','TEMPX','TASX','q_impact','alpha','beta','q_impact');

Var='LWC100';
[ninterp,ndecim,SampleRate]=get_dims(X.RawPath,Var,orate);
[blurf,nmiss]=getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','watt');
ncwriteatt(X.ncFINAL,'lwc100','MissingValues',nmiss);
ncwriteatt(X.ncFINAL,'lwc100','SampleRate',SampleRate);
lwc100power=blurf;

[plwc4,dryp4,twire,y4,fy4,R2,ci,kk] = ...
get_lwc301(orate,lwc100power,q_impact,TASX,alpha,beta,TEMPX,PSX,q_impact);
lwc100=plwc4;
D=0.0019;
L=0.0200;
area=L*D;
twire=150+C.Tzero;
ncwriteatt(X.ncFINAL,'lwc100','twire [C]',twire-C.Tzero);
[fy4,y4,dryp4,xfact1,xfact2,xfact3]=nu_re_fit0(y4,D,L,lwc100power,TEMPX,twire,TASX,PSX,beta);

if(~isempty(kk))
ncwriteatt(X.ncFINAL,'lwc100','Method','Calculated clear air fit');
ncwriteatt(X.ncFINAL,'lwc100','Clear Air Time [hr]',numel(kk)./X.procRate./3600);
ncwriteatt(X.ncFINAL,'lwc100','Coefficients',y4);
ncwriteatt(X.ncFINAL,'lwc100','R2',R2);
ncwriteatt(X.ncFINAL,'lwc100','conf_int95_A',ci(1,:));
ncwriteatt(X.ncFINAL,'lwc100','conf_int95_B',ci(2,:));
else
ncwriteatt(X.ncFINAL,'lwc100','Method','Default Coefficients used');
ncwriteatt(X.ncFINAL,'lwc100','Coefficients',y4);
end

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

sprintf('Processed get_varLWC100.m for Project: %s',X.PROJ)

end