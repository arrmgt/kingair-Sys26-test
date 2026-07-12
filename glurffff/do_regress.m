function [lm,yhat,coeffs, R2,T, variableNames] = do_regress(varargin)
% makeTable5 Create a table or timetable from five N×1 variables.
%   T = makeTable(X(:,1),X(:,2),X(:,3),X(:,4),X(:,5)) returns a table with default names Var1..Var5.
%   T = makeTable(...,'VariableNames',{'A','B','C','D','E'})

X = varargin{1};
if nargin>1
    N= varargin{2};
else
    N=string(["x1","x2","x3","x4","x5","x6","x7","x8"]);
end

[nn,nx] = size(X);
variableNames = N(1:nx);
switch nx
    case 3
        T = table(X(:,1),X(:,2),X(:,3),'VariableNames',N(1:3));
        ss1 = sprintf("%s ~ %s + %s",N(1),N(2),N(3));
    case 4
        T = table(X(:,1),X(:,2),X(:,3),X(:,4),'VariableNames',N(1:4));
        ss1 = sprintf("%s ~ %s + %s + %s",N(1),N(2),N(3),N(4));
    case 5
        T = table(X(:,1),X(:,2),X(:,3),X(:,4),X(:,5),'VariableNames',N(1:5));
        ss1 = sprintf("%s ~ %s + %s + %s + %s",N(1),N(2),N(3),N(4),N(5));
    case 6
        T = table(X(:,1),X(:,2),X(:,3),X(:,4),X(:,5),X(:,6),'VariableNames',N(1:6));
        ss1 = sprintf("%s ~ %s + %s + %s + %s + %s",N(1),N(2),N(3),N(4),N(5),N(6));
end

% Fit linear model
ss2 = sprintf("lm = fitlm(T, '%s');",ss1);
eval(ss2)

% Display results

disp(lm)
coeffs = lm.Coefficients.Estimate;
R2 = lm.Rsquared.Ordinary;

% Predict on new data (same variable names)
yhat = predict(lm, T);    % predictions for training data

return

% X: NxP numeric predictors, y: NX(:,1) response
cvMSE = crossval('mse', [X(:,2),X(:,3),X(:,4),X(:,5)], yhat, 'KFold', 10, 'Predfun', @regf);  % returns scalar MSE
rmse = sqrt(cvMSE);

end

% regf must be on the path or in the same file:
function yfit = regf(Xtrain,ytrain,Xtest)
    mdl = fitlm(Xtrain, ytrain);    % or fitrlinear/fitrtree inside if preferred
    yfit = predict(mdl, Xtest);
end