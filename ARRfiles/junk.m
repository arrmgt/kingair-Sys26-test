addpath('c:/users/alfre/Github/kingair-Sys26-test/Sys26/get_vars/utilities');
addpath('c:/users/alfre/Github/kingair-Sys26-test/ARRfiles');
addpath('c:/users/alfre/Github/kingair-Sys26-test/ARRfiles/multi-fit');

matfile="E:\MATLAB-DATA2\kingair_data\scratch\test26\temp\20260701_arr_TAS.mat"
load(matfile);

rnames = ["PTB", "DP1", "DP2", "PSA", "PSB", "DPA", "DPB", "DPR", "DPN"];
for i = 1:numel(rnames)
    blurf = changeRate(RAW.(rnames(i)),RATE.(rnames(i)),10);
    eval(sprintf("%s = blurf;",rnames(i)));
end
kk = find(PTB>PSA & DPA>200 & DPR>20);
for i = 1:numel(rnames);
    eval(sprintf("%s = repair_one(%s,kk);",rnames(i),rnames(i)));
end

    sigma.PTB   = 0.1;
    sigma.PSA   = 0.1;
    sigma.DPA   = 0.01;
    sigma.DPB   = 0.01;
    sigma.DPR   = 0.01;
    sigma.DPN   = 0.01;
    sigma.fcoef = 0.01;
    sigma.pcor  = 0.5;
    mr = zeros(size(DP1));
    clear LB UB betaf betaf1 
    betaf1 = [ ...]
  0 ...
  1 ...
  -2 ...
  2]';
   
LB(1) = -3.0;    UB(1) = 3; 
LB(2) = 0.0;     UB(2) = 2.0;
LB(3) = -5.0;    UB(3) = 0.0;
LB(4) = 0.0;     UB(4) = 4.0;

    options=optimset('lsqnonlin');
    options=optimset(options,'Display','iter');
    options=optimset(options,'MaxFunEvals',20000);
    %options=optimset(options,'TolX',1.e-4,'TolFun',1.e-4);
    mr = zeros(size(DPA));

    kk = find(DP1>20 & PSA<PTB & PSA>200);
    names  = {'PTB','PSA','DP1','DPA','DPB','DPR','DPN','mr'};
    values = {PTB(kk), PSA(kk), DP1(kk), DPA(kk), DPB(kk), DPR(kk), DPN(kk), mr(kk)};
    Z = cell2struct(values, names, 2);
    fun = @(b) fcalc(b, Z, sigma);


    [betaf,resnorm,resid,exitflag,output,lambda,jacobian]= ...
        lsqnonlin(fun,betaf1,LB,UB,options);
    [f,qx1,pkor,fcoef]=fcalc(betaf,Z,sigma);
    OUT1 = r858_solve3(PTB(kk), PSA(kk), DPA(kk), DPB(kk), DPR(kk), DPN(kk), fcoef, pkor, sigma, .05);
    plot([qx1,OUT1.q])

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



