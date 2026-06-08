function [x,x0]=dataAV410(fname);
%dataAV410: get IMU data from Applanix AV410 IMU/GPS.
%Project $Name: trans2am21_qc0 $ ($Revision: 1.1 $)
%$Date: 2011/10/09 22:47:43 $
%Rev='$Name: trans2am21_qc0 $ $RCSfile: dataAV410.m,v $ $Revision: 1.1 $';
%
% Input:  file name of POSPac *.out file
% Output: Array(reclen,nn)
%
% Assumed format
% CONTENTS
% time			seconds
% latitude		radians
% longitude		radians
% altitude		meters
% x velocity		meters/sec
% y velocity		meters/sec
% z velocity		meters/sec
% roll			radians
% pitch			radians	
% platform heading	radians
% wander angle		radians
% x body accel		meters/sec2
% y body accel		meters/sec2
% z body accel		meters/sec2
% x body angular rate	radians/sec
% y body angular rate	radians/sec
% z body angular rate	radians/sec

fname=string(fname);
reclen=17;

fid=fopen(fname,'r');
x0=fread(fid,'real*8');
[mm,nn0]=size(x0');
nn=floor(nn0/reclen); %just in case of partial record at end
x=reshape(x0(1:nn*reclen)',reclen,nn);
fid=fclose(fid);

end