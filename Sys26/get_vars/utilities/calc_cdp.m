function [ACDP,CCDP,CDPTot,CDPConc,CDPDbar,CDPLWC,CDPReff,frate]= ...
calc_cdp(ncFINAL,MNAME,CNAME,irate,orate, ...
tasXX,ACDP_raw,FirstBin,LastBin,SerialNumber,SampleArea, ...
SampleAreaUnits,CellEdges,Threshold);

[mm,nn,ncells] = size(ACDP_raw);
ACDP_raw=double(ACDP_raw);
if(orate>irate); frate=irate;else;frate=orate; end %limit frate to irate

ncwriteatt(ncFINAL,MNAME,'FirstBin',FirstBin,'DataType','int32'); %takes into account extra channel for NCAR compatibility
ncwriteatt(ncFINAL,MNAME,'LastBin',LastBin,'DataType','int32');
ncwriteatt(ncFINAL,CNAME,'FirstBin',FirstBin,'DataType','int32');
ncwriteatt(ncFINAL,CNAME,'LastBin',LastBin,'DataType','int32');

ncwriteatt(ncFINAL,MNAME,'SerialNumber',SerialNumber);
ncwriteatt(ncFINAL,CNAME,'SerialNumber',SerialNumber);

ncwriteatt(ncFINAL,MNAME,'SampleArea',SampleArea);
ncwriteatt(ncFINAL,CNAME,'SampleArea',SampleArea);

ncwriteatt(ncFINAL,MNAME,'SampleAreaUnits',SampleAreaUnits);
ncwriteatt(ncFINAL,CNAME,'SampleAreaUnits',SampleAreaUnits);

ncwriteatt(ncFINAL,MNAME,'CellSizes',CellEdges,'DataType','single');
ncwriteatt(ncFINAL,CNAME,'CellSizes',CellEdges,'DataType','single');

ncwriteatt(ncFINAL,MNAME,'Threshold',Threshold,'DataType','int32');
ncwriteatt(ncFINAL,CNAME,'Threshold',Threshold,'DataType','int32');

ss0=sprintf('Bins are indexed 0 - %i ',ncells);
ncwriteatt(ncFINAL,MNAME,'comment0',ss0);
ncwriteatt(ncFINAL,CNAME,'comment0',ss0);

ss1 = sprintf('Measured: %i bins (1-%i); ',ncells,ncells);
ncwriteatt(ncFINAL,MNAME,'comment1',ss1);
ncwriteatt(ncFINAL,CNAME,'commentf1',ss1);

ss2 = sprintf('Bin 0 is empty (compatibility). Bins 1-%i contain accumulations from probe;',ncells);
ncwriteatt(ncFINAL,MNAME,'comment2',ss2);
ncwriteatt(ncFINAL,CNAME,'comment2',ss2);

ss4 = sprintf('FirstBin=%i, LastBin=%i; Those bins are used for concentration calculations;',FirstBin,LastBin);
ncwriteatt(ncFINAL,MNAME,'comment4',ss4);
ncwriteatt(ncFINAL,CNAME,'comment4',ss4);

ss5=sprintf('CellSizes are bin edges for bin 1-%i (lower edge of bin 1 is uncertain).',ncells);
ncwriteatt(ncFINAL,MNAME,'comment5',ss5);
ncwriteatt(ncFINAL,CNAME,'comment5',ss5);

% Process the CDP data
blurf=reshape(permute(ACDP_raw,[1 2 3]),nn*mm,ncells);%reorder time dims
kk=find(blurf<0);blurf(kk)=0;

[minterp,mdecim]=interp_decim(irate,frate);
%Shift the data 1/2 of rate
nsYY  = floor(1 + mdecim/2);
blurf = cumsum(blurf,1);
blurf = diff([zeros(1,ncells);blurf(nsYY:mdecim:end,:)],1,1);% at frate 

[minterp,mdecim]=interp_decim(orate,frate);
Tas=changeRate(tasXX,orate,frate);

CDP_SV = (SampleArea*1.e-2)*(Tas*1.e2);  %per second

%add one to number of channels for compatability with NCAR software
ncells1   = ncells+1;
SV30 = CDP_SV(:,ones(ncells1,1));

DCDP = [0 mean([CellEdges(1:end-1);CellEdges(2:end)])];

%
% Add zero channel for NCAR software
ACDP  = zeros(size(blurf,1),ncells1);
ACDP(:,2:end)=blurf; %number in each cell, first empty
CCDP  = frate.*ACDP ./ SV30;
zz=find(SV30 < 10*SampleArea);
CCDP(zz) = 0;	% Set values for TAS < 10 m/s to zero

% add 1 to bin numbers (Header uses 0:29 for bin numbers)
% FirstBin and LastBin come from processing (var*.cdl)
% (_raw.nc file has all bins indicated from 0-29).
bbs=[FirstBin+1:LastBin+1];

mom0 = sum(CCDP(:,bbs),2);
mom1 = CCDP(:,bbs) * DCDP(bbs)';
mom2 = CCDP(:,bbs) * power(DCDP(bbs)',2);
mom3 = CCDP(:,bbs) * power(DCDP(bbs)',3);

CDPTot        = sum(ACDP(:,bbs),2);
CDPConc       = mom0;
CDPDbar       = mom1 ./ mom0; 
CDPDbar(find(isnan(CDPDbar))) = 0;
CDPLWC        = pi./6. * mom3 * (1.e-12*1.)*(1.e6);
CDPReff       = mom3 ./ mom2 /2;
CDPReff(isnan(CDPReff)) = 0.;

return


