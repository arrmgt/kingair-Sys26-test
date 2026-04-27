function xout=changeRateWrapped(xin,ninterp,ndecim,units0);

if(strfind(units0,'deg')); % change to radians
    xin=xin*pi/180;
end

sin1=decimateByFactors( Ninterp( sin(xin) ,ninterp), ndecim,'FIR');
cos1=decimateByFactors( Ninterp( cos(xin) ,ninterp), ndecim,'FIR');
xout=atan2(sin1,cos1);
jj=find(xout<0);
xout(jj)=xout(jj)+2.*pi;
if(strfind(units0,'deg')); % change to radians
    xout=xout*180/pi;
end




