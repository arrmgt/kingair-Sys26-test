function [y]=changeRate(x,irate,orate);
%function [y]=changeRate(x,R,type,FillValue);
%    Y = DECIMATE(X,R,FOUT) 
%    Decimates X by R. Designs a FIR filter so that 
%    Fnyquist is in the passband.
%    If R > 10, decimates in steps as advised by matlab
%    than 13, DECIMATE will produce a warning regarding the unreliability of
%    the results.  See NOTE below.
%    NOTE:   Uses changeRate only in the last step.

[x, tf] = fillmissing(x,'previous');
if ~isempty(find(tf))
    error('changeRate: data not clean');
end

y = changeRate(x,irate,orate);

end