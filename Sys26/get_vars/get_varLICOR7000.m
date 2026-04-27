function y=get_varLICOR7000(X)

%function [varargout] = get_7000licor(NC,MC,orate,temp,pres)
% GET_7000LICOR process data from the LI-7000 
%   
%   [FLOW70,CO2MLB70,TDPLI70,H2OMLB70,RHLI70] =
%     get_7000licor(NC,MC,orate,temp,pres)
%
% Modified from original get_nevzorov function
% Gets several licor output variables and resamples to desired rate,
% copying attributes from the raw file to the header file.
% Derives H2O mixing ratio in g/kg from mole fraction in licor output.
% Uses sat_vapor_pressure_GG(TK) function to estimate RH from Licor dewpoint and 
% static temperature.
%
% Inputs (from structure X)
%   temp - static temperature
%   pres - static pressure
%
% Outputs (names will be converted to lower case)
%   FLOW70 - Licor 7000 Flow
%   CO2MLB70 - Licor 7000 CO2 cell B concentration
%   TDPLI70 - Licor 7000 Dew point of cell B
%   H2OMLB70 - Licor 7000 H2O cell B concentration
%	Originally in mmol/mol - derive mass mixing ratio for output
%   RHLI70 - Licor 7000  estimated RH from temp/TDPLI70

% *_raw.nc variables
%   H2OML70:long_name = "Licor 7000 volume mixing ratio" ;
%   CO2ML70:long_name = "Licor 7000 CO2 volume mixing ratio" ;
%   LICORT70:long_name = "Licor 7000 temperature" ;
%   LICORP70:long_name = "Licor 7000 pressure" ;
%   FLOWR70:long_name = "Licor 7000 reference flow" ;
%   FLOWI70:long_name = "Licor 7000 sample flow" ;
%   CO2BABS70:long_name = "Licor 7000 CO2 cell B absorptance" ;
%   LI70P:long_name = "Licor 7000 pressure measured in cell B" ;
%   CO2BW:long_name = "Licor 7000 CO2 cell B raw signal" ;
%   CO2MLB70:long_name = "Licor 7000 CO2 cell B concentration" ;
%   DIAGRH70:long_name = "Licor 7000 internal humidity sensor" ;
%   H2OAW:long_name = "Licor 7000 H2O cell A raw signal" ;
%   LI70MSEC:long_name = "Licor 7000 milliseconds" ;
%   H2OBABS70:long_name = "Licor 7000 H2Ocell B absorptance" ;
%   LI70DIAG:long_name = "Licor 7000 Diagnostic" ;
%   LI70T:long_name = "Licor 7000 IRGA temperature" ;
%   H2OAGC70:long_name = "Licor 7000 H2O automatic gain control" ;
%   TDP70:long_name = "Licor 700 Dew point of cell B" ;
%   CO2AW:long_name = "Licor 7000 CO2cell A raw signal" ;
%   CO2AGC70:long_name = "Licor 7000 automatic gain control" ;
%   H2OBW:long_name = "Licor 7000 H2O cell B raw signal" ;
%   FLOW70:long_name = "Licor 7000 flow rate" ;


% Output variables
%   flow70:long_name = "Licor 7000 flow rate" ;
%   co2mlb70:long_name = "Licor 7000 CO2 cell B concentration" ;
%   tdp70:long_name = "Licor 700 Dew point of cell B" ;
%   rhli70:long_name = "Licor 7000 cell B relative humidity" ;

% FLOW70 must be the first variable
% RHLI70 calculated from TDPLI70

TT=datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

% Use pivot table and raw mapping table to get 
% 1. variables to be calculated;
% 2. raw measurements needed from *_raw.nc]
GROUPS = {"LICOR7000"};
[arcNames, rawNames, reverseMap] = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);

% Get physical constants
C = phycon();

vars = rawNames;

% get time variable from *_raw.nc
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

% get temperature and pressure from previous run of get_varTAS
matfile=fullfile(X.tempdir,sprintf("%s_TAS.mat",X.BaseName));
load(matfile,'PSX','TEMPX');
temp=TEMPX-C.Tzero;
pres=PSX;

% Output rate
orate=X.procRate;

% Get input rates from *_raw.nc

% Use FLOW70 as a test variable to get the data rate.
% If the test variable is not found, return gracefully with 'fill' arrays
try
    [irate,dims,~,FillValue]=get_irate(X.RawPath,'FLOW70'); 
catch    
    'get_varLICOR7000: ERROR. input rate for FLOW70 not found'
    return
end

% Assuming the missing value is the same for all variables.
% Create a fill variable, used if the variable is missing.
miss=FillValue;
if(isempty(miss));
    miss=X.FillValue;
end
fill = miss .* ones(numel(Time).*orate,1);

% Create a mask for if the pump is on (use a threshhold of 1.5 volts
% on the flow)
flowvar = ncread(X.RawPath,'FLOW70');
flow = flowvar(:);
flow = flow(:);

% Set missing values to zero so that extrapolation is reasonable
% This is needed only when the Licor files where recorded on a separate system
% flow(flow==flowvar.FillValue_(:)) = 0;
% VAR.var    = name(flowvar);
% VAR.data   = flow;
% VAR.fill   = flowvar.FillValue_;
% VAR.units0 = flowvar.units;
% VAR.wrap   = false;

% Interpolate to output times
flow  = getdata(X.RawPath,'FLOW70','OutputRate',orate);
first = find( flow > 1.5, 1, 'first' );

% Find when the pump was switch on and switched off
off   = [];
if first > 1; 
    off = 1:first; 
end
last = find( flow > 1.5, 1, 'last' );
if last < length(flow); 
    off = [ off last:length(flow) ]; 
end
nn=1:length(flow);
on=setxor(nn,off);
%on  = find( flow >= 1.5 );
%off = find( flow <  1.5 );

% Loop through each channel
for ivar = 1:length(vars)
    % Extract the variable name
    Var = vars{ivar};
    
    % The upper case raw file variable names are changed to
    % lower case for archiving.
    outvar = lower(Var);
    sprintf('Reading %s\n;',Var);
    
    switch (vars{ivar})
        case 'H2OMLB70'   
            % https://www.licor.com/env/help/eddypro6/Content/Converting_to_Mixing_Ratio.html      
            % H2O mole mixing ratio from mole fraction variable, licor site
            %      defines mole fraction as moles per mole of wet air.
            % Extract moles per mole dry air (mixing ratio) then convert to g/kg
            
            % From mole fraction to MR in moles per dry air: blurf./(1-blurf);
            % From moles to g/kg dry air: (18.02/28.96)*1000*MR
            [blurf,irate,nmiss] = getdata(X.RawPath,Var,'OutputRate',orate);
            molfrac = blurf./1000;     % Convert mmol/mol to mol/mol
            blurf   = 1000 .* C.Mv ./ C.Md .* (molfrac ./ (1-molfrac));
            
            % Rewrite a few attributes and variable name  
            if strcmp(vars{ivar},lower('H2OMLB70'))
                ncwriteatt(X.ncFINAL,lower(Var),'long_name','Licor 7000 H2O cell B mixing ratio');
                ncwriteatt(X.ncFINAL,lower(Var),'units','gram/kg');
                ncwriteatt(X.ncFINAL,lower(Var),'standard_name','mass_mixing_ratio_of_water_vapor_in_dry_air');
            end
        
        case 'TDP70'   
            %% Use existing vapor subroutine to estimate RH from temp and licor TDP
            %  See VAPRESS1, es, RH1 variables in get_miscXX for form
            % Note, vapor function struggles with the values extrapolated outside the
            %  usable data - used very basic dV/dt threshold from flow V
            sprintf('Calculating RH from licor TDP\n');
            [blurf,irate,nmiss] = getdata(X.RawPath,'TDP70','OutputRate',orate);
            e_sat2 = sat_vapor_pressure_GG(temp + C.Tzero);
            e_vap2 = sat_vapor_pressure_GG(blurf + C.Tzero);
            
            rhli70 = 100.*(e_vap2./e_sat2);
            rhli70(off)=miss;
        
        otherwise
            [blurf,irate,nmiss] = getdata(X.RawPath,Var,'OutputRate',orate);
    end

    % Still in loop over variables:  
    if ~strcmp(Var,'FLOW70')
        % Don't process values while the pump is off
        % Also, keep all values for the FLOW70 variable
        blurf(off) = miss;
    end
    
    % Report the number of missing values
    ncwriteatt(X.ncFINAL,lower(Var),'MissingValues',int32(nmiss));
    
    % Copy some attributes from the raw variable
    copyRawAtts(X.RawPath,Var,X.ncFINAL,lower(Var));
    
    % Output with lower case names
    ss=sprintf("%s = blurf;",lower(Var));
    eval(ss)
end  % End loop over variables

ss1="'orate','orate','arcNames','temp','pres','Time'";
for ii=1:numel(arcNames);
    if(numel(arcNames{ii})>1)
        ss1=sprintf("%s,'%s'",ss1,arcNames{ii});
    end
end


% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_LICOR7000.mat",X.BaseName));
delete(matfile)

ss=sprintf("save(matfile,%s);",ss1);
eval(ss);

TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds','TT','TT1')
;
load_ncFINAL(X.ncFINAL,matfile);

sprintf('Processed get_varLICOR7000.m for Project: %s',X.PROJ)