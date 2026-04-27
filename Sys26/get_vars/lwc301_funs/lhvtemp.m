%LHVTEMP: compute latent heat of vaporization at temp tc
%$Source: /home/cvs/kingair/Sys09/lwc301_funs/lhvtemp.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.2 $)
%$Date: 2020/09/05 20:20:36 $
%function lhv=lhvtemp(tc);
% Input: temperature (range -40 to +50) [Celsius]
% Output: Latent heat of vaporization [J/kg]

function lhv=lhvtemp(tc);

%if(tc >=-40 & tc<= 50),
%data from Iribarne and Godson (2nd Ed, 1981)
%
% Use table lookup
lhvs=[2.6348, 2.6030, 2.5749, 2.5247, 2.5008, 2.4891, ...
2.4774, 2.4656, 2.4535, 2.4418, 2.4300, 2.4183, 2.4062, ...
2.3945, 2.3823].*1e6;% J/kg
temps=[-40:10:0,5:5:50];% Celsius

% Use spline
pp=spline(temps,lhvs);
lhv=ppval(pp,tc);

%else
%help lhvtemp
%'Temperature range is -40 to +50'
%end


