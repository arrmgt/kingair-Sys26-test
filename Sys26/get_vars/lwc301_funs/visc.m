function x=visc(TK)
%C	./.* Calculate the viscosity  .*./  units kg./m./sec

% Sutherland equation
%    visc273K=1.718e-5;
%	x = visc273K * (393../(120.+TK)).*(TK./273.).^1.5;

% AirProperties app
	x = AirProperties(TK,[],[],'mu');
