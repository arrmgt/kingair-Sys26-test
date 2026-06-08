addpath('c:/users/rodi/Github/kingair-Sys26/Sys26/get_vars/mfiles858');
fileDir = 'P:\MATLAB-DATA2\kingair_data\scratch\test26\temp\20260408b_arr_TAS.mat';
load(fileDir);

% plot_F_alpha_beta.m
% Contour plot of F(alpha, beta) with beta on x-axis and alpha on y-axis.
%
% alpha = attack angle (radians)
% beta  = sideslip angle (radians)
%
% Replace the example F below with your own function handle, or comment it
% out if F is already defined in the workspace / on the path.

% --- Example F (delete or replace with your own) ---------------------------
[M, Mboom, Mship] = getDerivedVariablesR858( ...
    dpb, dpa, dpr_beta, dpr_alpha ...
    , dp1_ship + ship_pcor, dp1_boom + boom_pcor ...
    ,  ps_ship - ship_pcor,  ps_boom - boom_pcor);
f_ship_alpha = Mship.f_alpha ;
f_ship_beta = Mship.f_beta;
f_boom_alpha = Mboom.f_alpha;
f_boom_beta = Mboom.f_beta;
% ---------------------------------------------------------------------------

% Define grids (adjust ranges as needed)
beta0  = linspace(-20, 20, 101);   % sideslip, rad
alpha0 = linspace(-20, 20, 101);   % attack,   rad

[B, A] = meshgrid(beta0, alpha0);   % B varies along columns (x), A along rows (y)
TA = tan(alpha*pi/180);
TB = tan(beta.*pi./180);
dp1_ship = dp1_ship + ship_pcor;
F = f_beta(dp1_ship,dpa,dpb,dpr_beta);

% Evaluate F. If F is not vectorized, use arrayfun instead:
%   Z = arrayfun(@(a,b) F(a,b), A, B);
Z = f_beta(dp1_ship,dpa,dpb,dpr_beta);


% Filled contours with labeled lines on top
figure;
contourf(beta, alpha, Z, 20, 'LineColor', 'none'); hold on;
[C, h] = contour(beta, alpha, Z, 10, 'k');
clabel(C, h, 'FontSize', 8);

xlabel('\beta (deg)');
ylabel('\alpha (deg)');
title('F(\alpha, \beta)');
colorbar;
axis tight;
grid on;
