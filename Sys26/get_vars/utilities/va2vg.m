function [vg,ttt]=va2vg(att,va);
%VA2VG: converts air-relative to ground-relative velocity
% 
% Inputs (here NT = time dimension)
% att  is attitude matrix [3xNT]
% va   is air-relative velocity [NTx3]

if(nargin == 2)
    % get transformation matrix ttt
    [ttt,tttp]=vtrans_0(att); % ttt is [3x3xNT]
    %%%%VG=multiprod(ttt,va',[1,2],1); % before matlab R2020
    y = pagemtimes(ttt, reshape(va',3,1,[])); % y is [3x1xNT]
    y = squeeze(y);    % 3 x NT
    vg=y;
else
    '%function [vg]=va2vg(att,va);'
	    error('va2vg: 3 args needed')
end

