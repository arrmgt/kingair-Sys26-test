function [zgeoid,ZZ,R]=get_geoid(ZPATH,lat,lon,FillValue);
%P5
%# Geoid file in PGM format for the GeographicLib::Geoid class
%# Description WGS84 EGM2008, 1-minute grid
%# URL http://earth-info.nga.mil/GandG/wgs84/gravitymod/egm2008
%# DateTime 2009-08-31 06:54:00
%# MaxBilinearError 0.025
%# RMSBilinearError 0.001
%# MaxCubicError 0.003
%# RMSCubicError 0.001
%# Offset -108
%# Scale 0.003
%# Origin 90N 0E
%# AREA_OR_POINT Point
%# Vertical_Datum WGS84
%21600  10801
%65535
Offset= -108;
Scale= 0.003;
Latmax=90.;
Lonmin=0.;
fname=fullfile(ZPATH,'egm2008-1.pgm');
zz=imread(fname);
ZZ=double(zz)*Scale+Offset;

del=1/60;
%R=makerefmat('RasterSize',size(ZZ),'Latlim', [-90 90], 'Lonlim', [0 360-del], ...
%  'ColumnsStartFrom','north'); %removed from R2023b
R = georefcells([-90 90],[0 360-del],size(ZZ));


kk=find(lat~=FillValue);
zgeoid=FillValue*ones(size(lat));
%zgeoid(kk)=ltln2val(ZZ,R,'bicubic'); %removed R2023b
zgeoid(kk) = geointerp(ZZ,R,lat(kk),lon(kk)+360,'cubic');

