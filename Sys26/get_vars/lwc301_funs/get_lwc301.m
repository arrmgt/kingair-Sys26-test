function [plwc4,dryp4,twire,y4,fy,R2,ci,kk]= ...aias
   get_lwc301(orate,power,q_impact,tas,alpha,beta,tair,ps,ias)
%function [plwc4,dryp4,twire,y4,fy4,R2,ci,re,nu]= ...
%  get_lwc301(orate,power,q_impact,tas,alpha,beta,tair,ps,ias)
%
%$Source: /home/cvs/kingair/Sys09/lwc301_funs/get_lwc301.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.8 $)
%$Date: 2020/09/22 14:20:01 $
% Get the power law coefficients needed to estimate the dry air power
% component of the DMT LWC301 liquid water content sensor
% using matlab lsqnonlin tool
% In dry air, power = dryp
% In cloud, power from lwc [W] = power - dryp

%C 	Input:(orate,power,qc,tas,alpha,beta,tair,ps,q_impact)
%C      orate - output rate
%C		power - power to wire (W)
%C		q_impact -  impact pressure corrected for static defect (mb)
%C		tas   -  true airspeed (m/s)
%C		alpha -  attack angle (radians)
%C		beta  -  sideslip angle (radians)
%C		tair  -  air temperature (K)
%C		ps    -  static pressure corrected for static defect (mb)
%C		ias  -  indicated airspeed (knots)
%C      
%C 	Output: [plwc4,dryp4,twire,y4,fy,R2,ci,kk]
%C		plwc4  - calculated liquid water content (g/m3)
%C		dryp4  - dry air power predition (W)
%C		twire  - temperature of sensing element (K)
%C		y4     - estimated coefficients
%               y4=[A B];
%C		fy4    - residual power in clear air (estimated - measured) (W)   
%C		R2     -  R-squared from fit
%C		ci     - confidence interval on y4
%C		kk     - indices of points determined clear air
%C  
%C  By Al Rodi, UWyoming, 8/27/2020


%options=optimoptions('lsqnonlin','Display','off', ...
%'levenberg-marquardt''
%'trust-region-reflective'
options=optimoptions('lsqnonlin', ...
    'Display','none', ...
    'Algorithm','trust-region-reflective', ...
    'MaxIter',1001, ...
    'TolFun',1e-6, ...
    'TolX',1e-6 );
LB(1)=1e-6;
LB(2)=.1;
UB(1)=1e-3;
UB(2)=1;

C=phycon;
Tzero=C.Tzero;
%C		coef - constant coefficient for Re/Nu relation [dim]
%C		slope - exponent for Re (i.e. Re.^slope)
D=0.0019;
L=0.0200;
area=L*D;
twire=150+Tzero;
tairK=tair;
tfilm=(twire+tairK)/2;

power_on=6; % [W] detects system "on"
% Factor to convert power to LWC g/m3
[fact]=get_fact(area,tairK,tas,ps);

%
% First  get rough lwc100 values
%
nn0=numel(q_impact(find(q_impact>40)));
kk0=find(q_impact>40 & power > power_on );
%
A=1e-4;
B=0.60;
%%%%[fy4,y4,dryp4,xfact1,xfact2,xfact3]=nu_re_fit0([A,B],D,L,power(kk0),tairK(kk0),twire,tas(kk0),ps(kk0));
[fy,y4,dryp,xfact1,xfact2,xfact3]=nu_re_fit0([A,B],D,L,power(kk0),tairK(kk0),twire,tas(kk0),ps(kk0));
plwc0=(power(kk0)-dryp).*fact(kk0);

% Default to be used if analysis does not work
%
A=1.051e-004;
B=.5294;

% But start with just a guess
A=1e-4;
B=0.60;

R2=[];clear_air=[];y4=[];kk=[];
if(numel(kk0)/nn0>0.1);% On for  >10% of flight   
% Find clear air points iteratively

    % Rough cut. Eliminate high LWC
    [n,x]=hist(power(kk0),500);
    [y,i]=max(n);
    klear=x(i);
    klear1=klear-1;
    klear2=klear+1;
    gg=find(power(kk0)>klear1 &power(kk0)<klear2 );
    kk1=kk0(gg);
    
    [y1,~,res1]=lsqnonlin('nu_re_fit0',[A B],[],[],options,D,L,power(kk1),tairK(kk1),twire,tas(kk1),ps(kk1));
    [fy,y1,dryp,xfact1,xfact2,xfact3]=nu_re_fit0(y1,D,L,power(kk1),tairK(kk1),twire,tas(kk1),ps(kk1));
    plwc1=(power(kk1)-dryp).*fact(kk1);
    
    % Clip histogram
    [plwc1,irm,iout]=rmoutliers(plwc1,'percentiles',[20 80]);
    kk2=kk1(~irm);

    %
    % Do again with refined values 
    %
    [y2,~,res1]=lsqnonlin('nu_re_fit0',y1,[],[],options,D,L,power(kk2),tairK(kk2),twire,tas(kk2),ps(kk2));
    [fy,y,dryp,xfact1,xfact2,xfact3]=nu_re_fit0(y2,D,L,power(kk2),tairK(kk2),twire,tas(kk2),ps(kk2));
    %ci1 = nlparci(x1,res1,'jacobian',JACOBIAN);
    %[ci1(1,1),x1(1),ci1(1,2);ci1(2,1),x1(2),ci1(2,2)]
    plwc2=(power(kk2)-dryp).*fact(kk2);
    %
    % Refine clear air indices
    %
    [plwc2,irm,iout]=rmoutliers(plwc2,'percentiles',[5 95]);
    kk3=kk2(~irm);

    fun=@(beta,x) beta(1) + beta(2).*x;
    [BETA,R,J,CovB,MSE]  = nlinfit(xfact2,xfact3,fun,[0 1]);
    R2=(1-MSE./var(xfact3));
    clear_air=length(kk3)./orate/60;%minutes
    
    if(clear_air>10 & R2>.70)
        sprintf('LWC301 on and enough data for fit')
        %
        % Final calculation 
        %
        [y3,~,res1,~,~,~,JACOBIAN]=lsqnonlin('nu_re_fit0',y2,LB,UB,options,D,L,power(kk3),tairK(kk3),twire,tas(kk3),ps(kk3));
        [fy,y,dryp]=nu_re_fit0(y,D,L,power(kk3),tairK(kk3),twire,tas(kk3),ps(kk3));
        plwc=(power(kk3)-dryp).*fact(kk3);
        ci = nlparci(y,res1,'jacobian',JACOBIAN);
        
        [length(kk),length(kk0),clear_air,R2]
        sprintf('Length clear air = %g minutes',clear_air)
        %
        % Calculate for entire flight
        %
        kk=find(tas>50);
        plwc4=zeros(size(q_impact));
        [fy4,y4,dryp4]=nu_re_fit0(y3,D,L,power(kk),tairK(kk),twire,tas(kk),ps(kk));
        plwc4(kk)=(power(kk)-dryp4).*fact(kk);
        return
    end
end

% Else, use defaults
%
twire=150+Tzero;
% Default value of coefficients
    A=1.051e-004;
    B=.5294;
    y4=[A,B];
[fy4,y4,dryp4,xfact1,xfact2,xfact3]=nu_re_fit0(y4,D,L,power,tairK,twire,tas,ps);
plwc4=(power-dryp4).*fact;
fact4=fact;
ci=0;
R2=0;
zz=find(power<power_on);
plwc4(zz)=0.;
fact(zz)=0;
dryp4(zz)=0;
fy=0;
R2=0;
ci=0;
kk=[];

end




