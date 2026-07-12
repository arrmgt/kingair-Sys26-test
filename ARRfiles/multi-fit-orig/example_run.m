%% example_run.m
% Headless (no GUI) example of fitting and applying a correction model
% over a large collection of NetCDF files. Use this from the command
% line, in a batch job, or on a cluster for the biggest jobs where you
% don't want a GUI in the loop at all -- it calls the exact same
% functions as ncRegressionApp.m.

%% 1. Point at your data
ncFolder = '/path/to/netcdf/files';
listing = dir(fullfile(ncFolder, '**', '*.nc'));
ncFiles = fullfile({listing.folder}, {listing.name});
fprintf('Found %d NetCDF files.\n', numel(ncFiles));

%% 2. (Optional) inspect variables in one file first
% t = listNetCDFVariables(ncFiles{1})

%% 3. Choose your variables
% EDIT THESE to match your actual NetCDF variable names.
predictorVars = {'temperature','pressure','humidity','windSpeed','solarFlux'};
xVar = 'sensor_raw';   % the value you want corrected
yVar = 'reference';    % the value it should match after correction

%% 4. Fit
opts = struct();
opts.modelOrder  = 'linear';   % or 'interactions' / 'quadratic'
opts.standardize = true;       % recommended if predictors have very different scales
opts.validFrac   = 0.2;        % 20% of files held out for validation
opts.seed        = 1;
opts.verbose     = true;

model = streamFitCorrection(ncFiles, predictorVars, xVar, yVar, opts);

fprintf('\nFitted coefficients:\n');
disp(table(model.termNames(:), model.beta(:), 'VariableNames', {'Term','Coefficient'}));
fprintf('Train R^2=%.4f RMSE=%.4g (n=%d)\n', model.R2, model.RMSE, model.n);
fprintf('Val   R^2=%.4f RMSE=%.4g (n=%d)\n', model.valR2, model.valRMSE, model.nVal);

%% 5. Save the model
exportModel(model, fullfile(ncFolder, 'fits', 'nc_correction_model'));

%% 6. Apply the model to new data (e.g. a fresh file)
% newFile = fullfile(ncFolder, 'new_observation.nc');
% [data, ok] = readNetCDFChunk(newFile, [predictorVars, {xVar}]);
% if ok
%     k = numel(predictorVars);
%     n = numel(data.(matlab.lang.makeValidName(predictorVars{1})));
%     P = zeros(n, k);
%     for j = 1:k
%         P(:,j) = data.(matlab.lang.makeValidName(predictorVars{j}));
%     end
%     X = data.(matlab.lang.makeValidName(xVar));
%     Xcorrected = applyCorrectionModel(model, P, X);
% end
