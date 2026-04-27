function PHADS=get_hads(X,hname,HADS_VR,HADS_VT,HADS_PER);

%GET_HADS: get the  Hz HADS static pressure data
%$Source: /home/cvs/kingair/Sys09/get_hads.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.2 $)
%$Date: 2011/04/29 12:58:55 $

%if(isempty(hname)),hname='HADSA';end
%%(isempty(oname)),oname='ps_hads';end

% Eliminate an error message from the netcdf toolbox
warning('off','MATLAB:dispatcher:InexactCaseMatch');

orate=X.procRate;
Rate=orate;
rawFile = X.RawPath;

% HADS Channel A Temperature Correction
% HADS Channel A Temperature Reference 
% HADS Channel A Pressure 
Pm=HADS_PER(:);
T=(HADS_VT-HADS_VR)./HADS_VR;

PERNAME=strrep('HADS_PER','_',strcat(hname,'_'));
Po=ncreadatt(X.RawPath,PERNAME,'Po');

% fourth order polynomial coefficients
F=ncreadatt(X.RawPath,PERNAME,'F');
G=ncreadatt(X.RawPath,PERNAME,'G');
H=ncreadatt(X.RawPath,PERNAME,'H');
I=ncreadatt(X.RawPath,PERNAME,'I');
J=ncreadatt(X.RawPath,PERNAME,'J');
Kspan=ncreadatt(X.RawPath,PERNAME,'Kspan');;

% apply polynomial coeff using Horners rule
HF=(((F(5).*T + F(4)).*T + F(3)).*T + F(2)).*T +F(1);
HG=(((G(5).*T + G(4)).*T + G(3)).*T + G(2)).*T +G(1);
HH=(((H(5).*T + H(4)).*T + H(3)).*T + H(2)).*T +H(1);
HI=(((I(5).*T + I(4)).*T + I(3)).*T + I(2)).*T +I(1);
HJ=(((J(5).*T + J(4)).*T + J(3)).*T + J(2)).*T +J(1);

Y=Po-Pm;
PHADS=( (((HF.*Y + HG).*Y + HH).*Y + HI).*Y +HJ ).*Kspan; % in mmHg here
kk=find(isnan(PHADS)==1 & abs(gradient(PHADS))>3);
if(length(kk)>0)
    nn=length(PHADS);
    jj=setdiff(1:nn,kk);
    PHADS=interp1(jj,PHADS(jj),1:nn,'linear')';
    %%MC{oname}.NumberOfNaNs=ncint(length(kk));
end

% PrCalib is the calibration to the nominal HADS output
PrCalib=ncreadatt(X.RawPath,PERNAME,'PressureCalibration');

if(length(PrCalib)==2), % i.e. PrCalib is in the header
    PHADS=PHADS.*PrCalib(2)+PrCalib(1);
    %%MC{oname}.CalibMethod= 'UW calibration used' ;
else ;% apply conversion of mmHg to mb directly
    PHADS=PHADS.*1013.25./29.92;
    %%MC{oname}.CalibMethod= 'Manufacturers calibration used' ;
end

%%if(strcmp(oname,'ps_hads')==1 | strcmp(oname,'ps_hads_a')==1),PHADSA=PHADS;clear PHADS;end
%%if(strcmp(oname,'ps_hads_b')==1),PHADSB=PHADS;clear PHADS;end

%%MC=close(MC)

