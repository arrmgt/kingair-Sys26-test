function X=do_batch26(RawFile,varargin)
% do_batch25 - batch processing of King Air data"; 
% X = do_batch26(RawFile,Name,Value,....)
% Required: Raw file name
% do_batch25("20180802a_raw.nc","Project","bbflux18"); % defaults for 1 Hz run 
% Options (Name,Value) pairs and defaults (examples)
%   "Project"       ("shakedown26")            : Starting directory (normally PWD)
%   "Rate"          (25)                    : Processing Rate
%   "BaseOut"       ("20180802_arr)         : Archive file name 
%   "PosPac"        (true)                  : Process applanix data
%   "AVdata"        ("av410out")            : Subdirectory with pospac data
%   "DataRoot"      ("L:/kingair_data")     : Data file directory
%   "FillValue"     (-32767)                : Missing data fill value  
% Output nc file basename (for example, use BaseOut.c1.nc)
%   "BaseOut"  "20180802_arr", @(s)ischar(s)||isstring(s));
% Primary variables used in airspeed and other calculations
%   "TempUsed"      "trose"                 : Default temp
%   "PressUsed"     "ps_boom"               : Default static press   
%   "DP1Used"       "DP2"                   : Default DP1 
%   "scratchDir"    "L:/temp"               : Default temporary data dir
%   "DataRoot"      "L:/kingair_data"       : Default data root
% ---------- Parse inputs ----------
cleanup
osType = lower(computer("arch"));
p = inputParser; % Defaults are shown if not set in commmand line
addParameter(p, "PROJ", "shakedown26", @(s)ischar(s)||isstring(s));
addParameter(p, "Rate", 1, @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, "FillValue", -32767, @(x)isnumeric(x)&&isscalar(x)&&x>0); 
% Variables used in calculations (their raw variable names)
addParameter(p, "TempUsed",  "trose", @(s)ischar(s)||isstring(s));
addParameter(p, "PressUsed", "ps_boom", @(s)ischar(s)||isstring(s));
addParameter(p, "DP1Used",   "dp1_boom", @(s)ischar(s)||isstring(s));
addParameter(p, "QUsed",     "q_impact", @(s)ischar(s)||isstring(s));
% working subdirectory name for PP files
addParameter(p, "POSPAC", true, @(s)islogical(s));
addParameter(p, "locPP", "av410out", @(s)ischar(s)||isstring(s));
% Output nc file basename (for example, instead of 20180802.cXX.nc)
addParameter(p, "BaseOut", "", @(s)ischar(s)||isstring(s));
if(contains(osType,"win64"));
    addParameter(p, "SYS",("windows"),@(s)ischar(s)||isstring(s));
    % Raw data file location (*_raw.nc)
    addParameter(p, "Data","P:\MATLAB-DATA2\kingair_data\",@(s)ischar(s)||isstring(s));
    % Final ncfile will be on X.ncLOC/PROJ/work
    addParameter(p, 'ncLOC', 'Data', @(s)ischar(s)||isstring(s));
    addParameter(p, "Repo","C:\Users\rodi\Github\kingair-Sys26-test",@(s)ischar(s)||isstring(s));
    addParameter(p, "scratchDir","P:\MATLAB-DATA2\kingair_data\scratch\", @(s)ischar(s)||isstring(s));
    addParameter(p, "aster", "P:\MATLAB-DATA2\kingair_data\", @(s)ischar(s)||isstring(s));
    addParameter(p, "egm", "P:\MATLAB-DATA2\kingair_data\", @(s)ischar(s)||isstring(s));
else
    addParameter(p, "SYS",("medicinebow"),@(s)ischar(s)||isstring(s));
    % Raw data file location (*_raw.nc)
    addParameter(p, "Data","/cluster/alcova/kingairfacility/kingair_data/",@(s)ischar(s)||isstring(s));
    % Final ncfile will be on X.ncLOC/PROJ/work
    addParameter(p, 'ncLOC', 'Data', @(s)ischar(s)||isstring(s));
    addParameter(p, "Repo","/home/rodi/kingair-Sys26-test",@(s)ischar(s)||isstring(s));
    addParameter(p, "scratchDir", "/gscratch/rodi/", @(s)ischar(s)||isstring(s));
    addParameter(p, "aster","/cluster/alcova/kingairfacility/kingair_data/", @(s)ischar(s)||isstring(s));
    addParameter(p, "egm","/cluster/alcova/kingairfacility/kingair_data/", @(s)ischar(s)||isstring(s));
end
p.parse(varargin{:});
X = p.Results;
X.RawFile=RawFile;
addpath('../Sys26/config');

% Add some items
X.procRate = X.Rate
X.Home = fullfile(X.Repo,X.PROJ);
X.Source = fullfile(X.Repo,'Sys26');

addpath(X.Repo);
addpath(X.Source)
addpath(fullfile(X.Source,'get_vars')); 
addpath(fullfile(X.Source,'get_vars/utilities'));
addpath(fullfile(X.Source,'get_vars/av410imu')); 
addpath(fullfile(X.Source,'get_vars/gps_funs'));
addpath(fullfile(X.Source,'get_vars/av410imu'));
addpath(fullfile(X.Source,'get_vars/mfiles858'));
addpath(fullfile(X.Source,'get_vars/lwc301_funs'));
addpath(fullfile(X.Source,'get_vars/vapor_press_functions'));
addpath(fullfile(X.Source,'config/udunits_windows'));
addpath(fullfile(X.Source,'config/udunits_linux'));

X = Defaults0(X);
