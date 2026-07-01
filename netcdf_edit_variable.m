function netcdf_edit_variable(ncfile_in, ncfile_out, old_name, new_name, c0, c1, new_attrs)
% NETCDF_EDIT_VARIABLE  Rename a variable, apply new_calibration(x,c0,c1), write new attributes.
%
% USAGE
%   netcdf_edit_variable(ncfile_in, ncfile_out, old_name, new_name, c0, c1)
%   netcdf_edit_variable(ncfile_in, ncfile_out, old_name, new_name, c0, c1, new_attrs)
%
% INPUTS
%   ncfile_in   Path to the input NetCDF file  (preserved, never modified)
%   ncfile_out  Path to the output NetCDF file (always created fresh — will
%               overwrite if it already exists)
%   old_name    Variable name to read from the input file
%   new_name    Variable name to write in the output file
%   c0          2-element calibration vector [offset, scale] for voltage conversion
%               V = (x - c0(1)) ./ c0(2)
%   c1          2-element calibration vector [intercept, slope] for engineering units
%               y = c1(2) .* V + c1(1)
%   new_attrs   (optional) struct of attributes to write on the new variable
%               e.g.  new_attrs.units     = 'm/s';
%                     new_attrs.long_name = 'Wind Speed';
%
% CALIBRATION FUNCTION
%   y = new_calibration(x, c0, c1)
%     V = (x - c0(1)) ./ c0(2);
%     y = c1(2) .* V + c1(1);
%
% WORKFLOW FOR MULTIPLE VARIABLES
%   Chain calls, passing each output as the next input:
%     netcdf_edit_variable('20260630_raw.nc',  '20260630a_raw.nc', 'dev6289-0-AI5', 'DPN',  c0, c1, atts1);
%     netcdf_edit_variable('20260630a_raw.nc', '20260630b_raw.nc', 'dev6289-0-AI6', 'DPT',  c0, c1, atts2);
%     netcdf_edit_variable('20260630b_raw.nc', '20260630c_raw.nc', 'dev6289-0-AI7', 'DPQC', c0, c1, atts3);
%
% NOTES
%   - Each call does a full copy of ncfile_in to ncfile_out, renaming and
%     transforming the target variable.  ncfile_in is never modified.
%   - All other variables, dimensions, and global attributes are copied as-is.
%   - Transform is applied element-wise after flattening, then reshaped to
%     original dimensions (mirrors MATLAB's x = x(:) idiom).

    if nargin < 7
        new_attrs = struct();
    end

    % Validate calibration vectors
    if numel(c0) < 2 || numel(c1) < 2
        error('c0 and c1 must each have at least 2 elements.');
    end

    % -----------------------------------------------------------------------
    % 1. Validate inputs
    % -----------------------------------------------------------------------
    if ~isfile(ncfile_in)
        error('Input file not found: %s', ncfile_in);
    end
    if isfile(ncfile_out)
        fprintf('Output file exists — deleting and recreating: %s\n', ncfile_out);
        delete(ncfile_out);
    end

    % -----------------------------------------------------------------------
    % 2. Inspect source file
    % -----------------------------------------------------------------------
    info = ncinfo(ncfile_in);

    var_names = {info.Variables.Name};
    if ~any(strcmp(var_names, old_name))
        error('Variable "%s" not found in %s.\nAvailable variables: %s', ...
              old_name, ncfile_in, strjoin(var_names, ', '));
    end

    fprintf('Input  : %s\n', ncfile_in);
    fprintf('Output : %s\n', ncfile_out);
    fprintf('Rename : "%s"  -->  "%s"\n', old_name, new_name);
    fprintf('Transform: V=(x-c0(1))/c0(2);  y=c1(2)*V+c1(1)\n');
    fprintf('  c0 = [%s]\n', num2str(c0(:)', '%-10.6g '));
    fprintf('  c1 = [%s]\n', num2str(c1(:)', '%-10.6g '));

    % -----------------------------------------------------------------------
    % 3. Full copy: rename + transform target, copy everything else as-is
    % -----------------------------------------------------------------------
    copy_nc_file(info, ncfile_in, ncfile_out, old_name, new_name, c0, c1, new_attrs);

    % -----------------------------------------------------------------------
    % 4. Verify
    % -----------------------------------------------------------------------
    out_info  = ncinfo(ncfile_out);
    out_names = {out_info.Variables.Name};
    if ~any(strcmp(out_names, new_name))
        error('Verification failed: variable "%s" not found in output.', new_name);
    end

    y_check = ncread(ncfile_out, new_name);
    fprintf('\nVerification OK\n');
    fprintf('  Variable "%s"  size=%s  range=[%g, %g]\n', ...
            new_name, mat2str(size(y_check)), min(y_check(:)), max(y_check(:)));

    attr_names = fieldnames(new_attrs);
    for k = 1:numel(attr_names)
        fprintf('  Attribute "%s" = %s\n', attr_names{k}, ...
                format_attr_val(new_attrs.(attr_names{k})));
    end

    fprintf('\nDone.\n');
end


% ===========================================================================
% Full copy: rename target variable, transform it, copy everything else.
% Uses ncwriteschema for robust schema creation (preserves compression,
% chunking, unlimited dims, variable attributes, global attributes).
% ===========================================================================
function copy_nc_file(info, ncfile_in, ncfile_out, old_name, new_name, c0, c1, new_attrs)

    % ---- Rename target in the schema struct --------------------------------
    target_idx = [];
    for k = 1:numel(info.Variables)
        if strcmp(info.Variables(k).Name, old_name)
            info.Variables(k).Name = new_name;
            target_idx = k;
            break;
        end
    end

    % ---- Write full schema (creates file, all dims/vars/attrs at once) -----
    ncwriteschema(ncfile_out, info);

    % ---- Write data for every variable ------------------------------------
    fprintf('Copying variables');
    for k = 1:numel(info.Variables)
        var_out   = info.Variables(k).Name;
        is_target = (k == target_idx);
        var_in    = var_out;
        if is_target
            var_in = old_name;
        end

        data = ncread(ncfile_in, var_in);

        if is_target
            orig_size = size(data);
            flat = data(:);
            flat = new_calibration(flat, c0, c1);
            data = reshape(flat, orig_size);
            fprintf(' [%s->%s]', old_name, new_name);
        else
            fprintf('.');
        end

        ncwrite(ncfile_out, var_out, data);
    end
    fprintf(' done.\n');

    % ---- Add / overwrite new attributes on the renamed variable -----------
    attr_names = fieldnames(new_attrs);
    for j = 1:numel(attr_names)
        ncwriteatt(ncfile_out, new_name, attr_names{j}, new_attrs.(attr_names{j}));
    end
end


% ===========================================================================
% Calibration function
% ===========================================================================
function y = new_calibration(x, c0, c1)
% NEW_CALIBRATION  Apply two-stage linear calibration.
%   V = (x - c0(1)) ./ c0(2);   % convert raw counts to voltage
%   y = c1(2) .* V + c1(1);     % convert voltage to engineering units
    V = (x - c0(1)) ./ c0(2);
    y = c1(2) .* V + c1(1);
end


% ===========================================================================
% Helper: format an attribute value for display
% ===========================================================================
function s = format_attr_val(v)
    if isnumeric(v)
        s = num2str(v);
    elseif ischar(v) || isstring(v)
        s = sprintf('"%s"', v);
    else
        s = class(v);
    end
end