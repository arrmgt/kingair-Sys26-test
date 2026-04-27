function TD=dew(TFP) 
%DEW: compute dew point temp from vapor pressure
%$Source: /home/cvs/kingair/Sys09/dew.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.1 $)
%$Date: 2010/08/10 09:07:05 $

%C SHOULD ONLY ENTER FOR TFP LESS THAN 0 
     T=[0.002 1.133 2.265 3.392 4.516 5.640 6.760 7.883 9.000 ... 
     10.114 11.226 12.335 13.443 14.550 15.654 16.757 17.855 ...
     18.961 20.056 21.151 22.238 23.331 24.420 25.506 26.611 ...
     27.673 28.752 29.831 30.907 31.980 33.054 34.124 35.194 ...
     36.261 37.324 38.387 39.452 40.511 41.565 42.625 43.671 ...
     44.731 45.775 46.820 47.865 48.909 49.949];
%C THESE VALUES ARE FROM SMITHSONIAN TABLES.  ROUTINE USES INTERPOLATION 
%C BETWEEN THESE VALUES.
      [nn,mm]=size(TFP);
      TD=ones(nn,mm).*-999.;
      [P,S]=polyfit([0:46],T,4);
      kkk=find(TFP<0 & TFP>-46.);
      TD(kkk)=-polyval(P,-TFP(kkk),S);

      kkk=find(TFP>=0);
      TD(kkk)=TFP(kkk);
      
      kkk=find(TFP<=-46.);
      TD(kkk)=-49.949+1.0436.*(TFP(kkk)+46.);
      return
