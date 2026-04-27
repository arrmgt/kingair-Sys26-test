%FCSIRO: compute LWC for CSIRO probe for different probes and models.
%$Id: fcsiro.m,v 1.3 2014/06/20 15:01:02 rodi Exp $
function [f,plwc,dryp1,re1,nu1,other1,fact,twire]=...
    fcsiro(x,probe,Model,wk,qc,tas,atx,psxc,coef,slope,beta,TBOIL);
%function [f,plwc,dryp1,re1,fact,other1,twire]=...
%   fcsiro(x,probe,Model,wk,qc,tas,atx,psxc,coef,slope,beta,TBOIL);
%$Source: /home/cvs/kingair/Sys09/fcsiro.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.3 $)
%$Date: 2014/06/20 15:01:02 $
%C 	Input:
%C              x  - parameters for wire temperature
%C              probe - 1=old UW; 2=DMT
%C              model - 0=const; 1=power; 2=qc; 3=King(1981)
%C		wk - power to wire (W)
%C		qc - dynamic pressure (mb)
%C 		tas - true air speed (corrected for flow angle) [m/s]
%C 		atx - ambient air temperature [K]
%C 		psxc - static pressure (corrected for defect) [mb]
%C		coef - constant coefficient for Re/Nu relation [dim]
%C		slope - exponent for Re (i.e. Re.^slope)
%C		fact - the factor for conversion of power to LWC.
%C		other1 - diagnostic factor (disregard)
%C 	Output:
%C		f -  difference (Measured - predicted power ) [W]
%C 		plwc - liquid water content [g/m3]
%C		dryp1 -  predicted dry air power [W]
%C              Re   - Reynolds number
%C              Nu   - Nusselt number 
%C		fact - the factor for conversion of power to LWC.
%C		other1 - diagnostic factor (disregard)
%C		twire - diagnosed sensor temperature
%C  
%C  By Al Rodi, UWyoming, 12/16/97
%C		20001219: added King (1981) wire coating model.
%C*/
%C/*  Adapted from Darrel Baumgardner  OCT. 1990  
%C	Nimbus	King Probe Liquid Water Content Code
%C*/
%C  Lifted from $NIMBUS software. . . .
%	subroutine csirolwc(wk,tas,atx,psxc,acoef,twire,dryp1,plwc)
%C
%C.. compute dry and wet terms in CSIRO liquid water probe equation
%C 
	acoef=coef;
	apow=slope;
	bpow=.37;
	cpow=.250;
%C       Sensitive element dimensions [meters]
	if(probe == 1),%  UWYO unit
	al1 =3.8e-2;
	ad1 =.17e-2;
	elseif(probe == 2), % DMT unit
	al1 =2.0e-2;
	ad1 =.19e-2;
	else
	echo 'probe must be 1 or 2'
	return
	end

	C=phycon();
	area=ad1.*al1;
%
	if(Model == 1)
% following is coating Model based upon measured power
	twire=C.Tzero+x(1).*wk+x(2);
	end
%
	if(Model == 2)
% following is coating Model based upon dynamic pressure 
	twire=C.Tzero+x(1).*qc+x(2);
	end
%
	if(Model == 3)
% following is coating Model based King et al (1981)
	% guess at wire temperature 120 C = 393.15 K
	twire=393.15;
	tk=atx;
	tflm=(twire+tk)./2;
	cnd = 2.43e-2.*(398../(125.+tflm)).*(tflm./273.).^1.5  ;
	fct = pi.*al1.*cnd.*(twire-tk) ;
	nu=wk./fct;
	lambda=x(2).*nu.*cnd;
	twire=(x(1)+C.Tzero+lambda.*tk)./(1+lambda);
	end
%
	if(Model == 0)
% following is constant Wire temp model
	twire=C.Tzero+x(1);
	end
%
	tasx=tas;
	tk = atx;
	twk1 = twire;
	tflm1 = (twk1+tk)./2. ;%       !  "film" temperature
	if(tflm1 == 0.0), tflm1 = 0.001 ;end

%C	./.* Calculate the thermal conductivity  .*./  units J./m./K./s
%C	using "Sutherland's equation (as in King et al 1981)
	cnd1 = 2.43e-2.*(398../(125.+tflm1)).*(tflm1./273.).^1.5 ;
	cndw1 = 2.43e-2.*(398../(125.+twk1)).*(twk1./273.).^1.5  ;

%C	./.* Calculate the viscosity  .*./  units kg./m./sec
	visc1 = 1.718e-5.*(393../(120.+tflm1)).*(tflm1./273.).^1.5; 
	vscw1 = 1.718e-5.*(393../(120.+twk1)).*(twk1./273.).^1.5 ;

%C	./.* Calculate the density  .*./  units kg./m3
	dens1 = psxc.*100./(C.Rd.*tflm1) ;
	fct1 = pi.*al1.*cnd1.*(twk1-tk) ;
	nu1=wk./fct1;
        if(visc1 == 0.0 ), visc1 = 0.001 ;end
        if(cnd1 == 0.0 ), cnd1 = 0.001 ;end
        if(cndw1 == 0.0 ); cndw1 = 0.001;end 
	re1 = dens1.*tasx.*ad1./visc1 ; 
	prf1 = C.Cpd.*visc1./cnd1; 
	prw1 = C.Cpd.*vscw1./cndw1 ;


        if(prw1 == 0.0 ), prw1 = 0.001 ;end
        if(tasx == 0.0 ), tasx = 1.0 ;end

%c.. nominal acoefficient (acoef)=.26
%	xx=[0.4776   -1.6492    0.5289    0.2851  115.5338];
%	acoef=xx(1)+xx(2).*beta;
%	apow=xx(3)+xx(4).*beta;
	other1=prf1.^bpow.*(prf1./prw1).^cpow;
	dryp1 = acoef.*re1.^apow.*prf1.^bpow.*(prf1./prw1).^cpow.*fct1; 
	alhv100=lhvtemp(100);% latent heat of vap at 100
	cw=C.Cw; % specific heat of liquid water
        alhv=lhvtemp(TBOIL-C.Tzero); %latent heat vap = f(T)
  	fact = 1.0e3./(area.*tasx.*(alhv+cw.*(TBOIL-tk))) ;
	diff=(wk - dryp1) ;
	plwc=diff.*fact;
	f=diff;

