function [pcor, fcoef] = do_fcalc0(matfile,Pressure,varargin)
%
% Use Rodi and Leon (2012) result to get R858 f-parameter using maneuver data
%   and return pressure correction
% Compares analytical with regression Qimpact to get pkor
%    Regression uses r858_solve3(...,pcor,fcoef) to check result.
% This runs in the do10process1.m "maneuver" analyzer script
% Requires mat file with stored data
% e.g  'e:/MATLAB-DATA2/kingair_data/test26/work/maneuvers_SHIP.mat'
%
% Inputs:
%   matfile:            Data for fit
%   Pressure:           Either "SHIP" or "BOOM"  static pressure
%   Plots (optional):   Plots figures if true.
%
p = inputParser; 
addParameter(p, "Plots", false,            @(s)islogical(s));
p.parse(varargin{:});
X = p.Results;
Plots = X.Plots; % do plots if true

addpath('c:/users/alfre/Github/kingair-Sys26-test/ARRfiles/multi-fit');
addpath('c:/users/alfre/Github/kingair-Sys26-test/Sys26/get_vars/utilities');
addpath('c:/users/alfre/Github/kingair-Sys26-test/Sys26/get_vars/mfiles858');
addpath('c:/users/alfre/Github/kingair-Sys26-test/ARRfiles');

    sigma.PTB   = 0.1;
    sigma.PSX   = 0.1;
    sigma.DPX   = 0.01;
    sigma.DPB   = 0.01;
    sigma.DPR   = 0.01;
    sigma.DPN   = 0.01;
    sigma.fcoef = 0.01;
    sigma.pcor  = 0.5;

    clear LB UB betaf betaf1 
    betaf1 = [ ...]
  1.7 ...
  0 ...
  0 ...
  0]';
   
LB(1) = 1.7;     UB(1) = 1.7; 
LB(2) =  -20;    UB(2) = 20; 
LB(3) =  0;      UB(3) = 0; 
LB(4) =  0;      UB(4) = 0; 
LB=[];  UB=[];


options=optimset('lsqnonlin');
options=optimset(options,'Display','iter');
options=optimset(options,'MaxFunEvals',2000);
%%%options=optimset(options,'TolX',1.e-4,'TolFun',1.e-4);
sigma.ptb   = 0.1;
sigma.psa   = 0.1;
sigma.dp1   = 0.01;
sigma.dpa   = 0.01;
sigma.dpb   = 0.01;
sigma.dpr   = 0.01;
sigma.dpn   = 0.01;
sigma.fcoef = 0.01;
sigma.pcor  = 0.5;

rate = 10;
P = _PRESSURE;
        clear ptb psm dp1m dpa dpb dpr dpn mr
       
        mr = zeros(size(dpb));
        machn = zeros(size(dpb));
        pkor = zeros(size(dpb));
        fcoef = zeros(size(dpb));
        names  = {'PTB','PSX','DPX','DPA','DPB','DPR','DPN','mr','machn'};
        values = { ptb,  psm,  dp1m,  dpa,  dpb,...
            dpr,  dpn,  mr, machn};
        Z = cell2struct(values, names, 2);
        PTB = Z.DPX + Z.PSX; % ptb has problem
        figure(98), plot(PTB,Z.PTB,'.'),title(P),grid
        fun = @(b) fcalc(b, Z, sigma); 
        betaf1 = [0 0 0 0 0]';
        [ff,qqx1,ppkor,ffcoef]=fcalc(betaf1,Z,sigma);
        %%%%[betafx,diagnostix]=runCalibrationFit(Z,sigma,betaf1);
        warning off;
        [betaf,resnorm,resid,exitflag,output,lambda,jacobian]= ...
            lsqnonlin(fun,betaf1,LB,UB,options);
        [f,qx1,pkor,fcoef,fqx0,XX1f,betaf,machn] = fcalc(betaf,Z,sigma);
        Z.machn = machn;
        OUT1 = r858_solve3(ptb, psm, dpa, dpb, dpr, dpn, fcoef, pkor);
        if Plots
            figure(1)
            plot([1:numel(qx1)]./rate./60,[qx1-OUT1.q])
            title(sprintf('%s STATIC',P))
            xlabel('Time [minutes]')
            ylabel('Q(exact) - Q(fit) [hPa]')
            v=axis;
            axis([v(1) v(2) -3 3])
            grid
            figure(2)
            plot([1:numel(qx1)]./rate./60,pkor)
            title(sprintf('%s STATIC',P))
            xlabel('Time [minutes]')
            ylabel('Pressure correction [hPa]')
            v=axis;
            axis([v(1) v(2) 0 10])
            grid
            figure(3)
            plot([1:numel(qx1)]./rate./60,fcoef)
            title(sprintf('%s STATIC',P))
            xlabel('Time [minutes]')
            ylabel('f coefficient [dim]')
            v=axis;
            axis([v(1) v(2) 1.6 1.75])
            grid
        end

J = full(jacobian);           % should be Nx3
n = length(resid);
p = length(betaf);            % should be 3 now

mse = resnorm / (n - p);
Cbeta = mse * inv(J'*J);      % 3x3

% propagate using XX1f (Nx3), NOT a separate "data" matrix
Var_solution = sum((XX1f * Cbeta) .* XX1f, 2);   % Nx1

alpha = 0.05;
tval = tinv(1 - alpha/2, n - p);
CI_lower = pkor - tval * sqrt(Var_solution);
CI_upper = pkor + tval * sqrt(Var_solution);

Var_prediction = mse + Var_solution;    % mse already computed above
tval = tinv(1 - alpha/2, n - p);

CI_pred_lower = pkor - tval * sqrt(Var_prediction);
CI_pred_upper = pkor + tval * sqrt(Var_prediction);

return

% Suppose Z has fields like Z.var1, Z.var2, ... Z.var10, each Nx1
fieldNames = names;          % cell array of all field names
X = struct2array(Z);         % if ALL fields are numeric Nx1 vectors, this concatenates them into NxM

% If Z has some non-numeric or non-matching-length fields, be explicit instead:
%%%varsToUse = {'machn','DPA'};   % pick your candidate name

tbl = array2table([X, pkor], 'VariableNames', [fieldNames, {'y'}]);
mdl = stepwiselm(tbl, 'ResponseVar', 'y')

end

%%%%%%%%% Helper %%%%%%%%%%%
%%% Clean up before TO and after Landing
function x = repair_one(x, kk)
allSamples = (1:numel(x))';
if(kk>10)
    x = interp1(kk, x(kk), allSamples, 'linear', NaN);
    x(allSamples < kk(1)) = x(kk(1));
    x(allSamples > kk(end)) = x(kk(end));
end

end



