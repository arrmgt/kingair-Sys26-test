y1 = -10; y2=10;
close all
clear ax
clear *accel

blurf = ncread(X.ncFINAL,'AVlonga');xaccel=blurf(:);
blurf = ncread(X.ncFINAL,'AVlata');yaccel=blurf(:);
blurf = ncread(X.ncFINAL,'AVnorma');zaccel=blurf(:);
blurf = ncread(X.ncFINAL,'AVroll');roll=blurf(:);

ax(1)=subplot(4,1,1);
plot(xaccel)
title("Body accels");
ylabel('X axis')
v=axis;
axis([v(1),v(2),y1,y2])
grid

ax(2)=subplot(4,1,2);
plot(yaccel)
ylabel('Y axis')
v=axis;
axis([v(1),v(2),y1,y2])
grid

ax(3)=subplot(4,1,3);
plot(zaccel)
v=axis;
axis([v(1),v(2),y1,y2])
grid

ax(4)=subplot(4,1,4);;
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
set(ax, 'YLimMode', 'auto');