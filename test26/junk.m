function get_varTAS(X)
% GET_VARTAS  Compute TAS-group variables and write to NetCDF + matfile.
%
%   GET_VARTAS(X) reads raw measurements from the project's *_RAW.nc file,
%    computes True Air Speed and  derived thermodynamic variables.
%   Results are written to a matfile which is merged
%    with other measurement group matfiles into the 
%    into the final NetCDF file.
%
%   Required fields of the input struct X are set in the 
%         main calling program do_batch26.m
%
%   Outputs: The list arcNames are variables saved to the matfile
%
%   Local helpers (defined below):
%     get_uvw:  gets hi-rate TAS components for the EDR calculation
%     repair_one:   clean up the end times before TO and after landing.


TT=datetime('now');
% Time attributes
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

C = phycon; % Physical constants
Tzero = C.Tzero;

C = phycon; % Physical constants
Tzero = C.Tzero;

% Need these if available
needGROUPS = {'TAS'};
mask = contains(X.rawGROUPS,needGROUPS);
%  Need TAS and temp and pressure groups
GROUPS = X.rawGROUPS(mask) ; % Pressures loaded previously
% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_RAW.nc
[arcNames, rawNames] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

%% Read in the needed raw data and change rate as needed; 
%   Changing rate
info  = ncinfo(X.RawPath);
names = {info.Variables.Name};
info.Variables = info.Variables(ismember(names,rawNames));
RAW  = struct();
RATE = struct();
for i = 1:numel(info.Variables)
    var = info.Variables(i).Name;
    irate = get_irate(X.RawPath,var);
    x     = ncread(X.RawPath,var);
    RAW.(var) = x(:);
    RATE.(var)  = irate;
    if X.rmOutliers  %  Set in do_batch26 as an option 
        attrNames = {info.Variables(i).Attributes.Name};
        % Analog variable??
        if any(strcmp(attrNames,'AnalogCalibration')) 
            y  = RAW.(var);
            [B,Tfrm,TFoutlier]=rmoutliers(y,'movmedian',500);
            kk = find(~TFoutlier);
            y = interp1(kk,y(kk),[1:numel(y)]','pchip',0);
            plots = true
            if plots
                figure(i)
                plot([1:numel(y)]'./irate/60,y,'x')
                rawfile = strrep(X.RawFile,'_','\_');
                title(sprintf("%s: %s  irate = %5.0f",rawfile,var,irate))
                grid
                saveas(gca,sprintf('%s-%s.jpg',X.RawFile,var))
            end  
        end
    else
        y = RAW.(var);
    end
    D.(var) = changeRate(y,RATE.(var),X.procRate);
end

% Detect "in-flight"
[pcorc,fcoef] = cone_pcor(D.DP1,D.DPB,D.DPA,D.DPR,D.PSA);
% Rough estimates of measurement sigma for 8 inputs in r858_solve
sigma = 0.1*ones(8,1);
OUT= r858_solve(D.PTB, D.PSA, D.DPA, D.DPB, D.DPR, D.DPN, fcoef, pcorc,sigma);
kk = find(out.q_SE<10 & out.q>5 &  abs(pcorc)<5); % In-flight points
 
'end'