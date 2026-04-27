function get_varPCASP(X)

TT=datetime('now');% save processing start time

% This might be needed
clear ncinfo ncreadatt ncwriteatt ncread
close all

% Processing rate
orate=X.procRate;
try
    Time=ncread(X.RawPath,'time');
    rawTimeVar = 'time';
catch
    Time = ncread(X.RawPath,'Time');
    rawTimeVar = 'Time';
end

ssOut = "'Time'";

%  Need TAS and temp and pressure groups
matfile=fullfile(X.tempdir,sprintf("%s_TAS.mat",X.BaseName));
load(matfile,'TASX','PSX','TEMPKX');

% PCASP:  Allow for two PCASP with different suffixes
mask = ismember(X.rawGROUPS,{'PCASP1'});
GROUPS = X.rawGROUPS;
GROUPS = GROUPS(mask);
if any( numel(GROUPS))
    col1 = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);
end

% get actual suffixes
S = probeConfig;
Suffix1 = S.PCASP1.rawSuffix;
Suffix2 = S.PCASP2.rawSuffix;


mask = ismember(X.rawGROUPS,{'PCASP2'});
GROUPS = X.rawGROUPS;
GROUPS = GROUPS(mask);
if any(mask)
    col2 = getVarsAndRawNames(X.Ptable, GROUPS, X.Ttable);
    % Pad in case sizes different
    N = max(numel(col1), numel(col2));
    col1p = [col1; repmat("", N-numel(col1), 1)];
    col2p = [col2; repmat("", N-numel(col2), 1)];
    arcNames = [col1p, col2p];
    Suffixes = [Suffix1,Suffix2];
else
    arcNames = col1;
    Suffixes = Suffix1;
end


% Allow for more than one PCASP
for ii = 1:numel(Suffixes);
    SValue = Suffixes(ii);

    % Get variables from processed file
    NNAME=strcat('ASPP200_',SValue);
    SerialNumber = ncreadatt(X.RawPath,NNAME,'SerialNumber');
    %%%SampleArea = ncreadatt(X.RawPath,NNAME,'SampleArea');
    %%%SampleAreaUnits = ncreadatt(X.RawPath,NNAME,'SampleAreaUnits');
    CalibrationCoefficients = ncreadatt(X.RawPath,NNAME,'CalibrationCoefficients');
    CellEdges = ncreadatt(X.RawPath,NNAME,'CellSizes');
    CellEdgeUnits = ncreadatt(X.RawPath,NNAME,'CellSizeUnits');
    Threshold = ncreadatt(X.RawPath,NNAME,'threshold');
    [irate,dims]=get_irate(X.RawPath,NNAME,"OutputRate",orate);
    ncells=dims(1);
    
    
    % From processed file
    MNAME=strcat('AS200_',SValue);
    CNAME=strcat('CS200_',SValue);
    FirstBin = ncreadatt(X.ncFINAL,MNAME,'FirstBin');
    LastBin  = ncreadatt(X.ncFINAL,MNAME,'LastBin');
    ncwriteatt(X.ncFINAL,MNAME,'FirstBin',FirstBin);
    ncwriteatt(X.ncFINAL,MNAME,'LastBin',LastBin);
    ncwriteatt(X.ncFINAL,CNAME,'FirstBin',FirstBin);
    ncwriteatt(X.ncFINAL,CNAME,'LastBin',LastBin);
    ss0=sprintf('Bins are indexed 0 - %i ',ncells);
    ncwriteatt(X.ncFINAL,MNAME,'Comment0',ss0);
    ncwriteatt(X.ncFINAL,CNAME,'Comment0',ss0);
    ss1=sprintf('Measured: %i bins (1-%i); ',ncells,ncells);
    ncwriteatt(X.ncFINAL,MNAME,'Comment1',ss1);
    ncwriteatt(X.ncFINAL,CNAME,'Comment1',ss1);
    ss2=sprintf('Bin 0 is empty (compatibility). Bins 1-%i contain accumulations from probe;',ncells);
    ncwriteatt(X.ncFINAL,MNAME,'Comment2',ss2);
    ncwriteatt(X.ncFINAL,CNAME,'Comment2',ss2);
    if(FirstBin>1)
        
    
    end
    ss4=sprintf('FirstBin=%i, LastBin=%i; Those bins are used for concentration calculations;',FirstBin,LastBin);
    ncwriteatt(X.ncFINAL,MNAME,'Comment4',ss4);
    ncwriteatt(X.ncFINAL,CNAME,'Comment4',ss4);
    ss5=sprintf('CellSizes are bin edges for bin 1-%i (lower edge of bin 1 is uncertain).',ncells)
    ncwriteatt(X.ncFINAL,MNAME,'Comment5',ss5);
    ncwriteatt(X.ncFINAL,CNAME,'Comment5',ss5);
    
    % SPP200 flow rate
    FNAME=strcat('FLOW_',SValue);
    [irate,dims]=get_irate(X.RawPath,FNAME,"OutputRate",orate);
    if(orate>10)
        frate=10;
    else
        fraete=orate;
    end
    PcaspFlow = getdata(X.RawPath,FNAME,"OutputRate",frate);
    PcaspFlow(PcaspFlow<0 | PcaspFlow>100) = 0;
    units=ncreadatt(X.RawPath,FNAME,'units');
    
    if strfind(units,'volt') | length(units)==0
    %%%   c0=NC{FNAME}.AdditionalCoefficients(1);
    %%%   c0=ncreadatt(X.RawPath,FNAME,'AdditionalCoefficients');
    %%%   c1=NC{FNAME}.AdditionalCoefficients(2);PCASPrate
    %%%   PcaspFlow = power(PcaspFlow,c1) .* c0; % convert volts to cm3/sec
    %%%elseif isempty(strfind(units,'cm3 s-1')) & isempty(strfind(units,'cm3 sec-1'))
    %%%   sprintf ('%s','spp100 sample flow units not correct');
    %%%   return;        % bad units for pcasp flow - abort matlab
    end
        
    % SPP200 sheath flow rate
    SNAME=strcat('SHTHFLOW_',SValue);
    [irate,dims]=get_irate(X.RawPath,FNAME,"OutputRate",orate);
    PcaspSheath = getdata(X.RawPath,FNAME,"OutputRate",frate);
    PcaspSheath(PcaspSheath<0 | PcaspSheath>100) = 0;
    units=ncreadatt(X.RawPath,SNAME,'units');
    if strfind(units,'volt') | length(units)==0
    %%%   c0=NC{SNAME}.AdditionalCoefficients(1);
    %%%   c1=NC{SNAME}.AdditionalCoefficients(2);
    %%%   PcaspSheath=exp(PcaspSheath .* c1) .* c0; % convert volts to cm3/sec
    %%%elseif isempty(strfind(units,'cm3 s-1')) & isempty(strfind(units,'cm3 sec-1'))
    %%%   sprintf ('%s','spp100 sheath flow units not correct');
    %%%   return;        % bad units for pcasp sheath flow - abort matlab
    end
    
    %Raw spectra
    NNAME=strcat('ASPP200_',Suffixes(ii));
    [irate,dims]=get_irate(X.RawPath,NNAME,"OutputRate",frate);
    ncells=dims(1);
    blurf=ncread(X.RawPath,NNAME);
    % remove outlier values from cell array)
    blurf1=blurf(:);
    j=find(blurf1<0 | blurf1>1e10);
    blurf1(j)=0;
    blurf=reshape(blurf1,dims(1),dims(2),dims(3));
    blurf=reshape(permute(blurf,[2 3 1]),dims(2)*dims(3),dims(1));%reorder time dims
    
    
    [minterp,mdecim]=interp_decim(irate,frate);
    %Shift the data 1/2 of rate
    nsYY=floor(1 + mdecim/2);
    blurf=cumsum(blurf,1);
    blurf=diff([zeros(1,ncells);blurf(nsYY:mdecim:end,:)],1);% at frate 
    
    [minterp,mdecim]=interp_decim(orate,frate);
    matTAS=fullfile(X.tempdir,sprintf("%s_TAS.mat", X.BaseName));
    load(matTAS,'TASX','PSX','TEMPX')
    
    [minterp,mdecim]=interp_decim(orate,frate);
    Tas = decimateByFactors(Ninterp(TASX,minterp),mdecim,'FIR');
    Pmb = decimateByFactors(Ninterp(PSX,minterp),mdecim,'FIR');
    Tk = decimateByFactors(Ninterp(TEMPX,minterp),mdecim,'FIR');
    
    % Density corrected flow rate [cm3 s-1];
    
    Tref = ncreadatt(X.RawPath,FNAME,'Tref');
    if isempty(Tref); Tref = 20; end;
    Pref = ncreadatt(X.RawPath,FNAME,'Pref');
    if isempty(Pref); Pref = 1013; end;
    
    PcaspSV=PcaspFlow.*Tk.*Pref./Pmb./(Tref+273.15); 
    
    %
    % Add one to the number of channels to accomodate NCAR software
    %
    ncells1 = ncells + 1;
    SV30=PcaspSV(:,ones(ncells1,1));
    
    % Removed to agree with NCAR
    %% Density corrected sheath flow rate [cm3 s-1];
    %Tref = NC{SNAME}.Tref(:);
    %if isempty(Tref); Tref = 20; end;
    %Pref = NC{SNAME}.Pref(:);
    %if isempty(Pref); Pref = 1013; end;
    %PcaspSheath=spp200shthflow .* Tk .* Pref ./ Pmb ./ (Tref+273.15); 
    
    ncwriteatt(X.ncFINAL,MNAME,'CellSizes',CellEdges);
    ncwriteatt(X.ncFINAL,CNAME,'CellSizes',CellEdges);
    DPcasp = [0 mean([CellEdges(1:end-1);CellEdges(2:end)])];
    
    %
    % Add zero channel for NCAR software
    NPcasp  = zeros(size(blurf,1),ncells1);
    NPcasp(:,2:end)=blurf(:,1:end); %number in each cell, first empty
    CPcasp  = frate.*NPcasp ./ SV30;
    CPcasp(find(isnan(CPcasp))) = 0;
    
    % add 1 to bin numbers (Header uses 0:29 for bin numbers)
    % FirstBin and LastBin come from processing (var*.cdl)
    % (_raw.nc file has all bins indicated from 0-29).
    bbs=[FirstBin+1:LastBin+1];
    
    mom0 = sum(CPcasp(:,bbs),2);
    mom1 = CPcasp(:,bbs) * DPcasp(bbs)';
    mom2 = CPcasp(:,bbs) * power(DPcasp(bbs)',2);
    mom3 = CPcasp(:,bbs) * power(DPcasp(bbs)',3);
    
    PcaspTot        = sum(NPcasp(:,bbs),2);
    PcaspConc       = mom0;
    PcaspDbar       = mom1 ./ mom0; 
    PcaspDbar(find(isnan(PcaspDbar))) = 0;
    PcaspSfc        = pi * mom2; 
    PcaspVol        = pi/6 * mom3;
    PcaspDspr       = sqrt(mom2.*mom0./mom1./mom1-1);
    PcaspDspr(find(isnan(PcaspDspr))) = 0;
    
    % Add suffix
    
    ss=strcat('AS200_',SValue,'=NPcasp;');eval(ss);
    ss=strcat('CS200_',SValue,'=CPcasp;');eval(ss);
    ss=strcat('TCNTP_',SValue,'=PcaspTot;');eval(ss);
    ss=strcat('CONCP_',SValue,'=PcaspConc;');eval(ss);
    ss=strcat('DBARP_',SValue,'=PcaspDbar;');eval(ss);
    ss=strcat('PSFCP_',SValue,'=PcaspSfc;');eval(ss);
    ss=strcat('PVOLP_',SValue,'=PcaspVol;');eval(ss);
    ss=strcat('DISPP_',SValue,'=PcaspDspr;');eval(ss);
    ss=strcat('PFLW_', SValue,'=PcaspFlow;');eval(ss);
    ss=strcat('PFLWC_',SValue,'=PcaspSV;');eval(ss);
    ss=strcat('PFLWS_',SValue,'=PcaspSheath;');eval(ss);
    
    % Add Serial Number and OutputRate attributes to archive file
    for i = 1:length(arcNames(:,ii))
        nm = arcNames{i,ii};
        try
            ncwriteatt(X.ncFINAL,nm,'SerialNumber',SerialNumber);
            ncwriteatt(X.ncFINAL,nm,'OutputRate',frate);
        catch
            {nm 'not found!'}
        end
    end
    
    % Add the CalibrationCoefficients used for calculating the flow
    try
        ncwriteatt(X.ncFINAL ...
        ,['PFLW_' SValue],'CalibrationCoefficients',CalibrationCoefficients)
    catch
    end

    Rate=frate;

    for jj=1:numel(arcNames(:,ii));
            ssOut=sprintf("%s,'%s'",ssOut,arcNames{jj,ii}); 
    end; 
        
end % end of multiple PCASPs

Rate=frate;
arcNames=arcNames(:);
ss1 = "'orate','irate','Rate','frate','arcNames','Suffixes'";
ssOut = sprintf("%s,%s",ss1,ssOut);

% Write variables out to matfile
matfile=fullfile(X.tempdir,sprintf("%s_PCASP.mat",X.BaseName));
delete(matfile)
ss=sprintf("save(matfile,%s);",ssOut);eval(ss);

load_ncFINAL(X.ncFINAL,matfile);
;
TT1=datetime('now');
procSeconds=seconds(TT1-TT)
save(matfile,'-append','procSeconds')

sprintf('Processed get_varPCASP.m for Project: %s',X.PROJ)