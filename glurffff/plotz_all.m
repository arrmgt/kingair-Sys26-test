PROJ = 'test26'
dataDir = fullfile('P:/MATLAB-DATA2/kingair_data/',PROJ,'work')

file = fullfile('P:/MATLAB-DATA2/kingair_data/',PROJ,'work','20260408a_arr.c10.nc');
blurf = ncread(file,'beta');beta = blurf(:);
blurf = ncread(file,'TASX'); tas = blurf(:);
blurf = ncread(file,'avroll'); roll = blurf(:);
blurf = ncread(file,'avzmsl'); zmsl =blurf(:);


kk0=[1:numel(tas)]';
kk=find(zmsl>zmsl(1)+1000 & abs(beta)<0.1);

ax(1)=subplot(4,1,1)
plot(kk0(kk),beta(kk))
ylabel('beta')
grid

ax(2)=subplot(4,1,2)
plot(kk0(kk),tas(kk))
ylabel('tas')
grid

ax(3)=subplot(4,1,3)
plot(kk0(kk),roll(kk))
ylabel('roll')
grid

ax(4)=subplot(4,1,4)
plot(kk0(kk),zmsl(kk))
ylabel('zmsl')
grid

% Link axes limits: 'x', 'y', or 'xy' (use 'xy' to link both)
linkaxes(ax, 'x')
% Enable interactive zoom for the figure
z = zoom(gcf);
z.Enable = 'on';

% Example axes handles ax
% 1) Using YLimMode
set(ax, 'YLimMode', 'auto');
