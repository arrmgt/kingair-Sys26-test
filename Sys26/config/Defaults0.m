function X=Defaults0(X)
%
% Continue to set defaults based on settings do_batch25
warning off

%************************
% Unidata udunits: unit conversion
%   Setup and test
%
%************************
if contains(X.SYS,'windows') 
    X.udunits = fullfile(X.Source,'config','udunits-windows');
elseif(contains(X.SYS,'medicinebow'))
    X.udunits = fullfile(X.Source,'config','udunits-linux')
end
addpath(X.udunits);
setenv("UDUNITS2_XML_PATH",fullfile(X.udunits,'xml_files','udunits2.xml'));
%  Make sure it works (if not, go to X.udunits directory 
%     and run "make mex". Then start run do_batch25 again.

try
    y=convertUnits(75,'Fahrenheit','Celsius');
    sprintf('Converted 75 deg Fahrenheit to Celsius, yielding %0.2f Celsius',y)
catch
    getenv("UDUNITS2_XML_PATH")
    error('Problem with udunits')
end

% Parse the basename for files
x=char(X.RawFile);
z=strfind(x,'_raw.nc')-1;
X.BaseName0=x(1:z);

if X.POSPAC % Process Applanix pospac data
    % Run sbet and rms data from applanix pospac?
    %   PosPac files are prefix_sbet.out and prefix_rms.out
    %   where prefix is nominally PROJ, and location is av410out
    %   forexample, files are
    %   fullfile("Data","PROJ","av410out",[PROJ,"_sbet.out"]);
    
    X.SBETbasename = "_sbet.*";
    basename=fullfile(X.Data,X.PROJ,'work',X.locPP,[X.BaseName0 + X.SBETbasename]);
    AVsbet=dir(basename);
    X.AVdata=fullfile(AVsbet.folder,AVsbet.name);
    
    X.RMSbasename = "_rms.*";
    basename=fullfile(X.Data,X.PROJ,'work',X.locPP,[X.BaseName0 + X.RMSbasename]);
    AVrms=dir(basename);
    X.AVrms=fullfile(AVsbet.folder,AVrms.name);
    
    % AVsbet
    if( ~isfile(X.AVdata) & X.POSPAC)
            "Will not use post-processed Applanix variables."
            "$AVsbet does not exist."
            X.POSPAC = false;
    end
    % AVrms
    if( ~isfile(X.AVrms)  & X.POSPAC)
        "Will not use post-processed Applanix variables."
        "$AVms does not exist."
        X.POSPAC = false;
    end
end

% Output file configuration
%  There are two xlsx spreadsheets used in configurati
%    1. "PROCESSED_VARS.xlsx" available broups of output variables
%           "TIME TAS HADS WESTON CPT AV410RT AV410PP AV410RMS
%               WINDRT WINDPP CDP CDP_1 LWC301 LWC100 PVMLWC"
%    2. "RAW_VAR.xlsx has variables recorded for those groups
%
% Fill_Value
X.FillValue=-32767;
    
% Input and Output mat file and archive file locations
X.Home=fullfile(X.Repo,X.PROJ);
% Raw data file location (*_raw.nc)
    X.RawPath=fullfile(X.Data,X.PROJ,'work',X.RawFile);
% Work directory
    X.workPath=fullfile(X.scratchDir,X.PROJ,'work');
% Output file locations
    X.Output=fullfile(X.scratchDir,X.PROJ,'work');
    mkdir(X.Output); 
    ss=sprintf("X.outputPath = fullfile(X.%s,X.PROJ,'work');",X.ncLOC);
        eval(ss)
    mkdir(X.outputPath);
    X.tempdir=fullfile(X.scratchDir,X.PROJ,'temp');
    delete(X.tempdir);
    mkdir(X.tempdir);
%    Final output file name
X.ncFINAL=fullfile(X.outputPath,sprintf('%s.c%i.nc',X.BaseOut,X.procRate));

% Determine which raw variables are needed given variables to be processed
% 
X.PWD=pwd;

%% 
if(isempty(X.BaseOut))
    z=strfind(X.RawFile,'_raw.nc')-1;
    X.BaseName=X.BaseName0;
else
    X.BaseName=X.BaseOut;
end

% mapping toolbox option
X.MAP=true;% always use matlab mapping toolbox

% Cleanup directories
delete(fullfile(X.tempdir,'*'));

% Output nc file base name (instead of basename in basename.cXX.nc)
if(isempty(X.BaseOut))
    RawFile = X.RawFile;
    z=strfind(RawFile,'_raw.nc')-1;
    X.BaseName=RawFile(1:(z-1));
else
    X.BaseName=X.BaseOut;
end

% Get project local gobal atts
% If not in X.Home, check config directory. Throw error if non-exit.
try
    X.localGlobalAtts = which('global_atts.txt');
catch
    error('global_atts.txt does not exist')
end

% Name of the variables database
X.varDB = fullfile(X.Home,'variablesXX.db');

% Which get_var* scripts need to be run??
% 'get_varTIME.m' and 'get_varTAS.m' are always run
% Use xlsx files and scan rawfile to identify variables that exist
X.configDir=fullfile(X.Source,'config');

% xlsfiles and DB file are saved in tar file, and retrieved.
%       [This is because of an unknown reason they are being corrupted??]
tarFile = fullfile(X.Home,'xlsfiles','tables.tar'); 
untar(tarFile,X.Home);
X.xlsraw=fullfile(X.Home,'RAW-VARS.xlsx');
X.xlsarc=fullfile(X.Home,'PROCESSED-VARS.xlsx');

% Consolidate groups from PROCESSED_VARS.xlsx and RAW_VARS.xlsx
%   to create the blank pivot table
%   with all possible measurents and output variables
%   sorted into measurement groups
%
[Pxlsx,Ptable,Txlsx,Ttable]=build_groups(X);
[nrow,ncol]=size(Ptable);

% Variable column names (measurement groups) for archiving 
cnames_arc=table2array(Ptable(:,1));

% Get column names which are measurement groups
opts_raw=detectImportOptions(Pxlsx);
cnames_raw=opts_raw.VariableNames;

%  Assume Applanix post-processed variables 
%   have names containing uppercase "PP" 
if ~X.POSPAC % remove Applanix post-processed groups
    % remove pospac variables from list for now
    % since they are not on *_raw.nc
    mask = ~contains(cnames_raw,["PP" "AV410RMS"]) ;
    cnames_raw = cnames_raw(mask);
end
X.rawGROUPS=sort(unique(cnames_raw(2:end)));

%  Cull when no raw data 
[Ptable, Ttable, keepGroups, gets] = isThereData(X.RawPath, X.varDB, X.rawGROUPS, Ptable, Ttable);
X.Ptable=Ptable; % Pivot table
X.Ttable=Ttable; 
X.rawGROUPS = unique(keepGroups);

% Column names of measurement groups
X.varnames=sort(unique(table2array(Ptable(:,1))))';

% Set the processing order for running modules
% 
gets0 = gets;
gets = string();
gets(1) = "get_varTIME(X)"; % Always first

% Need pressures first before TAS
if any(ismember(keepGroups,"CPT"))
    gets(end+1) = "get_varCPT(X)";
end
if any(ismember(X.rawGROUPS,"HADS"))
    gets(end+1) = "get_varHADS(X)";
end
if any(ismember(X.rawGROUPS,"WESTON"))
    gets(end+1) = "get_varWESTON(X)";
end
% Then always do get_varAV410RT and get_varTAS
gets(end+1) = "get_varAV410RT(X)";
gets(end+1) = "get_varTAS(X)";

% Add the rest
gets1 = gets0(~ismember(gets0,gets)) ;% Do multiple PCASP in one call to get_varPCASP
gets1 = strrep(gets1, "PCASP1", "PCASP");
gets1 = strrep(gets1, "PCASP2", "PCASP");

% combine whats left
gets= [gets gets1];

% Remove duplicates in gets list
gets = unique(gets, 'stable');
X.get_vars=gets;

% Get time from raw file for reference ("Time" or "time"?)
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end
% Length of time vector
X.rawTimeVar = Time;
X.time_len=numel(Time);

% Finally, create archive file with all variable names
% Scroll through X.varnames, using database to get attributes
X.structVars=X.rawGROUPS;
[X.schemaFINAL, X]=make_schema(X);

% Finally, do processing
save(fullfile(X.Home,"Xvalues.mat"),'X');
X=do_process1(X);

end

