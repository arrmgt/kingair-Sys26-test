function [pcorc,qq,tb,ta,f0]=boom_pcor(varargin)
X=varargin{1};
if(length(varargin)>1),b=varargin{2};else,b=0;end

%X=[p1,pb,pa,pr]
p1=X(:,1);
pb=X(:,2);
pa=X(:,3);
pr=X(:,4);

betaf = [ ...
   1.650716541450256; ...
   0.255438248129942; ...
];

%[pcorcx,qx,tbx,tax]=boom_pcor_f0([X]);
f0=1.68*ones(size(p1));
[pcorcx,qqx,tbx,tax]=pkor858(p1,pb,pa,pr,f0);

%regress f from the pressures
XX=[tax];
[nn,mm]=size(XX);
f0=[ones(size(XX),1) XX]*betaf;
%[pcorc,qq,tb,ta,jac]=boom_pcor_f([X f0]);
[pcorc,qq,tb,ta]=pkor858(p1,pb,pa,pr,f0);

kk=find(p1<15);
pcorc(kk)=0;
qq(kk)=0;
tb(kk)=0;
ta(kk)=0;

if(b>0)
'boom_pcor:filtering'
pcorc=filtfilt(b,1,pcorc);
qq=filtfilt(b,1,qq);
tb=filtfilt(b,1,tb);
ta=filtfilt(b,1,ta);
end
