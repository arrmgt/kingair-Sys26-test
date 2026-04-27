function y=unwrap_wrap(x,ninterp,ndecim,FillValue,units);
% unwrap, then interp/decim, then wrap

nn=1:numel(x);
notmiss=find(x~=FillValue);
nmiss=setxor(nn,notmiss);


% Get sizes of final output 
xx=Ninterp(x,ninterp,'linear');
yy=decimateByFactors(xx,ndecim,'linear');

if(~isempty(strfind(units,'deg')))
x1=unwrap(x(notmiss).*pi./180,pi);
else; % must be radians
x1=unwrap(x(notmiss),pi);
end

x2=interp1(notmiss,x1,nn);

% Missing values removed; x1 is in radians
x3=Ninterp(x2,ninterp,'linear');
x4=decimateByFactors(x3,ndecim,'FIR');
x5=wrap(x4);

% Convert units back if necessary
if(~isempty(strfind(units,'deg')))
y=x5.*180./pi;
else; % must be radians
y=x5;
end

return

