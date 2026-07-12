function windplot(X,Y,U,V)
% X, Y, U, V are Nx1
figure
plot(X, Y, '.k', 'MarkerSize', 8)    % aircraft positions
hold on
quiver(X, Y, U, V, 0.5, 'b')         % scale factor 0.5 (adjust as needed)
axis equal
xlabel('X'); ylabel('Y')
title('Aircraft locations with wind vectors (quiver)')
grid on
legend('Aircraft', 'Wind')
hold off