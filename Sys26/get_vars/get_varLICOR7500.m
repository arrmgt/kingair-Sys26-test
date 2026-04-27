function get_varLICOR7500(X)

% Output variables
%  co2abs75:long_name = "Licor 7500A CO2 absorptivity" ;`
%  h2oabs75:long_name = "Licor 7500A H2O absorptivity" ;
%  co2absraw75:long_name = "Licor 7500A CO2 rs-232 absorptivity" ;
%  h2oabsraw75:long_name = "Licor 7500A H2O absraworptivity" ;
%  co2ndens75:long_name = "Licor 7500A CO2 number density" ;
%  h2ondens75:long_name = "Licor 7500A H2O number density" ;
%  co2mdens75:long_name = "Licor 7500A CO2 mass density" ;
%  h2omdens75:long_name = "Licor 7500A H2O mass density" ;
%  co2ml75:long_name = "CO2 mole fraction LICOR 7500A" ;
%  h2oml75:long_name = "H2O mole fraction LICOR 7500A" ;
%  h2omx75:long_name = "H2O mixing ratio LICOR 7500A" ;
%  co2mx75:long_name = "CO2 mixing ratio LICOR 7500A" ;
%  h2oms75:long_name = "H2O specific humidity LICOR 7500A" ;
%  co2ms75:long_name = "CO2 specific humidity LICOR 7500A" ;
%  tdplicor75:long_name = "Dew point temperature from LICOR 7500A H2O mixing ratio" ;
%  li75diag:long_name = "Licor 7500 Diagnostic Value" ;


TT=datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end
% This might be needed
clear ncinfo ncreadatt ncwriteatttime

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc]
GROUPS = {"LICOR7500"};
[arcNames, rawNames, reverseMap] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

orate=X.procRate;
Rate=num2str(orate);

C=phycon();
Rd=C.Rd; % Dry air constant
Mv=C.Mv; % MW H2O
Md=C.Md; % MW H2O
Mco2=C.Mco2; % MW CO2
Rv=C.Rv;
Rstar=C.Rstar;
T0=C.Tzero;

% get temperature and pressure from previously run TAS matlab file
matfile=fullfile(X.tempdir,sprintf("%s_TAS.mat",X.BaseName));
load(matfile,'PSX','TEMPX');
TK=TEMPX;
PMB=PSX; % corrected static pressure

% Effective pressure for water vapor
Pew_Pa=PMB.*100;
Pew_kPa=Pew_Pa./1000;

% li75diag:long_name = "LI-7500 Diagnostic Value" ;
Var0='LI75DIAG';
Var1=lower(Var0);
% get desired units from archive file
units1=ncreadatt(X.ncFINAL,Var1,'units');
[blurf,irate,nmiss]=getdata(X.RawPath,Var0,'OutputRate',orate,"UnitsOut",units1);
eval(strcat(Var1,'=blurf',';'));
ncwriteatt(X.ncFINAL,Var1,'InputRate',irate);
ncwriteatt(X.ncFINAL,Var1,'MissingValues',nmiss);

% li75cool:long_name = "LI-7500 Cooler" ;
Var0='LI75COOL';
Var1=lower(Var0);
% desired units from archive database
units1=ncreadatt(X.ncFINAL,Var1,'units');
[blurf,irate,nmiss]=getdata(X.RawPath,Var0,'OutputRate',orate,"UnitsOut",units1);
eval(strcat(Var1,'=blurf',';'));
ncwriteatt(X.ncFINAL,Var1,'InputRate',irate);
ncwriteatt(X.ncFINAL,Var1,'MissingValues',nmiss);

% h20abs75:long_name = "Licor 7500A H20 absorptivity";
% h20abs75:units = "dimensionless";
% h20abs75:matlab_name = "H20A" ;
Var='H2OA';
[blurf,irate,nmiss]=getdata(X.RawPath,Var,'OutputRate',orate);
eval(strcat(Var,'=blurf',';'));
ncwriteatt(X.ncFINAL,'h2oabs75','InputRate',irate);
ncwriteatt(X.ncFINAL,'h2oabs75','MissingValues',nmiss);
%	CrossSens=NC{Var}.CrossSensitivity(:);
%	Zero=NC{Var}.Zero;
%	Z=NC{Var}.Z;
H2OA=blurf;
h2oabs75=blurf;

% h2oabsraw75:long_name = "Licor 7500A H20 absorptivity";
% h2oabsraw75:units = "dimensionless";
% h2oabsraw75:matlab_name = "H20RAW" ;
Var='H2ORAW';
[blurf,irate,nmiss]=getdata(X.RawPath,Var,'OutputRate',orate);
eval(strcat(Var,'=blurf',';'));
ncwriteatt(X.ncFINAL,'h2oabsraw75','InputRate',irate);
ncwriteatt(X.ncFINAL,'h2oabsraw75','MissingValues',nmiss);
%	CrossSens=NC{Var}.CrossSensitivity(:);
%	Zero=NC{Var}.Zero;
%	Z=NC{Var}.Z;
H2ORAW=blurf;
h2oabsraw75=blurf;


% Change only this to switch to desired input
%Use='XA'; % this is for H2OA and CO2A absorptivity
Use='XRAW'; % this is for H2ORAW and CO2RAW absorptivity
% end of changes

switch Use
    case 'XA'
        nameH='H2OA';
        AbsH=H2OA;
        Coeff=ncreadatt(X.RawPath,nameH,'AdditionalCoefficients');
        Coeff=[Coeff(end:-1:1) 0];
        Span=ncreadatt(X.RawPath,nameH,'Span');
    case 'XRAW'
        nameH='H2ORAW';
        AbsH=H2ORAW;
        Coeff=ncreadatt(X.RawPath,nameH,'AdditionalCoefficients');
        Coeff=[Coeff(end:-1:1) 0];
        Span=ncreadatt(X.RawPath,nameH,'Span');
end

% h2ondens75:long_name = "Licor 7500A H2O number density";
% h2ondens75:units = "mmol/m3" ;
% h2ondens75:matlab_name = "h2ondens75_" ;
%Number density (mmol/m3)
Q=AbsH.*Span./Pew_kPa;
W=Pew_kPa.*polyval(Coeff,Q);
W(W<=1)=1;
h2ondens75=W;

% h2omdens75:long_name = "Licor 7500A H2O mass density";
% h2omdens75:units = "gram/m3" ;
% h2omdens75:matlab_name = "h2omdens75_" ;
%H2O mass density (g/m3)
Wm=Mv.*W./1000;
h2omdens75=Wm;

% h2oml75:long_name = "H2O mole fraction LICOR 7500A";
% h2oml75:units = "mmol/mole";
% h2oml75:matlab_name = "h2oml75_" ;
% H2O mole fraction (mmol/mol)
rho_air=Pew_Pa./Rstar./TK; % moles air/m3
Wf=W./rho_air;
h2oml75=Wf; %mmol/mole

% h2omx75:long_name = "H2O mixing ratio LICOR 7500A";
% h2omx75:units = "gram/kgram";
% h2omx75:matlab_name = "h2omx75_" ;
% mixing ratio = eps*e/(P-e)
% Nv=e/P=mole fraction of water vapor
eps=Mv/Md;
e_Pa=Wf./1000.*Pew_Pa; %  Pascals
Pdry=Pew_Pa-e_Pa;
w=eps.*e_Pa./Pdry;
h2omx75=w*1000;  % g/kg

% h2oms75:long_name = "H2O specific humidity LICOR 7500A";
% h2oms75:units = "gram/kgram";
% h2oms75:matlab_name = "h2oms75_" ;
% q=mv/(mv+md);
q=w./(1+w);
h2oms75=q*1000; %g/kg

% tdplicor75:long_name = "Dew point temperature from LICOR 7500A H2O mixing ratio";
% tdplicor75:units = "Celsius";
% tdplicor75:matlab_name = "tdplicor75_" ;
% Dewpoint temperature (use WMO 2000);
e_Pa(find(e_Pa > 100)) = 100;
tdplicor75=vap2dewpoint(e_Pa/100)-T0;

% Licor manual Tdp equation
%x=log(Wf.*Pew_kPa./613.65);
%Tdp=240.97.*x./(17.502-x);

%
%--------------CO2 variables---------------
%

% co2abs75:long_name = "Licor 7500A CO2 absorptivity";
% co2abs75:units = "dimensionless";
% co2abs75:matlab_name = "CO2A" ;
Var='CO2A';
[blurf,irate,nmiss]=getdata(X.RawPath,Var,'OutputRate',orate);
eval(strcat(Var,'=blurf',';'));
ncwriteatt(X.ncFINAL,'co2abs75','InputRate',irate);
ncwriteatt(X.ncFINAL,'co2abs75','MissingValues',nmiss);
CO2A=blurf;
co2abs75=blurf;
%	CrossSens=NC{Var}.CrossSensitivity(:);
%	Zero=NC{Var}.Zero;
%	Z=NC{Var}.Z;

% co2absraw75:long_name = "Licor 7500A CO2 absorptivity";
% co2absraw75:units = "dimensionless";
% co2absraw75:matlab_name = "CO2RAW" ;
Var='CO2RAW';
[blurf,irate,nmiss]=getdata(X.RawPath,Var,'OutputRate',orate);
eval(strcat(Var,'=blurf',';'));
ncwriteatt(X.ncFINAL,'co2absraw75','InputRate',irate);
ncwriteatt(X.ncFINAL,'co2absraw75','MissingValues',nmiss);
CO2RAW=blurf;
co2absraw75=blurf;
%	CrossSens=NC{Var}.CrossSensitivity(:);
%	Zero=NC{Var}.Zero;
%	Z=NC{Var}.Z;

switch Use
    case 'XA'
        irate=1000;
        nameC='CO2A';
        AbsC=CO2A;
    case 'XRAW'
        irate=20;
        nameC='CO2RAW';
        AbsC=CO2RAW;
end

% Effective pressure for CO2 
aw=ncreadatt(X.RawPath,nameC,'aw');
Psi=(1+(aw-1)*Wf./1000);
Pec_kPa=Pew_kPa.*Psi; %Wf/1000 is number conc H2O (moles/m3)
Pec_Pa=Pec_kPa./1000;

% co2ndens75:long_name = "Licor 7500A CO2 number density";
% co2ndens75:units = "mmol/m3";
% c2ondens75:matlab_name = "co2ndens75_" ;
%Number density (mmol/m3)
Span=ncreadatt(X.RawPath,nameC,'Span');
Coeff=ncreadatt(X.RawPath,nameC,'AdditionalCoefficients');
Coeff=[Coeff(end:-1:1) 0];
Q=AbsC.*Span./Pec_kPa;
C=Pec_kPa.*polyval(Coeff,Q);
co2ndens75=C;
ncwriteatt(X.ncFINAL,'co2ndens75','Input',nameC);

% co2mdens75:long_name = "Licor 7500A CO2 mass density";
% co2mdens75:units = "milligram/m3";
% c2omdens75:matlab_name = "co2mdens75_" ;
% CO2 mass density
Cm=Mco2.*C;
co2mdens75=Cm;
ncwriteatt(X.ncFINAL,'co2mdens75','Input',nameC);

% co2ml75:long_name = "CO2 mole fraction LICOR 7500A";
% co2ml75:units = "umol/mole";
% co2ml75:matlab_name = "co2ml75_" ;
% CO2 mole fraction
rho_air=Pew_Pa./Rstar./TK; % moles air/m3
Cf=C./rho_air;
co2ml75=Cf*1000;
ncwriteatt(X.ncFINAL,'co2ml75','Input',nameC);

% co2ms75:long_name = "CO2 specific humidity LICOR 7500A";
% co2ms75:units = "ugram/gram";
% co2ms75:matlab_name = "co2mx75_" ;
% MW moist air = Md*(1-q)+q*Mw=Mm
Mm=Md.*(1-q)+q*Mv;
qco2=Cf./1000.*Mco2./Mm; % mass CO2/mass moist air
co2ms75=qco2*1e6; % ugram/gram

% co2mx75:long_name = "CO2 mixing ratio LICOR 7500A";
% co2mx75:units = "ugram/gram";
% co2mx75:matlab_name = "co2mx75_" ;
wco2=qco2./(1-qco2); %mixing ratio CO2
co2mx75=wco2*1e6; % ugram/gram


for i=1:numel(arcNames)
    if(contains(arcNames{i},'co2'))
        ss=sprintf("ncwriteatt(X.ncFINAL,'%s','%s','%s');",arcNames{i},'Input',nameC);
    elseif(contains(arcNames{i},'h2o'))
        ss=sprintf("ncwriteatt(X.ncFINAL,'%s','%s','%s');",arcNames{i},'Input',nameH);
    end
    eval(ss)
end

ss1="'orate','orate','arcNames','Time'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_LICOR7500.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')
;
load_ncFINAL(X.ncFINAL,matfile);

sprintf('Processed get_varLICOR7500.m for Project: %s',X.PROJ)