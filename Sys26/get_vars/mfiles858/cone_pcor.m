function [pcorc,qx,tbx,tax,fcoef,XXf,betaf,machn]=cone_pcor(p1,pb,pa,pr,psm,varargin);
%
% Calculate flow angles and static pressure correction
%
%  [pcorc,qx,tbx,tax,f0,XXf,betaf,machn] = cone_pcor(X,PSM[,MR])
%   where X is an array of pressure measurements (see  below)
%      PSM is uncorrected static pressure
%      MR is mixing ratio for humidity correction [g/g] (optional)
%
%   Outputs [pcorc,qx,tbx,tax,f0,XXf,betaf,machn] 
%       pcorc = Static pressure correction 
%       qx = dynamic pressure
%       tbx = tan of sideslip angle beta
%       tba = tan of attack angle alpha
%       f0 = 858 probe sensitivity factor
%       XXF, betaf , machn are for diagnostic checking (see below)
%     


% From Rodi&Leon(2012)
betaf = [ ...
   1.699864444944109; ...
  -0.156929423443038; ...
   0.066325085038090; ...
   0.001254576494439  ...
   ];

if(isempty(varargin))
    mr = zeros(size(p1));
else
    mr = varargin{1};
end

p1_min = 10; %mb
kk = find(p1>p1_min);

% These are independent of static pressure correction
tbx = tanBeta(pb,pr);
tax = tanAlpha(pa,pb,pr);
qx0 = impactPcalc(p1,pa,pb,pr); %uncorrected
% fqx us f*q; fqx/f = q; fqx is independent of pcor
fqx = fqCalc(pa,pb,pr);  

% Sanity check
kk = find ( p1>0 & qx0>0 & ((qx0+psm)./psm+1)>1 ...
    & psm>200 & psm<1200 );
if ~isempty(kk)
    p1 = interp1(kk,p1(kk),[1:numel(p1)]','linear',0);
    qx0 = interp1(kk,qx0(kk),[1:numel(p1)]','linear',0);
    psm = interp1(kk,psm(kk),[1:numel(p1)]','linear',0);
end

onez = ones(size(psm));
% Set default f
f0=1.68.*ones(size(p1)); % just a guess
%  We need mach number to get f, so we have to iterate
pErr = fqx./f0 -qx0;  %  Error in q
for jj=1:3 % Iterate three times
% We need machn to get pErr, and pErr to get machn
    machn=mach(qx0+pErr,psm-pErr,mr);
    % Rodi & Leon(2012)
    XX=[machn machn.^2 pa]; 
    XXf=[onez XX];
    f0=XXf*betaf; 
    pErr=fqx./f0-qx0;
end

pcorc = pErr; 
qx = fqx./f0;
fcoef = f0;

kk=find( p1<=p1_min | isnan(machn) |isinf(machn) );
if(~isempty(kk));
    pcorc(kk)=0;
    qx(kk)=0;
    tbx(kk)=0;
    tax(kk)=0;
    fcoef(kk)=0;
end

return

