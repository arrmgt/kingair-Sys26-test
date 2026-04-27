function [tas,tasn]=tasf(varargin) ;               
%function [tas,tasn]=tasf(Qc,Ps,Ta[,mr]) ;               
%TASFM: Compute true airspeed from press/temps (moist version)
%$Source: /home/cvs/kingair/Sys09/tasf.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.3 $)
%$Date: 2012/05/07 15:41:52 $
%
%c                    
%c... input: 
%c...   Qc (pitot - static pressure, corrected, mb)          
%c...   Ps (static pressure, corrected, mb)            
%c...   Ta (static air temperature, K)             
%c...   mr (mixing ratio, kg/kg) -- optional for humidity correction
%c...                    
%c... output: tas (true airspeed, m/s) -- optionally humidity corrected              
%c...         tasn(true airspeed, m/s) -- optionally humidity corrected
%c...                                     using NCAR method
%c... 

Qc=varargin{1};
Ps=varargin{2};
Ta=varargin{3};
if(nargin>3)
   mr=varargin{4};
   if(isempty(mr)),mr=0;end
   q=mr./(1+mr); %specific humidity
 else
   mr=zeros(size(Qc));
   q=zeros(size(Qc));
end

C=phycon();
Mv=C.Mv;
Md=C.Md;
Rd=C.Rd;
Rv=C.Rv;
Cpd=C.Cpd;
Cpv=C.Cpv;
Cvd=C.Cvd;
Cvv=C.Cvv;
eps=C.eps;

Cp = (Cpd + Cpv.*mr)./(1+mr);
Cv = (Cpv + Cvv.*mr)./(1+mr);
R  = (Rd + Rv.*mr)./(1+mr);
k=R./Cp;
kk = find( ~isnan(Ta) & ~isinf(Ta) & Ta>0);
Ta = interp1(kk,Ta(kk),1:numel(Ta),'linear',0)';
tas=sqrt(2.*Cp.*Ta.*((1.+Qc./Ps).^k-1.));

%NCAR method (Bull 9, Apppendix B)
M=mach(Qc,Ps,mr);% 
Gamma=Cpd./Cvd;
    S=sqrt(Gamma.*Rd.*Ta);
Tas=M.*S;
tasn=Tas.*(1+.000304.*q.*1000);

   