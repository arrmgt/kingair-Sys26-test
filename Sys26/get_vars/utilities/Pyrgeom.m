function rad=pyrgeom(pgdt,pgst,pyrg)
%function rad=pyrgeom(pgdt,pgst,pyrg)
%PYRGEOM: compute corrected IR irradiance from dome and sink temps.
%$Source: /home/cvs/kingair/Sys09/pyrgeom.m,v $
%Project $Name:  $ ($Revision: 1.2 $)
%$Date: 2023/04/10 18:06:19 $

%
%********************************************************************  
%
%     corrected top/bottom pyrgeometer irradiance (watts/m2)
%     requires:1-pgdt;2-pgst;3-pyrg
%     where:  pgdt = Pyrgeometer Dome Temperature (C)
%             pgst = Pyrgeometer Sink Temperature (C)
%             pyrg = Uncorrected Pyrgeometer Irradiance (w/m2)
%
%********************************************************************
    C=phycon;
    Tzero = C.Tzero;
     e0 = 0.986 ;  
     sbc = 5.6686e-8 ; 
     xktb = 5.50 ;% from NCAR's processing
     %xktb = 4.30 ;% from NCAR Bulletin 25

     dscor = xktb .* sbc .* ((pgdt+Tzero).^4 - (pgst+Tzero).^4);
     tcor  = e0 .* sbc .* ((pgst+Tzero).^4);
     rad   = pyrg - dscor + tcor;

     return
