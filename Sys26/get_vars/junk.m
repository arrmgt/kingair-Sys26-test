b=kaiser_lp(1000,12.5,10,.01,80);
fields = fieldnames(raw);
for i = 1:numel(fields);
    figure(i)
    x = raw.(fields{i});
    xf = filtfilt(b,a,x);
    [pp,ff]=spec(x(zz1000),xf(zz1000),[4096,2*4096,1/1000]);
        loglog(ff,pp(:,1),ff,pp(:,2)), grid
    PP.(fields{i})=pp;
    FF.(fields{i})=ff;
    legend("Raw","Filtered","fontsize",15,'FontWeight','bold');
    xlabel('Frequency [Hz]','fontsize',15)
    ylabel('PSD variance/freq unit','fontsize',15,'FontWeight','bold');
    ss = sprintf("20260408b: %s 1000 Hz",fields{i});
    title(ss,,'fontsize',15,'FontWeight','bold')
    axis([v(1) v(2) 1e-10, 1e-2])
end