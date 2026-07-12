function [lm,beta] =do_pcor()
data = fullfile('P:/MATLAB-DATA2/kingair_data/test26/work')
files = string(["20260408a_arr.c25.nc","20260408b_arr.c25.nc"]);

q1 = []
ps_ship0 = [];
ps_boom0 = [];
alpha = [];
beta = [];
f = [];
for ii = 1:numel(files)
    file = fullfile(data,files(ii));
    blurf = ncread(file,'q_ship_beta'); q1=[q1;blurf(:)];
    blurf = ncread(file,'ps_ship'); ps_ship0=[ps_ship0;blurf(:)];
    blurf = ncread(file,'ps_boom'); ps_boom0=[ps_boom0;blurf(:)];
    blurf = ncread(file,'alpha'); alpha=[alpha;blurf(:)];
    blurf = ncread(file,'beta'); beta=[beta;blurf(:)];
    blurf = ncread(file,'f_ship_beta'); f=[f;blurf(:)];
end
kk=find(q1>35);
offset  = mean(ps_ship0(kk)-ps_boom0(kk));
ps_ship = ps_ship0 ;
ps_boom = ps_boom0 + offset;

time=datetime(2026,4,8) + seconds([1:numel(kk)]');
offset = mean(ps_ship(kk)-ps_boom(kk));
x1 = ps_ship(kk)-ps_boom(kk);
x2 = q1(kk);
x3 = alpha(kk);
x4 = beta(kk);
x5 = f(kk);

[lm,yhat,T]=do_regress(x1,x2,x3,x4,x5,'VariableNames',["pcor","q","alpha","beta","f"],'Time',time);

beta = lm.Coefficients.Estimate;   % [Intercept; ...]
yhat = applyCoeffs_matrix(beta,[x2,x3,x4,x5]);
ci = coefCI(lm);        % Nx2 matrix, lower and upper bounds
%C = [1 1 1 1];
%d = 0
%p = coefTest(lm, C, d); % general linear hypothesis C*beta = d
%ANOVA=anova(lm,'summary')

plot_fit(x1,yhat)

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

