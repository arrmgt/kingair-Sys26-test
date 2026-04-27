function z = srtmHeights( p, lats, lons )
%SRTMHEIGHTS: get the height from SRTM binary files
%$Source: /home/cvs/kingair/Sys09/srtmHeights.m,v $
%Project $Name:  $ ($Revision: 1.11 $)
%$Date: 2023/04/10 18:06:19 $
% function z = srtmHeights( p, lats, lons )
%
% This function get the height from SRTM binary files which contain 16 bit,
% big endian values of the terrain height in meters.
%
% Input values
%   p - path of the SRTM data files, they should be named NttEnnn.hgt
%         N   is N or S for northern or southern hemisphere
%         tt  is the latitude of the lower left corner
%         E   is E or W for eastern or western hemisphere
%	  nnn is the longitude of the lower left corner
%  lats - array of latitudes (N is positive)
%  lons - array of longitudes (E is positive)
%         lats and lons must be the same size
%
% Output values
%   z - height of the terrain in meters - missing values set to -32767
%
% Data wasdownloaded from http://dds.cr.usgs.gov/srtm/version2_1;
%
% History
%   2005/01 LDO written
%   2010/04 LDO Modified to use USGS http site
%               Added Eurasia in the 3 arcsec data
%   2010/10 LDO Added aster data
%   2019/11 LDO Added aster version 3 data
%

server = 'http://dds.cr.usgs.gov/srtm/version2_1';

%
% One arcsecond files for the US are stored in seven different regions
% given by the following boundaries
%
srtm1_regions = [ 38, -126, 49, -112; ...
                  38, -111, 49,  -98; ...
                  38,  -97, 49,  -84; ...
                  28, -123, 37, -101; ...
                  25, -100, 37,  -84; ...
                  17,  -83, 47,  -65; ...
                   0, -179, 59, -130 ];

%
% Test if inputs are reasonable
%
if nargin ~= 3; 
  error('Usage: srtmHeight(p,lats,lons)'); 
  return; 
end
if size(lats) ~= size(lons); 
  error('srtmHeights: size of lats and lons must be the same.');
  return;
end
if ( min(lats) < -90 ) 
  error('srtmHeights: Latitudes must be greater than -90');
  return;
end
if ( max(lats) > 90 ) 
  error('srtmHeights: Latitudes must be less than 90');
  return;
end
if ( min(lons) < -180 ) 
  error('srtmHeights: Longitudes must be greater than -180');
  return;
end
if ( max(lons) > 360 ) 
  error('srtmHeights: Longitudes must be less than 360');
  return;
end

% Preset heights to -32767
z = -32767 * ones(size(lats));
if ( size(z) == 0 ); return; end

% Wrap longitudes to -180 to 180 degrees
ii = find(lons>180);
lons(ii) = lons(ii)-360;

latdirs = 'SN';
londirs = 'WE';

% Files are stored in 1 degree tiles
for x = floor(min(lons)):floor(max(lons))
  for y = floor(min(lats)):floor(max(lats))

% Find which points are in this tile
    ii = find( lons >= x & lons <= x+1 & lats >= y & lats <= y+1 );
    if ~ isempty(ii)
% Generate the local file name of the data
      if strfind(p,'aster')
% Look for version 3
        file = sprintf('%s/ASTGTMV003_%c%02d%c%03d_dem.tif', ...
          p, latdirs((y>=0)+1), abs(y), londirs((x>=0)+1), abs(x));
% If not found, try version 2
        if ~exist(file,'file')
          file = sprintf('%s/ASTGTM2_%c%02d%c%03d_dem.tif', ...
            p, latdirs((y>=0)+1), abs(y), londirs((x>=0)+1), abs(x));
        end
% If not found, try version 1
        if ~exist(file,'file')
          file = sprintf('%s/ASTGTM_%c%02d%c%03d_dem.tif', ...
            p, latdirs((y>=0)+1), abs(y), londirs((x>=0)+1), abs(x));
        end
        try
          height = imread(file);
          %%%%disp(['Getting terrain heights from ' file]) %debug
          height(height==-9999) = -32767;
          height = height';
          pts = size(height,1);
        catch me;
          disp(['Unable to read heights from ' file]); 
          continue;
        end
      else
        file = sprintf('%s/%c%02d%c%03d.hgt', ...
          p, latdirs((y>=0)+1), abs(y), londirs((x>=0)+1), abs(x));
% Open the file. If there is an error, try downloading it from the FTP server
        fid = fopen([file '.zip'],'r','b');
        if ( fid < 0 )
  	  [pathstr name ext] = fileparts(file);
	  remfile = [name ext '.zip'];
	  %%%%disp(['Downloading ' remfile]), %debug
	  try
% Section for 1 arcsecond data, path name contains the string 'srtm-1'
	    if ~ isempty(strfind(p,'srtm-1'))
              for i = 1:7
                if ( y >= srtm1_regions(i,1) & ...
                     x >= srtm1_regions(i,2) & ...
                     y <= srtm1_regions(i,3) & ...
                     x <= srtm1_regions(i,4) )
	          url = sprintf('%s/SRTM1/Region_%02d/%s',server,i,remfile);
                end
              end
% else change directory to 3 arcsecond data
	    else
              if x >= -14 & y >= 35 & y < 61,  % Extends only to 61 degrees north
	        url = sprintf('%s/SRTM3/Eurasia/%s',server,remfile);
              else
	        url = sprintf('%s/SRTM3/North_America/%s',server,remfile);
              end
	    end
            urlwrite(url,[file '.zip']);
	    %%%%disp(['Downloaded ' url]), %debug
	  catch
	    disp(['Unable to get ' url])
	  end
          fid = fopen([file '.zip'],'r','b');
        end
% Print an error if it still doesn't exist
        if fid<0
          disp([file ' not found.'])
          continue;
        else
          disp(['Getting terrain heights from ' file '.zip']);
          fclose(fid);
% Unzip the file
          unzip([file '.zip'],p);
% Read in the data, it is stored as 16 bit, big endian integers
% 'b' option specifies big endian
          fid = fopen(file,'r','b');
          [height,count] = fread(fid,inf,'int16');
          fclose(fid);
% Data is unzipped and read in, delete temporary unzipped file
          system(['rm ' file]);
% Assume the matrix is square, reshape it
          pts = sqrt(count);
          height = reshape(height,pts,pts);
        end
      end
% The tiles are inclusive with points defined on all sides
% Get the '1' based indices of the points in the matrix
% Row starts from the top, column starts from the left
      ix = round((lons(ii) - x)*(pts-1)) + 1;
      iy = pts - round((lats(ii) - y)*(pts-1));
% Read in the values for this tile
      for jj=1:length(ii)
        z(ii(jj)) = height(ix(jj),iy(jj));
      end
    end
  end
end
