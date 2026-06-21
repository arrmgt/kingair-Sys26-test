blurf=ncread(X.RawPath,'DP1');DP1=blurf(:);
blurf=ncread(X.RawPath,'DP2');DP2=blurf(:);
blurf=ncread(X.RawPath,'PSA');PSA=blurf(:);
blurf=ncread(X.RawPath,'PSB');PSB=blurf(:);
blurf=ncread(X.RawPath,'PTB');PTB=blurf(:);


PTOTA=DP1+PSA;
PTOTB=DP2+PSB;
kk=2e4:10e4;
plot([1:numel(kk)]/60,[PTOTB(kk)-PTOTA(kk),PTB(kk)-PTOTA(kk)])
ylabel('PTOT differences [hPa]')
xlabel('Time [min]')
title('20260607_raw.nc')
grid
legend('PTOTB-PTOTA','PTB-PTOTA','Location','southeast')
title('20260617\_raw.nc')
saveas(gfc,'Ptots.jpg')
