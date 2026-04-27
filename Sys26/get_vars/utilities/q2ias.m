function ias=q2ias(q);
%       R by CP
C=phycon();
% Eta=Cpd/Cpv
Eta=C.Cpd/C.Cvd;
% k=Rd/Cpd
k=C.Rd/C.Cpd;
% Specific heat at constant pressure
Cpd=C.Cpd;

% REFERENCE POINT FOR ICAO STANDARD ATMOSPHERE
TSTP=C.Tstp;
PSTP=C.pstp;

%C TO KNOTS FROM M/SEC

blurf = 2..*Cpd.*TSTP.*((1.+q./PSTP).^k-1.);
ias=zeros(length(q),1);
kkk=find(blurf>5.);
ias(kkk)=convertUnits(sqrt(blurf(kkk)),'m/s','knots');
return

