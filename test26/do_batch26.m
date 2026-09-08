function X = do_batch26(RawFile, varargin)
%DO_BATCH26 Batch-process a King Air raw netCDF file into a Sys26 archive.
%   X = DO_BATCH26(RAWFILE) processes RAWFILE (a "*_raw.nc" file) using
%   the default options listed below, and returns X: the struct of
%   resolved options (from inputParser) used for the run, plus the
%   derived fields described under Output.
%
%   X = DO_BATCH26(RAWFILE, 'Name', Value, ...) overrides any of the
%   options below. Name/Value pairs are case-insensitive and may be
%   abbreviated (standard inputParser matching rules).
%
%   Example:
%       X = do_batch26('20260710b_raw.nc', 'PROJ','test26', ...
%               'Rate',30, 'BaseOut','20260710b', ...
%               'Repo','C:\Users\alfre\Github\kingair-Sys26-test');
%
%   ------------------------------------------------------------------
%   General
%   ------------------------------------------------------------------
%     PROJ        (string,  default "test26")
%                 Project/campaign subdirectory name (under Repo).
%     Rate        (numeric, default 1)
%                 Output processing rate, in Hz.
%     BaseOut     (string,  default "")
%                 Output archive basename, e.g. BaseOut.c1.nc.
%     FillValue   (numeric, default -32767)
%                 Fill value used for missing data.
%
%   ------------------------------------------------------------------
%   Calculation variables (raw variable names used as inputs)
%   ------------------------------------------------------------------
%     TempUsed    (string,  default "TROSE")
%                 Temperature variable used in airspeed/other calcs.
%     PressUsed   (string,  default "ps_ship")
%                 Static pressure variable.
%     PcorUsed    (string,  default "ship_pcor")
%                 Static pressure correction variable. In practice this
%                 should always be left as "ship_pcor". Also used to
%                 derive DP1Used/QUsed below (dp1_<prefix>, q_<prefix>,
%                 where <prefix> is the part of PcorUsed before "_").
%     NOpcor      (logical, default false)
%                 If true, skip the pressure correction step.
%
%     rmOutliers  (logical, default false)
%                 If true, remove outliers in raw measurements
%
%   ------------------------------------------------------------------
%   POS/PAC (Applanix) processing
%   ------------------------------------------------------------------
%     POSPAC      (logical, default false)
%                 Process Applanix POS/PAC navigation data.
%     PPonly      (logical, default false)
%                 If true, run only the POS/PAC processing step.
%     locPP       (string,  default "av410out")
%                 Subdirectory (under PROJ) holding POS/PAC data.
%
%   ------------------------------------------------------------------
%   Paths  (defaults depend on platform: Windows vs. medicinebow/Linux;
%           see the OS-specific blocks in the code for exact values)
%   ------------------------------------------------------------------
%     SYS         (string) Set automatically to "windows" or
%                 "medicinebow" from computer("arch"). Not normally
%                 passed explicitly by the caller.
%     Data        (string) Root directory containing raw *_raw.nc files.
%     Repo        (string) Path to the kingair-Sys26 repository (must
%                 contain a PROJ subdirectory and a Sys26 subdirectory).
%     ncLOC       (string, default "Data") Name of the X field that
%                 supplies the output location; output is written under
%                 X.(ncLOC)/PROJ/work.
%     scratchDir  (string) Scratch/temporary working directory.
%     aster       (string) ASTER elevation data directory.
%     egm         (string) EGM (geoid) data directory.
%
%   ------------------------------------------------------------------
%   Output
%   ------------------------------------------------------------------
%     X   Struct containing all resolved options above, plus:
%           X.RawFile   the RAWFILE argument
%           X.procRate  = X.Rate
%           X.Home      = fullfile(X.Repo, X.PROJ)
%           X.Source    = fullfile(X.Repo, 'Sys26')
%           X.DP1Used   = "dp1_" + <prefix of PcorUsed before "_">
%           X.QUsed     = "q_"   + <prefix of PcorUsed before "_">
%
%     A copy of X is also saved to Xvalues.mat in the current directory
%     before further defaults are applied by Defaults0.
%
%   See also DEFAULTS0, INPUTPARSER.

% ----------------------------------------------------------------------
% Reset path/workspace state so each run starts from a known baseline.
% ----------------------------------------------------------------------
cleanup
restoredefaultpath
clear functions
osType = lower(computer("arch"));

%% Parse inputs
p = inputParser;   % defaults shown below apply unless overridden by caller

% --- General ----------------------------------------------------------
addParameter(p, "PROJ",      "test26",     @(s)ischar(s)||isstring(s));
addParameter(p, "Rate",      1,            @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, "BaseOut",   "",           @(s)ischar(s)||isstring(s));
addParameter(p, "FillValue", -32767,       @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, "rmOutliers", false,       @(s)islogical(s));

% --- Calculation variables ---------------------------------------------
addParameter(p, "TempUsed",   "TROSE",      @(s)ischar(s)||isstring(s));
addParameter(p, "PcorUsed",   "ship_pcor",  @(s)ischar(s)||isstring(s));  % always ship_pcor
addParameter(p, "PressUsed",  "ps_ship",    @(s)ischar(s)||isstring(s));
addParameter(p, "NOpcor",     false,        @(s)islogical(s));

% --- POS/PAC (Applanix) -------------------------------------------------
addParameter(p, "POSPAC",    false,        @(s)islogical(s));
addParameter(p, "PPonly",    false,        @(s)islogical(s));
addParameter(p, "locPP",     "av410out",   @(s)ischar(s)||isstring(s));

% --- Platform-dependent paths --------------------------------------------
if contains(osType, "win64")
    addParameter(p, "SYS",        "windows", @(s)ischar(s)||isstring(s));
    addParameter(p, "Data",       "E:\MATLAB-DATA2\kingair_data\",              @(s)ischar(s)||isstring(s));
    addParameter(p, "ncLOC",      "Data",                                       @(s)ischar(s)||isstring(s));
    addParameter(p, "Repo",       "C:\Users\alfre\Github\kingair-Sys26-work",   @(s)ischar(s)||isstring(s));
    addParameter(p, "scratchDir", "E:\MATLAB-DATA2\kingair_data\scratch\",      @(s)ischar(s)||isstring(s));
    addParameter(p, "aster",      "E:\MATLAB-DATA2\kingair_data\",              @(s)ischar(s)||isstring(s));
    addParameter(p, "egm",        "E:\MATLAB-DATA2\kingair_data\",              @(s)ischar(s)||isstring(s));
else
    addParameter(p, "SYS",        "medicinebow", @(s)ischar(s)||isstring(s));
    addParameter(p, "Data",       "/cluster/alcova/kingairfacility/kingair_data/", @(s)ischar(s)||isstring(s));
    addParameter(p, "ncLOC",      "Data",                                         @(s)ischar(s)||isstring(s));
    addParameter(p, "Repo",       "/home/rodi/kingair-Sys26-work",                @(s)ischar(s)||isstring(s));
    addParameter(p, "scratchDir", "/gscratch/rodi/",                             @(s)ischar(s)||isstring(s));
    addParameter(p, "aster",      "/cluster/alcova/kingairfacility/kingair_data/", @(s)ischar(s)||isstring(s));
    addParameter(p, "egm",        "/cluster/alcova/kingairfacility/kingair_data/", @(s)ischar(s)||isstring(s));
end

p.parse(varargin{:});
X = p.Results;
X.RawFile = RawFile;
addpath('../Sys26/config');

%% Derived fields
X.procRate = X.Rate;
X.Home     = fullfile(X.Repo, X.PROJ);
X.Source   = fullfile(X.Repo, 'Sys26');

% Measurement names derived from PcorUsed, e.g. "ship" from "ship_pcor"
pcor      = extractBefore(X.PcorUsed, '_');
X.DP1Used = "dp1_" + pcor;
X.QUsed   = "q_"   + pcor;

%% Set MATLAB search path
addpath(X.Repo);
addpath(X.Source);
addpath(fullfile(X.Source, 'get_vars'));
addpath(fullfile(X.Source, 'get_vars/utilities'));
addpath(fullfile(X.Source, 'get_vars/av410imu'));
addpath(fullfile(X.Source, 'get_vars/gps_funs'));
addpath(fullfile(X.Source, 'get_vars/mfiles858'));
addpath(fullfile(X.Source, 'get_vars/lwc301_funs'));
addpath(fullfile(X.Source, 'get_vars/vapor_press_functions'));
addpath(fullfile(X.Source, 'config/udunits-windows'));
addpath(fullfile(X.Source, 'config/udunits-linux'));

%% Save inputs and apply remaining defaults
save('Xvalues.mat', 'X');
X = Defaults0(X);
