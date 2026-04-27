function [f,x,dryp,xfact1,xfact2,xfact3]=nu_re_fit0(x,D,L,power,tair,twire,tas,ps,beta)
%function [f,x,dryp,xfact1,xfact2,xfact3]=nu_re_fit0(x,D,L,TBOIL,power,tair,twire,tas,ps,beta)
%$Source: /home/cvs/kingair/Sys09/lwc301_funs/nu_re_fit0.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.3 $)
%$Date: 2020/09/22 14:20:01 $

% Get the power law coefficients needed to estimate the dry air power
% component of the DMT301 liquid water content sensor
% using matlab lsqnonlin tool
% In dry air, power = dryp
% In cloud, power from lwc [W] = power - dryp
%C 	Input:
%C      x  - [A,B] parameters for wire temperature
%C            A = scale factor
%C            B = Re exponent
%C      D  -  diameter of sensing element
%C      L  -  length of sensing element
%C		power - power to wire (W)
%C		tair -  air temperature (K)
%C		twire -  sensing wire temperature (K)
%C		tas -  true airspeed (m/s)
%C      ps  -  static pressure (mb)
%C      
%C 	Output:
%C		f -  difference (measured - predicted power ) [W]
%C      x  - parameters for clear air power (same as input)
%C 		dryp - predicted dry air power [W]
%C      xfact1,xfact2, xfact3 - debug quantitities
%C         where xfact2 = (tas.*ps*100).^B;
%C               xfact3 = dryp./(A.*(twire-tair))./xfact1;
%C               and xfact1=(120+tflm).^B.* (tflm.^((3-5*B)/2))./(125+tflm);
%C
%C  Derived from King et al (1981)
%C  DOI: https://doi.org/10.1175/1520-0450(1981)020<0195:FPTOTC>2.0.CO;2 
%C  
%C  By Al Rodi, UWyoming, 8/27/2020
%
A=x(1);
B=x(2);
bpow0=.37;
cpow0=.250;
Cpd=1005;

tflm=(tair+twire)/2;

% Physical constants
prf = Cpd.*visc(tflm)./cond(tflm); 
prw = Cpd.*visc(twire)./cond(twire) ;
other=prf.^bpow0.*(prf./prw).^cpow0;


% In dry air, dryp./(twire-tair)/(A.*xfact1)= (tas.*ps*100).^B = xfact2;
%    (King et al, 1982, Fig. 1)


% xfact2 vs xfact3 is King (1981) plot
xfact1=(120+tflm).^B.* (tflm.^((3-5*B)/2))./(125+tflm);
xfact2=(tas.*ps*100).^B;
dryp=A.*other.*(twire-tair).*xfact1.*xfact2;
xfact3=(power)./(A.*other.*(twire-tair))./xfact1;
f=power-dryp ;





