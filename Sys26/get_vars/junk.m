y1 = -10; y2=10;

ax(1)=subplot(4,1,1)
plot(omega(:,1)*180/pi)
ylabel('X axis')
v=axis;
axis([v(1),v(2),y1,y2])


ax(2)=subplot(4,1,2)
plot(omega(:,2).*180/pi)
ylabel('Y axis')
v=axis;
axis([v(1),v(2),y1,y2])

ax(3)=subplot(4,1,3)
plot(omega(:,3).*180/pi)
ylabel('Z axis')
v=axis;
axis([v(1),v(2),y1,y2])

ax(4)=subplot(4,1,4);
plot(att1(1,:)*180/pi)
ylabel('Roll angle')

% Link axes limits: 'x', 'y', or 'xy' (use 'xy' to link both)
linkaxes(ax, 'x')
% Enable interactive zoom for the figure
z = zoom(gcf);
z.Enable = 'on';

% Example axes handles ax
% 1) Using YLimMode
set(ax, 'YLimMode', 'auto');