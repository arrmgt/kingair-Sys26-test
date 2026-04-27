function get_varLWC100a(X)

% Load time vector to reference length
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
load(matfile,'PSX','TEMPX','TASX','qc','alpha','beta','');
clear TT TT1 names

xlsfile='defines3.xlsx';
GROUPS={'LWC100'};
ProbeSuffix=[];
names=namesQQ(X,GROUPProbeSuffix,'nameLWC100',GROUPS);

TT=datetime('now');

Var='LWC100'
irate=1000;
[ninterp,ndecim]=interp_decim(irate,orate);
blurf=ncread(X.RawPath,Var);
DMT=decimateByFactors(Ninterp(blurf(:),ninterp),ndecim,'FIR');
nmiss=0;
ncwriteatt(X.ncFINAL,'lwc100','MissingValues',nmiss);

%
% First use constant wire temp model to get rough lwc100 values
%
probe=2;% DMT 100 probe (probe=1 is UW)
%lsqnonlin:  A Levenberg-Marquardt method .
Model=0;%constant wire temp
options=optimset('lsqnonlin');

v = ver('MATLAB');
options = optimset(options,'Algorithm','Levenberg-Marquardt');

options=optimset(options,'MaxIter',1000);
options=optimset(options,'TolFun',1e-6);
options=optimset(options,'TolX',1e-6);

% Boiling point of water as a function of atmos pressure
PP=300:1100;
TBOIL=spline(PP,boilpoint(PP),PSX);


DMT_on=5.5; % [W] detects system "on"
x0=[120];%inital guess at wire temp (C)
[f0,LWC100]=fcsiro(x0,2,Model,DMT,qc,TASX.*cos(alpha),TEMPX,PSX,.26,.60,beta,TBOIL);
LW0=LWC100;
zz=find(~isnan(LW0) & ~isinf(LW0));
[n,x]=hist(LW0(zz),500);
[y,i]=max(n);
klear=x(i);
klear1=klear-0.1;
klear2=klear+0.1;

%
% now fine tune selection for clear air values
% and use power model to recompute lwc100
%
%Model=1;%power modelbeta
Model=2;%qc model
kk=find(LWC100>klear1 &LWC100<klear2 & aias>110 & DMT>DMT_on );
ii=find(detrend(beta(kk),'constant')<.01);
kk=kk(ii((5*orate:end)));

if(length(kk)>100),%turned on?
    x0=lsqnonlin('fcsiro',[0 130],[],[],options,2,Model,DMT(kk),qc(kk),TASX(kk).*cos(alpha(kk)), ...
    TEMPX(kk),PSX(kk),.26,.60,beta(kk),TBOIL(kk));
    [f0,lwc100]=fcsiro(x0,2,Model,DMT,qc,TASX.*cos(alpha),TEMPX,PSX,.26,.60,beta,TBOIL);
    
    %
    % Do once more with refined values 
    % still using power model
    %
    kk1=find(abs(lwc100)<0.05 & aias>110 & DMT>DMT_on );
    ii=find(detrend(beta(kk1),'constant')<.01);
    kk1=kk1(ii((5*orate:end)));
    [x1,resn1,res1,exflg1]=lsqnonlin('fcsiro',x0,[],[],options,2,Model,DMT(kk1),qc(kk1), ...
    TASX(kk1).*cos(alpha(kk1)),TEMPX(kk1),PSX(kk1),.26,.60,beta(kk1),TBOIL(kk1));
    [f1,lwc100,dryp1,re,nu,other1,fct1]=fcsiro(x1,2,Model,DMT,qc,TASX.*cos(alpha),...
    TEMPX,PSX,.26,.60,beta,TBOIL);
    twire1=x1(1).*DMT+x1(2);
    
    %finally, remove more outliers
    zz=find(abs(f1(kk1))<.1);
    kkf=kk1(zz);
    
    kkk=find(aias>50 & DMT>DMT_on);
    clear_air=length(kkf)./length(kkk)*100; % percent
    
    R2=corrcoef(log(re(kkf)),log(nu(kkf)));
    
    if(clear_air>15  & R2(1,2)>0.8 ); %
    'DMT: enough clear air data'
    [x2,resn2,res2,exflg2]= ...
    lsqnonlin('fcsiro',x0,[],[],options,2,Model, ...
    DMT(kkf),qc(kkf),TASX(kkf).*cos(alpha(kkf)),TEMPX(kkf),PSX(kkf), ...
    .26,.60,beta(kkf),TBOIL(kkf));
    [f2,lwc100,dryp2,re,nu,other2,fct2,twire]=fcsiro(x2,2,Model,DMT,qc,TASX.*cos(alpha), ...
    TEMPX,PSX,.26,.60,beta,TBOIL);
    lresid2=std(f2(kkf));
    
    twmin=min(twire(kkf));twmax=max(twire(kkf));
    ncwriteatt(X.ncFINAL,'lwc100','MinWireTempC',round(twmin));
    ncwriteatt(X.ncFINAL,'lwc100','MaxWireTempC',round(twmax));
    ncwriteatt(X.ncFINAL,'lwc100','ResidStdev',lresid2);
    ncwriteatt(X.ncFINAL,'lwc100','WireTempCoeff',x2);
    ncwriteatt(X.ncFINAL,'lwc100','ClearAirFitRValue',R2(1,2));
    
    else ; % use default from variables*.cdl file
    'DMT: not enough clear air data'
    Model=0; % constant wire temperature
    x2=ncreadatt(X.ncFINAL,'/','DMT.defaultWireTempCoeffs');
    x2=120;
    [f2,lwc100,dryp2,re,nu,other2,fct2,twire]=fcsiro(x2,2,Model,DMT,qc,TASX.*cos(alpha),...
    TEMPX,PSX,.26,.60,beta,TBOIL);
    ncwriteatt(X.ncFINAL,'lwc100','Comment','Default wire temperature coefficient used');
    ncwriteatt(X.ncFINAL,'lwc100','WireTempCoeff',x2);
    end
    
    ii=setxor(1:length(DMT),kkk);
    if(length(ii)>0);lwc100(ii)=zeros(length(ii),1);end
    
    ncwriteatt(X.ncFINAL,'lwc100','EstClearAirPercent',round(clear_air*10)/10);
    if(Model == 0),ncwriteatt(X.ncFINAL,'lwc100','WireTempModel','Const wire temp model');end
    if(Model == 1),ncwriteatt(X.ncFINAL,'lwc100','WireTempModel','Power model');end
    if(Model == 2),ncwriteatt(X.ncFINAL,'lwc100','WireTempModel','Qc model');end
    
    kk=find(aias<80);
    lwc100(kk)=zeros(length(kk),1);

else
    'DMT-100 turned on??'
    ncwriteatt(X.ncFINAL,'lwc100','Comment', 'DMT-100 turned on??');
    lwc100=zeros(length(DMT),1);
end

ss1="'orate','Rate','rawfile','names','Time'";
for ii=1:numel(names);
    ss1=sprintf("%s,'%s'",ss1,names{ii}); 
end
% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_LW100.mat",X.BaseName));
delete(matfile)
ss=sprintf("save(matfile,%s);",ss1);eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds')
;
load_ncFINAL(X.ncFINAL,matfile);


sprintf('Processed get_varLWC100a.m for Project: %s',X.PROJ)