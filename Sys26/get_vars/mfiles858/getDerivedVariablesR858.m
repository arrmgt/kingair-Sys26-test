function  [M, Mship, Mboom] = getDerivedVariablesR858( ...
    dpb, dpa, dpr_beta, dpr_alpha, dp1_ship, dp1_boom, ps_ship, ps_boom)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Mboom derived variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% R858 noseboom variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RAW variables
%   DPA     --> dpa             "alpha A1 - A2"
%   DPB     --> dpb             "beta  B1 - B2"
%   DPR     --> dpr_beta        "reference P1 - B1"
%   DPN     --> dpr_alpha       "reference P1 - A1"
%   DP1     --> dp1_Mship       "P1 - Mship static pressure"
%   DP2     --> dp1_boom        "P1 - boom static pressure"
%   PSA     --> ps_ship         "ship static pressure"
%   PSB     --> ps_boom         "boom static pressure"
%
% Mboom variables:    Use DP1_boom (P1 - booom Static)
% MMship variables:   Use DP1_Mship (P1 - Mship static)
% *_alpha variables:  Use the DPR_alpha measurement (P1 - A1)
% *_beta variables:   Use the DPR_beta measurement (P1 - B1)

% Inputs (measurements)
%   dpb
%   dpa
%   dpr_beta
%   dpr_alpha
%   dp1_ship
%   dp1_boom
%   ps_ship
%   ps_boom
%
% Outputs (derived):  alpha = uses dpr_alpha; beta = uses dpr_beta
%   q_alpha         |   Impact pressure using dpr_alpha
%   q_beta          |   Impact pressure using dpr_beta
%   ta_alpha
%   ta_beta
%   tb_alpha
%   tb_beta
%   fq_alpha
%   fq_beta
%   f_alpha
%   f_beta
%   ps_ship
%   ps_boom

% Definitions
%   ta_alpha        |   tan(alpha) using dpr_alpha
%   ta_beta         |   tan(beta) using dpr_beta
%   ta_alpha        |   tan(alpha) using dpr_alpha
%   tb_beta         |   tan(beta) using dpr_beta
%   q_alpha         |   impact pressure using dpr_alpha
%   q_beta          |   impact pressure using dpr_beta
%   f_alpha         |   f-factor using dpr_alpha
%   f_beta          |   f-factor dpr_beta
%   fq_alpha        |   f*q using dpr_alpha
%   fq_beta         |   f*q using dpr_beta
%   ps_boom         |   ps using boom static
%   ps_ship         |   ps using ship static
%
%function out1 = q_alpha(dp1a,dpa,dpb,dpra)
%function out1 = q_beta(dp1a,dpa,dpb,dpr)
%function out1 = f_alpha(dp1a,dpa,dpb,dpra)
%function out1 = f_beta(dp1a,dpa,dpb,dpr)
%function out1 = fq_alpha(dpa,dpb,dpra)
%function out1 = fq_beta(dpa,dpb,dpr)
%function out1 = ta_alpha(dpa,dpb,dpra)
%function out1 = ta_beta(dpa,dpb,dpr)
%function out1 = tb_alpha(dpa,dpb,dpra)
%function out1 = tb_beta(dpb,dpr)
%
% These variables were derived with symbolic toolbox
M.fq_alpha  = fq_alpha(dpa,dpb,dpr_alpha);
M.fq_beta   = fq_beta(dpa,dpb,dpr_beta);
M.ta_alpha  = ta_alpha(dpa,dpb,dpr_alpha);
M.ta_beta   = ta_beta(dpa,dpb,dpr_beta);
M.tb_alpha  = tb_alpha(dpa,dpb,dpr_alpha);
M.tb_beta   = tb_beta(dpb,dpr_beta);
M.ps_boom   = ps_boom;
M.ps_ship   = ps_ship;
M.dpr_alpha = dpr_alpha;
M.dpr_beta  = dpr_beta;

Mship.q_alpha  = q_alpha(dp1_ship, dpa, dpb, dpr_alpha);
Mship.q_beta   = q_beta(dp1_ship, dpa, dpb, dpr_beta);
Mship.f_alpha  = f_alpha(dp1_ship, dpa, dpb, dpr_alpha);
Mship.f_beta   = f_beta(dp1_ship, dpa, dpb, dpr_beta);

Mboom.q_alpha  = q_alpha(dp1_boom, dpa, dpb, dpr_alpha);
Mboom.q_beta   = q_beta(dp1_boom, dpa, dpb, dpr_beta);
Mboom.f_alpha  = f_alpha(dp1_boom, dpa, dpb, dpr_alpha);
Mboom.f_beta   = f_beta(dp1_boom, dpa, dpb, dpr_beta);

% Cleanup prior to takeoff;
q = Mboom.q_beta;
kk=find(q>25);
M       = pretty(kk,M);
Mship   = pretty(kk,Mship);
Mboom   = pretty(kk,Mboom);


end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% helper
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function M = pretty(kk,M)
fNames = fieldnames(M);
for ii=1:numel(fNames);
    ss=sprintf("x = M.%s;",fNames{ii}); eval(ss);
    k = kk(~isnan(x(kk)) & ~isinf(x(kk)));
    v1 = x(k(1)); v2 = x(k(end));
    zzall = [1:numel(x)]';
    x = interp1(k,x(k),zzall,'spline');
    
    % find queries left/right of domain and set to first/last sample value
    left  = zzall <= k(1);
    right = zzall >= k(end);
    x(left)  = v1;
    x(right) = v2;
    ss=sprintf("M.%s = x;",fNames{ii});eval(ss);
end

end