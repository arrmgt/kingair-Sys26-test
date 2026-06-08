RawPath = "P:\MATLAB-DATA2\kingair_data\test26\work\20260408a_raw.nc";
info = ncinfo(RawPath);
RAWNAMES = {info.Variables.Name};   
isPresent = ismember(rawNames,RAWNAMES);
raw = struct();
PTB = getdata(RawPath,'PTB');
FillValue = ncreadatt(RawPath,'DP2','_FillValue');
kk  = find(PTB > 0 & PTB > FillValue ...
    & ~isnan(PTB)  & ~isinf(PTB)  ); % Accept
kk0 = [1:numel(PTB)]';               % All  
for k = 1:length(rawNames)
    var1 = char(rawNames(k));
    if isPresent(k)
        blurf = getdata(RawPath, var1);
        blurf = interp1(kk, blurf(kk), kk0, 'linear', NaN);
        % set left-of-first to first good point 
        %     and right-of-last to last good
        blurf(kk0 < kk(1))   = blurf(kk(1)); 
        blurf(kk0 > kk(end)) = blurf(kk(end));
        raw.(var1 ) = blurf;
    end
end

zz25=1.45e5:1.75e5;
freqs = [5,25,100,1000];
close all
for i = 1:numel(freqs);
    f=freqs(i);
    zz=round(zz25(1)*f/25:zz25(end)*f/25)e;
    TROSEf=changeRate(raw.TROSE,1000,f);
    p = nextpow2(2048*f/25);
    val = 2^p;
    [pp,ff]=spec(TROSEf(zz),[round(2048*f/25),val,1/f]);
    figure(i)
    loglog(ff,pp(:,1));
    title(sprintf("Rate = %i",f),'FontSize',10)
    grid
end