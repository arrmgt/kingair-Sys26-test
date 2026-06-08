y1 = -10; y2=10;
close all
clear ax
clear *accel


blurf = ncread(X.ncFINAL,'avrollr');    rollr=blurf(:);
blurf = ncread(X.ncFINAL,'avpitchr');   pitchr=blurf(:);
blurf = ncread(X.ncFINAL,'avyawr');     yawr=blurf(:);
blurf = ncread(X.ncFINAL,'avroll');     roll=blurf(:);
blurf = ncread(X.ncFINAL,'PSX');        pmb=blurf(:);

ax(1)=subplot(4,1,1)
plot(rollr*180/pi)
title('Body angle rates ')
ylabel('X axis')
v=axis;
axis([v(1),v(2),y1,y2])
grid

ax(2)=subplot(4,1,2)
plot(pitchr.*180/pi)
ylabel('Y axis')
v=axis;
axis([v(1),v(2),y1,y2])
grid

ax(3)=subplot(4,1,3)
plot(yawr.*180/pi)
ylabel('Z axis')
v=axis;
axis([v(1),v(2),y1,y2])
grid

ax(4)=subplot(4,1,4);
plot(roll)
ylabel('Roll angle')
grid

% Link axes limits: 'x', 'y', or 'xy' (use 'xy' to link both)
linkaxes(ax, 'x')
% Enable interactive zoom for the figure
z = zoom(gcf);
z.Enable = 'on';

% Example axes handles ax
% 1) Using YLimMode
%set(ax, 'YLimMode', 'auto');