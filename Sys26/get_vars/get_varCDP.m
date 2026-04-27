function get_varCDP(X)

TT=datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

% Load time vector to reference length
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

orate=X.procRate;
Rate=num2str(orate);

% This might be needed
clear ncinfo ncreadatt ncwriteatt

S = probeConfig;
ProbeSuffix = (S.CDP.rawSuffix);

GROUPS = {'CDP'};
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
[arcNames, rawNames, reverseMap] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

matfile=fullfile(X.tempdir,sprintf("%s_TAS.mat",X.BaseName));
load(matfile,'TASX');

% Get CDP dimensions
jj = cell_find(arcNames,['ACDP_' + ProbeSuffix])

%[mm,nn,oo] = size(ACDP_raw);

% Read in data and set ACDP and CCDP attributes in the output file
% Check if this is the full spectra or combined
% If it is combined, use ['ACDP_1_ + ProbeSuffix];

% Get variable suffix (location) information
cdpName=char(['ACDP_' + ProbeSuffix]);
cdpName1 = char(['ACDP_1_' + ProbeSuffix]);

% Get the data
blurf=ncread(X.RawPath,cdpName);
ACDP_raw=permute(blurf,[2,3,1]);
[mm,nn,oo] = size(ACDP_raw);

MNAME = char(['ACDP_' + ProbeSuffix]);
MNAME1 = char(['ACDP_1_' + ProbeSuffix]);
CNAME  =['C' MNAME(2:end)];
CNAME1 = ['C' MNAME1(2:end)];

FirstBin = ncreadatt(X.ncFINAL,MNAME,'FirstBin');
LastBin  = ncreadatt(X.ncFINAL,MNAME,'LastBin');

FirstBin1 = ncreadatt(X.ncFINAL,MNAME1,'FirstBin');
LastBin1  = ncreadatt(X.ncFINAL,MNAME1,'LastBin');

SerialNumber = ncreadatt(X.RawPath,MNAME,'SerialNumber');
SampleArea = ncreadatt(X.RawPath,MNAME,'SampleArea');
SampleAreaUnits = ncreadatt(X.RawPath,MNAME,'SampleAreaUnits');
CellEdges = ncreadatt(X.RawPath,MNAME,'CellSizes');
Threshold = ncreadatt(X.RawPath,MNAME,'Threshold');

% Raw data rate 
[irateRaw,dims,frate] = get_irate(X.RawPath,cdpName);
[ACDP,CCDP,cdptot,cdpconc,cdpdbar,cdplwc,cdpreff,frate]= ...
calc_cdp(X.ncFINAL,MNAME,CNAME,irateRaw,orate,TASX,ACDP_raw, ...
FirstBin,LastBin,SerialNumber,SampleArea, ...
SampleAreaUnits,CellEdges,Threshold);

sfx=ProbeSuffix;
ss=sprintf("%s = %s;",strcat('ACDP_',sfx),'ACDP');eval(ss)
ss=sprintf("%s = %s;",strcat('CCDP_',sfx),'CCDP');eval(ss)
ss=sprintf("%s = %s;",strcat('cdptot_',sfx),'cdptot');eval(ss)
ss=sprintf("%s = %s;",strcat('cdpconc_',sfx),'cdpconc');eval(ss)
ss=sprintf("%s = %s;",strcat('cdpdbar_',sfx),'cdpdbar');eval(ss)
ss=sprintf("%s = %s;",strcat('cdplwc_',sfx),'cdplwc');eval(ss)
ss=sprintf("%s = %s;",strcat('cdpreff_',sfx),'cdpreff');eval(ss)

% Fill sample rate info into ncFINAL
ncwriteatt(X.ncFINAL,strcat('ACDP_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('CCDP_', sfx),'OutputRate',frate);
%ncwriteatt(X.ncFINAL,strcat('CDPTot_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('cdpconc_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('cdpdbar_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('cdplwc_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('cdpreff_', sfx),'OutputRate',frate);

ncwriteatt(X.ncFINAL,strcat('ACDP_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('CCDP_', sfx),'SampleRate',irateRaw);
%ncwriteatt(X.ncFINAL,strcat('cdptot_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('cdpconc_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('cdpdbar_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('cdplwc_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('cdpreff_', sfx),'SampleRate',irateRaw);


% Now recalculate after rebinning (combining) some of the lower channels

% test
% combine cells: 9-10, 10-11, and 11-12 um
% combine cells: 12-13, 13-14, and 14-16 um
%ACDP_raw  =[ 1 1 1 1 1 1 1 1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1];
%CellEdges= [2 3 4 5 6 7 8 9 10 11 12 13 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50];
%ACDP_1_raw=[ 1 1 1 1 1 1 1 3  3  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1];
%CellEdges1=[2 3 4 5 6 7 8 9 12 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50];
%LastBin=30;
%LastBin1=26;
%ACDP_raw=ones(1,1,30);
%ACDP_1_raw=nan(1,1,LastBin1);
%x=sum(ACDP_raw);  % should be 30
%y=sum(ACDP_1_raw);% should be 30

kk0=1:length(CellEdges);
% hardwire two specfic windows, specifically 9-12 and 12-16 um.
kk1=find(CellEdges>=8 & CellEdges<=10); % values are micrometers
kk2=find(CellEdges>=10& CellEdges<=12);
kk3=find(CellEdges>=12& CellEdges<=14);

kk=[1:kk1(1),kk1(end),kk2(1),kk2(end),kk3(1),kk3(end):kk0(end)];
[kku]=unique(kk); % keep just the unique values -- 2 windows may be adjacent

CellEdges1=CellEdges(kku);
FirstBin1 = ncreadatt(X.ncFINAL,MNAME1,'FirstBin');
LastBin1  = length(CellEdges1)-1;

zz1=1:(kk1(1)-1);
zz2=kk1(1:(end-1));
zz3=kk2(1:(end-1));
zz4=kk3(1:(end-1));
zz5=kk3(end):oo;

ACDP_1_raw = cat(3, ...
ACDP_raw(:,:,zz1), ...
sum(ACDP_raw(:,:,zz2),3), ...
sum(ACDP_raw(:,:,zz3),3), ...
sum(ACDP_raw(:,:,zz4),3), ...
ACDP_raw(:,:,zz5) ...
);

[ACDP_1,CCDP_1,cdptot_1,cdpconc_1,cdpdbar_1,cdplwc_1,cdpreff_1,frate]= ...
calc_cdp(X.ncFINAL,MNAME1,CNAME1,irateRaw,orate,TASX,ACDP_1_raw, ...
FirstBin1,LastBin1,SerialNumber,SampleArea, ...
SampleAreaUnits,CellEdges1,Threshold);


sfx=ProbeSuffix;
ss=sprintf("%s = %s;",strcat('ACDP_1_',sfx),'ACDP_1');eval(ss)
ss=sprintf("%s = %s;",strcat('CCDP_1_',sfx),'CCDP_1');eval(ss)
ss=sprintf("%s = %s;",strcat('cdptot_1_',sfx),'cdptot_1');eval(ss)
ss=sprintf("%s = %s;",strcat('cdpconc_1_',sfx),'cdpconc_1');eval(ss)
ss=sprintf("%s = %s;",strcat('cdpdbar_1_',sfx),'cdpdbar_1');eval(ss)
ss=sprintf("%s = %s;",strcat('cdplwc_1_',sfx),'cdplwc_1');eval(ss)
ss=sprintf("%s = %s;",strcat('cdpreff_1_',sfx),'cdpreff_1');eval(ss)

% Rename and fFill sample rate info into ncFINAL
ncwriteatt(X.ncFINAL,strcat('ACDP_1_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('CCDP_1_', sfx),'OutputRate',frate);
%ncwriteatt(X.ncFINAL,strcat('cdptot_1_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('cdpconc_1_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('cdpdbar_1_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('cdplwc_1_', sfx),'OutputRate',frate);
ncwriteatt(X.ncFINAL,strcat('cdpreff_1_', sfx),'OutputRate',frate);

ncwriteatt(X.ncFINAL,strcat('ACDP_1_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('CCDP_1_', sfx),'SampleRate',irateRaw);
%ncwriteatt(X.ncFINAL,strcat('cdptot_1_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('cdpconc_1_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('cdpdbar_1_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('cdplwc_1_', sfx),'SampleRate',irateRaw);
ncwriteatt(X.ncFINAL,strcat('cdpreff_1_', sfx),'SampleRate',irateRaw);

irate = irateRaw;
ss1="'orate','irate','Rate','frate','arcNames','ProbeSuffix','Time'";
for ii=1:numel(arcNames);
    ss1=sprintf("%s,'%s'",ss1,arcNames{ii}); 
end; 

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_CDP.mat",X.BaseName));

ss=sprintf("save(matfile,%s);",ss1);eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds')

load_ncFINAL(X.ncFINAL,matfile);

sprintf('Processed get_varCDP.m for Project: %s',X.PROJ)