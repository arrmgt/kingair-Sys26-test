function [ttt,tttp]=vtrans_0(att);
%VTRANS_0: coordinate transformation aircraft to earth
%$Source: /home/cvs/kingair/Sys09/vtrans_0.m,v $
%Project $Name: trans2am21_qc0 $ ($Revision: 1.1 $)
%$Date: 2010/08/10 09:07:16 $
%
%
sr=sin(att(1,:)');
cr=cos(att(1,:)');
sp=sin(att(2,:)');
cp=cos(att(2,:)');
sh=sin(att(3,:)');
ch=cos(att(3,:)');

% 
% rr='[1. 0. 0.;0 cr -sr;0. sr cr]'
%
% pp='[cp 0. sp; 0. 1. 0.; -sp 0. cp]'
%
% hh='[sh  ch 0.;-ch sh 0.; 0. 0. 1.]'
%
% gg='[1. 0. 0.; 0. -1. 0.; 0. 0. 1.]'
%
% symmul(sym(gg),symmul(sym(hh),symmul(sym(pp),sym(rr))))
%
% ans =
%
% [1.*sh*cp, 1.*sh*sp*sr+1.*ch*cr, 1.*sh*sp*cr-1.*ch*sr]
% [1.*ch*cp, 1.*ch*sp*sr-1.*sh*cr, 1.*ch*sp*cr+1.*sh*sr]
% [  -1.*sp,             1.*cp*sr,             1.*cp*cr]
%

nn=length(sr);
v1=ones(nn,1);
v0=zeros(nn,1);
rr=NaN*ones(3,3,nn);
rr(1,:,:)=[v1 v0 v0]';
rr(2,:,:)=[v0 cr -sr]';
rr(3,:,:)=[v0 sr cr]';

% pitch rotation
pp=NaN*ones(3,3,nn);
pp(1,:,:)=[cp v0 sp]';
pp(2,:,:)=[v0 v1 v0]';
pp(3,:,:)=[-sp v0 cp]';

% Roll rotation
hh=NaN*ones(3,3,nn);
hh(1,:,:)=[sh ch v0]';
hh(2,:,:)=[-ch sh v0]';
hh(3,:,:)=[v0 v0 v1]';

% Heading rotation
gg=NaN*ones(3,3,nn);
gg(1,:,:)=[v1 v0 v0]';
gg(2,:,:)=[v0 -v1 v0]';
gg(3,:,:)=[v0 v0 v1]';

% before matlab R2020
%tt1=multiprod(pp,rr);
%tt2=multiprod(hh,tt1);
%ttt=multiprod(gg,tt2);
%tttp=permute(ttt,[2,1,3]);

tt1=pagemtimes(pp,rr);
tt2=pagemtimes(hh,tt1);
ttt=pagemtimes(gg,tt2);
tttp=permute(ttt,[2,1,3]);


% symbolic toolbox version
%shsr=sh.*sr;
%shcr=sh.*cr;
%chsr=ch.*sr;
%chcr=ch.*cr;

%v11= sh .*cp;
%v12= shsr .*sp+chcr;
%v13= shcr .*sp-chsr;
%v21= ch .*cp;
%v22= chsr .*sp-shcr;
%v23= chcr .*sp+shsr;
%v31= -sp;
%v32= sr .*cp;
%v33= cr .*cp;
%vv1=[v11,v12,v13];
%vv2=[v21,v22,v23];
%vv3=[v31,v32,v33];
%
% now the transpose form (earth to aircraft)
%vv1i=[v11,v21,v31];
%vv2i=[v12,v22,v32];
%vv3i=[v13,v23,v33];

%ttt=[vv1,vv2,vv3];

