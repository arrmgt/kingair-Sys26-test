function y = getdata(ncfile, Var)

x=ncread(ncfile,Var); 
x=x(:);
y=zeros(size(x));
kk=find(~isnan(x));
y(kk)=x(kk);

