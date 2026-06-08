function [lm,BETA] =do_pcor_raw()
addpath('c:/users/rodi/Github/kingair-Sys26/Sys25/get_vars/utilities')
data = fullfile('P:/MATLAB-DATA2/kingair_data/test26/work')
files = string(["20260408a_raw.nc","20260408b_raw.nc"]);

q1 = [];
ps_ship0 = [];
ps_boom0 = [];
alpha = [];
beta = [];
f = [];

VARS = {'DPA','DPB','DPR','DPN','PSA','PSB','DP1','DP2','AALT',}
rate = 10;
for ii = 1:numel(files)
    file = fullfile(data,files(ii));
    blurf = getdata(file,'TROSE', 'OutputRate',rate);   TROSE  = blurf(:);
    blurf = getdata(file,'DPA', 'OutputRate',rate);     DPA  = blurf(:);
    blurf = getdata(file,'DPB', 'OutputRate',rate);     DPB  = blurf(:);            
    blurf = getdata(file,'DPR', 'OutputRate',rate);     DPR  = blurf(:);
    blurf = getdata(file,'DPN', 'OutputRate',rate);     DPN  = blurf(:);
    blurf = getdata(file,'PSA', 'OutputRate',rate);     PSA  = blurf(:);
    blurf = getdata(file,'PSB', 'OutputRate',rate); PSB  = blurf(:);
    blurf = getdata(file,'DP1', 'OutputRate',rate);     DP1  = blurf(:);
    blurf = getdata(file,'DP2', 'OutputRate',rate);     DP2  = blurf(:);
    blurf = getdata(file,'PTB', 'OutputRate',rate);     PTB  = blurf(:);
    blurf = getdata(file,'AALT', 'OutputRate',rate);    AALT  = blurf(:);

    %%function  [M, Mship, Mboom] = getDerivedVariablesR858( ...
    %%dpb, dpa, dpr_beta, dpr_alpha, dp1_ship, dp1_boom, ps_ship, ps_boom)
       
    zz = find( DP1 > 30   & DP1 < 100 ...
        & DP2 > 30   & DP2 < 100 ...
        & abs(PSA-PSB) < 20  );
    [M, Mboom, Mship] = getDerivedVariablesR858( ...
        DPB(zz), DPA(zz), DPR(zz), DPN(zz), ...
        DP1(zz), DP2(zz), PSA(zz), PSB(zz));
    q1          = [q1;Mship.q_beta]; 
    ps_ship0    = [ps_ship0;PSA(zz)];
    ps_boom0    = [ps_boom0;PSB(zz)];
    alpha       = [alpha;atan(M.ta_beta)];
    beta        = [beta;atan(M.tb_beta)];
    f           = [f;Mship.f_beta];

end
kk=1:numel(q1);
offset  = mean(ps_ship0(kk)-ps_boom0(kk));
ps_ship = ps_ship0 ;
ps_boom = ps_boom0 + offset;

M = calc_mach(q1 + ps_ship, ps_ship);

time=datetime(2026,4,8) + seconds([1:numel(kk)]');
x1 = ps_ship(kk)-ps_boom(kk);
x2 = M(kk);
x3 = q1(kk);
x4 = alpha(kk);
X = [x1,x2,x3,x4];
variableNames = ["pcor","Mach","q","alpha"];
[lm,yhat,T]=do_regress(X,variableNames);

disp(lm)
R2 = lm.Rsquared.Ordinary;
BETA = lm.Coefficients.Estimate;   % [Intercept; ...]
yhat = applyCoeffs_matrix(BETA,X(:,2:end));
ci = coefCI(lm);        % Nx2 matrix, lower and upper bounds
%C = [1 1 1 1];
%d = 0
%p = coefTest(lm, C, d); % general linear hypothesis C*beta = d
%ANOVA=anova(lm,'summary')

figure(2)
plot(x1,yhat,'.');
xlabel('PSA-PSB')
ylabel('pcor')

end

function yhat = applyCoeffs_matrix(beta, X)
% Apply linear model coefficients to predictor matrix X.
% beta : (p+1)x1 vector [intercept; b1; b2; ...; bp]
% X    : NxP numeric matrix where columns match beta(2:end) order
% yhat : Nx1 predicted responses

% Ensure column orientation
beta = beta(:);
if size(beta,1) ~= size(X,2)+1
    error('Length of beta must be number of columns of X plus one (intercept).');
end

yhat = X * beta(2:end) + beta(1);
end
