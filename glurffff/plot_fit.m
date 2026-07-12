function plot_fit(x,y);

% Fit line y = m*x + b
p = polyfit(x,y,1);    % p(1)=m, p(2)=b
m = p(1);
b = p(2);

% Evaluate fit for plotting
xx = linspace(min(x),max(x),100);
yy = polyval(p,xx);

% Compute R-squared (goodness of fit)
yfit = polyval(p,x);
SSres = sum((y - yfit).^2);
SStot = sum((y - mean(y)).^2);
R2 = 1 - SSres/SStot;

% Plot
close all
figure
scatter(x,y,25,'.'), hold on
plot(xx,yy,'r-','LineWidth',2)
legend('Data','Linear fit','Location','best')
xlabel('Q'), ylabel('PCOR')
title(sprintf('Linear fit: y = %.4f x + %.4f   R^2 = %.3f', m, b, R2))
grid on
hold off
