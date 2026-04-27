function get_varRADIATION(X)

TT=datetime('now');
% Physical constants structure
C=phycon;
Tzero=C.Tzero;

% Load time vector to reference length
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end


% Get raw variables needed for tas group
%
orate=X.procRate;
Rate=orate;
rawfile=X.RawPath;

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc
GROUPS = "RADIATION";
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Cross-check
info = ncinfo(X.RawPath);
rnames = {info.Variables.Name};
[tf, loc] = ismember(rawNames,rnames);
if any(isempty(loc));
    error('get_varRADIATION: raw varariable missing')
end

% if(innamePP('rstb2'))
%   Var='KT'
%   blurf=getdata(NC,Var,ninterp,ndecim,[],'Celsius');
% 
% Check if low rate (1Hz) and over fires (kt > 50)
% If so, get the 1 HZ RS-232 values
%   if orate==1 & max(blurf) > 50
%     blurf=getdata(NC,'KT1585',1,1,[],'Celsius');
%   end
%   evalin('caller',strcat(Var,Rate,'=blurf',';'));
% end

pira =0.0010289;
pirb =0.0002392;
pirc =1.56e-7;
%
% Upper PIR hemisphere temperature
%
  Var='PIRHU'
  blurf = getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','ohm');
  pirhu=1./(pira+pirb.*log(blurf)+pirc.*(log(blurf)).^3) - Tzero;
  TDomeT = pirhu;
%
% Upper PIR case temperature
%
  Var='PIRCU'
  blurf= getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','ohm');
  pircu=1./(pira+pirb.*log(blurf)+pirc.*(log(blurf)).^3)-Tzero;
  TSinkT = pircu;
%
% Upper PIR radiometer
%
  Var='PIRU'
  piru= getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','watt/m2');
  piruc=pyrgeom(pirhu,pircu,piru);
  irt = piru;
  irtc = piruc;

%"Upper Eppley PIR hemisph. temperature "
  if ~any(ismember(arcNames,'TDomeT')); clear pirhu; end
  if ~any(ismember(arcNames,'TDomeT')); clear pirhd; end
  if ~any(ismember(arcNames,'irt'));    clear piru;  end


%
% Lower PIR hemisphere temperature
%
if any(ismember(arcNames,'irbc'))
  Var='PIRHD'
  blurf= getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','ohm');
  pirhd=1./(pira+pirb.*log(blurf)+pirc.*(log(blurf)).^3)-Tzero;
  TDomeB = pirhd;
end

%
% Lower PIR case temperature
%
  Var='PIRCD'
  blurf = getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','ohm');
  pircd =1./(pira+pirb.*log(blurf)+pirc.*(log(blurf)).^3)-Tzero;
  TSinkB = pircd;
%
% Lower PIR radiometer
%
  Var='PIRD'
  pird= getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','watt/m2');
  pirdc=pyrgeom(pirhd,pircd,pird);
  irb = pird;
  irbc = pirdc;

  if ~any(ismember(arcNames,'TSinkB')); clear pircu; end
  if ~any(ismember(arcNames,'TSinkB')); clear pircd; end
  if ~any(ismember(arcNames,'irb'));  clear pird;  end

%
% Upper PSP radiometer
%
if any(ismember(arcNames,'swt'))
  Var='PSPU'
  pspu= getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','watt/m2');
  swt = pspu;
end

%
% Lower PSP radiometer
%
if any(ismember(arcNames,'swb'))
  Var ='PSPD'
  pspd = getdata(X.RawPath,Var,'OutputRate',orate,'UnitsOut','watt/meter2');
  swb = pspd;
end

% Old BX100 radiometer
if any(ismember(arcNames,'bxa100'))
  BXA100_ = getdata(X.RawPath,'BXA100','OutputRate',orate,'UnitsOut','watts/meter2');
  BXB100_ = getdata(X.RawPath,'BXB100','OutputRate',orate,'UnitsOut','watt/meter2');
  BXC100_ = getdata(X.RawPath,'BXC100','OutputRate',orate,'UnitsOut','watts/meter2');
  BXD100_ = getdata(X.RawPath,'BXD100','OutputRate',orate,'UnitsOut','watts/meter2');
% Calculate the NDVI vegetation index
  if any(ismember(arcNames,'ndvi'))
    refc = BXC100_./0.078;
    refd = BXD100_./0.127;
    ndvi = (refd - refc)./(refd + refc);
  end
end

ss1="'orate','Rate','rawfile','arcNames','rawNames','Time','ss1'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_RADIATION.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=ceil(seconds(TT1-TT));
sprintf("procSeconds= %.0f",procSeconds)
save(matfile,'-append','procSeconds','TT','TT1')
;
load_ncFINAL(X.ncFINAL,matfile);
sprintf('Processed get_varRADIATION.m for Project: %s',X.PROJ)

end