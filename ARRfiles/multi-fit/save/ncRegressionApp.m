classdef ncRegressionApp < handle
    %NCREGRESSIONAPP Interactive app for multivariate calibration
    %regression over large NetCDF datasets.
    %
    %   app = ncRegressionApp launches the GUI. Workflow:
    %     1. "Select NetCDF Folder..." to scan a folder for .nc files
    %     2. Pick 4-5 predictor variables, plus the X and Y variables
    %     3. Choose model order / options, click "Run Fit"
    %     4. Inspect coefficients, R^2/RMSE, and a diagnostic plot
    %     5. "Export Model..." to save coefficients (.mat + .csv)
    %
    %   The fit itself is out-of-core (streamFitCorrection.m): it never
    %   loads the whole dataset into memory, so this scales to gigabytes
    %   of NetCDF files. The fit runs on a background worker (via
    %   parfeval, if Parallel Computing Toolbox is available) so the UI
    %   stays responsive; otherwise it runs synchronously and the app
    %   will be unresponsive until the fit finishes -- for very large
    %   batch jobs in that situation, prefer example_run.m from a script
    %   or the command line instead of the GUI.
    %
    % See also: streamFitCorrection, applyCorrectionModel, exportModel

    properties (Access = public)
        UIFigure            matlab.ui.Figure
        NCFiles             cell = {}
        AvailableVars       table
        FitModel            struct = struct()
        FitFuture                    % parallel.FevalFuture, if used
    end

    properties (Access = private)
        MainGrid
        FolderLabel
        FileListBox
        PredictorListBox
        XDropDown
        YDropDown
        ModelOrderDropDown
        StandardizeCheckBox
        ValidFracField
        SeedField
        RunButton
        ExportButton
        StatusTextArea
        ResultsLabel
        CoefTable
        DiagAxes
    end

    methods (Access = public)
        function app = ncRegressionApp()
            createComponents(app);
        end
    end

    methods (Access = private)

        function createComponents(app)
            app.UIFigure = uifigure('Name', 'NetCDF Multivariate Correction App', ...
                'Position', [100 100 1050 650]);

            app.MainGrid = uigridlayout(app.UIFigure, [1 2]);
            app.MainGrid.ColumnWidth = {330, '1x'};

            % ---------------- Left column: data + options ----------------
            leftGrid = uigridlayout(app.MainGrid, [11 1]);
            leftGrid.RowHeight = {30, 90, 22, 130, 22, 30, 30, 30, 30, 30, 40};
            leftGrid.Layout.Row = 1; leftGrid.Layout.Column = 1;

            btnFolder = uibutton(leftGrid, 'Text', 'Select NetCDF Folder...', ...
                'ButtonPushedFcn', @(src,evt) app.onSelectFolder());
            btnFolder.Layout.Row = 1;

            app.FileListBox = uilistbox(leftGrid, 'Items', {}, 'Multiselect', 'off');
            app.FileListBox.Layout.Row = 2;

            lbl1 = uilabel(leftGrid, 'Text', 'Predictor variables (pick 4-5):');
            lbl1.Layout.Row = 3;

            app.PredictorListBox = uilistbox(leftGrid, 'Items', {}, 'Multiselect', 'on');
            app.PredictorListBox.Layout.Row = 4;

            lbl2 = uilabel(leftGrid, 'Text', 'X (to correct)          Y (target)');
            lbl2.Layout.Row = 5;

            xyGrid = uigridlayout(leftGrid, [1 2]);
            xyGrid.Layout.Row = 6;
            xyGrid.Padding = [0 0 0 0];
            app.XDropDown = uidropdown(xyGrid, 'Items', {});
            app.YDropDown = uidropdown(xyGrid, 'Items', {});

            moGrid = uigridlayout(leftGrid, [1 2]);
            moGrid.Layout.Row = 7;
            moGrid.Padding = [0 0 0 0];
            uilabel(moGrid, 'Text', 'Model order:');
            app.ModelOrderDropDown = uidropdown(moGrid, ...
                'Items', {'linear','interactions','quadratic'}, 'Value', 'linear');

            app.StandardizeCheckBox = uicheckbox(leftGrid, ...
                'Text', 'Standardize predictors (z-score)', 'Value', false);
            app.StandardizeCheckBox.Layout.Row = 8;

            vfGrid = uigridlayout(leftGrid, [1 4]);
            vfGrid.Layout.Row = 9;
            vfGrid.Padding = [0 0 0 0];
            uilabel(vfGrid, 'Text', 'Val frac:');
            app.ValidFracField = uieditfield(vfGrid, 'numeric', 'Value', 0.2, ...
                'Limits', [0 0.9]);
            uilabel(vfGrid, 'Text', 'Seed:');
            app.SeedField = uieditfield(vfGrid, 'numeric', 'Value', 1);

            app.RunButton = uibutton(leftGrid, 'Text', 'Run Fit', ...
                'ButtonPushedFcn', @(src,evt) app.onRunFit(), ...
                'BackgroundColor', [0.2 0.6 0.3], 'FontColor', [1 1 1]);
            app.RunButton.Layout.Row = 10;

            app.ExportButton = uibutton(leftGrid, 'Text', 'Export Model...', ...
                'ButtonPushedFcn', @(src,evt) app.onExport(), 'Enable', 'off');
            app.ExportButton.Layout.Row = 11;

            % ---------------- Right column: status + results ----------------
            rightGrid = uigridlayout(app.MainGrid, [4 1]);
            rightGrid.RowHeight = {110, 30, 160, '1x'};
            rightGrid.Layout.Row = 1; rightGrid.Layout.Column = 2;

            app.StatusTextArea = uitextarea(rightGrid, 'Value', {'Select a folder of NetCDF files to begin.'}, ...
                'Editable', 'off');
            app.StatusTextArea.Layout.Row = 1;

            app.ResultsLabel = uilabel(rightGrid, 'Text', '', 'FontWeight', 'bold');
            app.ResultsLabel.Layout.Row = 2;

            app.CoefTable = uitable(rightGrid, 'Data', table(), ...
                'ColumnName', {'Term','Coefficient'});
            app.CoefTable.Layout.Row = 3;

            app.DiagAxes = uiaxes(rightGrid);
            app.DiagAxes.Layout.Row = 4;
            title(app.DiagAxes, 'Validation: Y vs corrected X');
            xlabel(app.DiagAxes, 'X corrected');
            ylabel(app.DiagAxes, 'Y');
        end

        function log(app, msg)
            ts = datestr(now, 'HH:MM:SS'); %#ok<TNOW1,DATST>
            app.StatusTextArea.Value = [app.StatusTextArea.Value; {sprintf('[%s] %s', ts, msg)}];
            scroll(app.StatusTextArea, 'bottom');
            drawnow limitrate;
        end

        function onSelectFolder(app)
            folder = uigetdir(pwd, 'Select folder containing .nc files');
            if isequal(folder, 0), return; end
            listing = dir(fullfile(folder, '**', '*.nc'));
            if isempty(listing)
                uialert(app.UIFigure, 'No .nc files found in that folder (searched recursively).', 'No files found');
                return
            end
            app.NCFiles = fullfile({listing.folder}, {listing.name});
            app.FileListBox.Items = app.NCFiles;
            app.log(sprintf('Found %d NetCDF files under %s', numel(app.NCFiles), folder));

            try
                app.AvailableVars = listNetCDFVariables(app.NCFiles{1});
                names = cellstr(app.AvailableVars.Name);
                app.PredictorListBox.Items = names;
                app.XDropDown.Items = names;
                app.YDropDown.Items = names;
                if numel(names) >= 2
                    app.XDropDown.Value = names{1};
                    app.YDropDown.Value = names{2};
                end
                app.log(sprintf('Loaded %d variables from %s (used as the variable list for all files -- they should share the same schema).', ...
                    numel(names), app.NCFiles{1}));
            catch err
                uialert(app.UIFigure, err.message, 'Could not read variables');
            end
        end

        function onRunFit(app)
            predictors = app.PredictorListBox.Value;
            if numel(predictors) < 2
                uialert(app.UIFigure, 'Pick at least 2 (typically 4-5) predictor variables.', 'Not enough predictors');
                return
            end
            xVar = app.XDropDown.Value;
            yVar = app.YDropDown.Value;
            if isempty(xVar) || isempty(yVar)
                uialert(app.UIFigure, 'Choose both an X and a Y variable.', 'Missing selection');
                return
            end
            if any(strcmp(predictors, xVar)) || any(strcmp(predictors, yVar))
                uialert(app.UIFigure, 'X and Y must not also be selected as predictors.', 'Overlapping selection');
                return
            end

            opts = struct();
            opts.modelOrder = app.ModelOrderDropDown.Value;
            opts.standardize = logical(app.StandardizeCheckBox.Value);
            opts.validFrac = app.ValidFracField.Value;
            opts.seed = app.SeedField.Value;
            opts.verbose = true;

            app.RunButton.Enable = 'off';
            app.ExportButton.Enable = 'off';
            app.log(sprintf('Starting fit: %d files, predictors={%s}, X=%s, Y=%s, order=%s, standardize=%d', ...
                numel(app.NCFiles), strjoin(predictors, ','), xVar, yVar, opts.modelOrder, opts.standardize));

            usedParallel = false;
            try
                pool = gcp('nocreate');
                if isempty(pool)
                    pool = parpool; %#ok<NASGU>
                end
                app.FitFuture = parfeval(@streamFitCorrection, 1, app.NCFiles, predictors, xVar, yVar, opts);
                usedParallel = true;
            catch
                usedParallel = false;
            end

            if usedParallel
                app.log('Running fit on a background worker (Parallel Computing Toolbox detected)...');
                lastLen = 0;
                while true
                    if strcmp(app.FitFuture.State, 'finished')
                        break
                    end
                    d = app.FitFuture.Diary;
                    if numel(d) > lastLen
                        newText = d(lastLen+1:end);
                        lines = strsplit(newText, newline);
                        lines = lines(~cellfun(@isempty, lines));
                        for i = 1:numel(lines)
                            app.log(lines{i});
                        end
                        lastLen = numel(d);
                    end
                    pause(0.3);
                    drawnow limitrate;
                end
                try
                    model = fetchOutputs(app.FitFuture);
                catch err
                    app.RunButton.Enable = 'on';
                    uialert(app.UIFigure, err.message, 'Fit failed');
                    return
                end
            else
                app.log('Parallel Computing Toolbox not available -- running synchronously (UI will be unresponsive; for very large jobs prefer example_run.m from the command line).');
                drawnow;
                try
                    model = streamFitCorrection(app.NCFiles, predictors, xVar, yVar, opts);
                catch err
                    app.RunButton.Enable = 'on';
                    uialert(app.UIFigure, err.message, 'Fit failed');
                    return
                end
            end

            app.FitModel = model;
            app.RunButton.Enable = 'on';
            app.ExportButton.Enable = 'on';
            app.displayResults(model);
        end

        function displayResults(app, model)
            app.log(sprintf('Done. Train R^2=%.4f RMSE=%.4g (n=%d) | Val R^2=%.4f RMSE=%.4g (n=%d)', ...
                model.R2, model.RMSE, model.n, model.valR2, model.valRMSE, model.nVal));
            app.ResultsLabel.Text = sprintf('Train R^2=%.4f  RMSE=%.4g  (n=%d)      Val R^2=%.4f  RMSE=%.4g  (n=%d)', ...
                model.R2, model.RMSE, model.n, model.valR2, model.valRMSE, model.nVal);
            app.CoefTable.Data = table(model.termNames(:), model.beta(:), ...
                'VariableNames', {'Term','Coefficient'});
            app.plotDiagnostics(model);
        end

        function plotDiagnostics(app, model)
            cla(app.DiagAxes);
            sampleFiles = model.valFiles;
            if isempty(sampleFiles), sampleFiles = model.trainFiles; end
            if isempty(sampleFiles), return; end

            try
                [data, ok] = readNetCDFChunk(sampleFiles{1}, ...
                    [model.predictorVars, {model.xVar, model.yVar}]);
                if ~ok, return; end
                k = numel(model.predictorVars);
                n = numel(data.(matlab.lang.makeValidName(model.predictorVars{1})));
                P = zeros(n, k);
                for j = 1:k
                    P(:, j) = data.(matlab.lang.makeValidName(model.predictorVars{j}));
                end
                X = data.(matlab.lang.makeValidName(model.xVar));
                Y = data.(matlab.lang.makeValidName(model.yVar));
                valid = all(isfinite(P), 2) & isfinite(X) & isfinite(Y);
                P = P(valid,:); X = X(valid); Y = Y(valid);

                % Subsample for a responsive scatter plot.
                maxPts = 20000;
                if numel(X) > maxPts
                    idx = randperm(numel(X), maxPts);
                    P = P(idx,:); X = X(idx); Y = Y(idx);
                end

                Xc = applyCorrectionModel(model, P, X);
                scatter(app.DiagAxes, Xc, Y, 6, 'filled', 'MarkerFaceAlpha', 0.3);
                hold(app.DiagAxes, 'on');
                lims = [min([Xc;Y]), max([Xc;Y])];
                plot(app.DiagAxes, lims, lims, 'r--', 'LineWidth', 1);
                hold(app.DiagAxes, 'off');
                title(app.DiagAxes, sprintf('Validation sample: %s', sampleFiles{1}), 'Interpreter', 'none');
                xlabel(app.DiagAxes, 'X corrected');
                ylabel(app.DiagAxes, model.yVar, 'Interpreter', 'none');
            catch err
                app.log(sprintf('Diagnostic plot skipped: %s', err.message));
            end
        end

        function onExport(app)
            if ~isfield(app.FitModel, 'beta')
                uialert(app.UIFigure, 'Run a fit first.', 'Nothing to export');
                return
            end
            [file, folder] = uiputfile('*.mat', 'Save model as', 'nc_correction_model.mat');
            if isequal(file, 0), return; end
            [~, name, ~] = fileparts(file);
            outPath = fullfile(folder, name);
            exportModel(app.FitModel, outPath);
            app.log(sprintf('Exported model to %s.mat and %s_coefficients.csv', outPath, outPath));
        end
    end
end
