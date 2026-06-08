function [x,x0]=rmsAV410(fname);
%dataAV410: get IMU rms estimates from Applanix AV410 IMU/GPS.
%Project $Name: trans2am21_qc0 $ ($Revision: 1.1 $)
%$Date: 2011/10/09 22:47:43 $
%Rev='$Name: trans2am21_qc0 $ $RCSfile: rmsAV410.m,v $ $Revision: 1.1 $';
%
% Input:  file name of POSPac *.out file
% Output: Array(reclen,nn)
%
% Assumed format
% CONTENTS
% time				seconds
% North position RMS error	meters
% East position RMS error	meters
% Down  position RMS error	meters
% North velocity RMS error	meters
% East velocity RMS error	meters
% Down  velocity RMS error	meters
% Roll RMS error		arc-minutes
% Pitch RMS error		arc-minutes
% Heading RMS error		arc-minutes

reclen=10;

%sprintf('opening %s',fname)
fid=fopen(fname,'r');
x0=fread(fid,'real*8');
[mm,nn0]=size(x0');
nn=floor(nn0/reclen);
x=reshape(x0(1:nn*reclen)',reclen,nn);
fid=fclose(fid);

end
