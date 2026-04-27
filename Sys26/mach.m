function [m]=mach(varargin)
%function m=mach(qc,ps,[[mr],recovf]])
%MACH: Compute mach number from pressures
%$Source: /home/cvs/kingair/Sys09/mach.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.3 $)
%$Date: 2011/06/27 16:30:01 $
%

qc=varargin{1};
ps=varargin{2};
if(nargin>2)
  mr=varargin{3};
  if(isempty(mr)),mr=0;end;
  q=mr./(1+mr);
 else
  q=0;
  mr=0;
end

% Moist air (per kg of moist air)
C=phycon();
Rd=C.Rd;
Rv=C.Rv;
Cpd=C.Cpd;
Cvd=C.Cvd;
Cpv=C.Cpv;
Cvv=C.Cvv;

Yd = 1./(1+mr);   Yv = mr./(1+mr);
Cp = Yd.*Cpd + Yv.*Cpv;
Cv = Yd.*Cvd + Yv.*Cvv;
Rm = Yd.*Rd  + Yv.*Rv;
gamma = Cp ./ Cv;
k=(gamma-1)./gamma; % R/Cp


fact=(qc./ps+1).^k-1;
m2=2./(gamma-1).*fact;
m2(find(m2<0))=0;
m=sqrt(m2);

function mach_sim
% Using symbolic toolbox
% tas=sqrt(2.*Cp.*Ta.*((1.+Qc./Ps).^k-1.));
% ts = Tm  ./(1.+recovf.*((1.+Qc./Ps).^k-1.)); 
syms  R Tm  gmma r  Cp M  Qc Ps k  Cv
Cp=Cv*gmma;

fact = (1+Qc/Ps)^k;
Ta = Tm/(1+r*(fact-1)); 
tas2=2*Cp*Ta*(fact-1);
Vs2 = gmma*R*Ta;
M2=tas2/Vs2
