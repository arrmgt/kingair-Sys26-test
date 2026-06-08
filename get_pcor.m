function [Yfit,m,b] = get_pcor(X,Y)
% Ensure column vectors
X=X(:);
Y=Y(:);

% Linear fit (degree 1): p = [m b]
p = polyfit(X, Y, 1);
m = p(1);
b = p(2);

% Evaluate fit on a fine grid for a smooth line
%%%%xx = linspace(min(X), max(X), 200);
Yfit = polyval(p, X);

% Plot data and fit
figure;
plot(X, Y, 'o', 'MarkerSize', 8, 'DisplayName', 'data');
hold on;
plot(X, Yfit, '.r', 'LineWidth', 2, 'DisplayName', sprintf('fit: Y = %.3f X + %.3f', m, b));
hold off;
grid on;
legend('Location','best');
xlabel('X');
ylabel('Y');
title('Linear Fit');
