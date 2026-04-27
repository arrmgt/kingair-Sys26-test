function out=wrap(varargin);
%function out=wrap(in);
% re-raps 0-2*pi type data

in=varargin{1};

%flag360 indicates...
if(nargin==2)
  flag360=varargin{2};
 else
  flag360=[];
end

out=in;
kk=find(in<-pi);
twopi=2*pi;

while(~isempty(kk))
  out(kk)=out(kk)+twopi;
  kk=find(out<0);
end

kk=find(out>pi);
while(~isempty(kk))
  out(kk)=out(kk)-twopi;
  kk=find(out>=pi);
end

if(~isempty(flag360))
  kk=find(out<0);
  out(kk)=out(kk)+twopi;
end


 
