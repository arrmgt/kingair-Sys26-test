function x=cond(TK);
%C	./.* Calculate the thermal conductivity  .*./  units J./m./K./s
%C	using "Sutherland's equation (as in King et al 1981)

%cond273K=2.43e-2;
%x=cond273K *(398../(125.+TK)).*(TK./273.).^1.5 ;

% AirProperties app
x=AirProperties(TK,[],[],'k');
