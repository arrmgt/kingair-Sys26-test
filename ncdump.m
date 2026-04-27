function ncdump(filename, varargin)
% ncdump_cdl(filename)
% ncdump_cdl(filename,'-h')
% ncdump_cdl(filename,'-v','TIME')
%
% Emulates basic NCAR ncdump functionality.

info = ncinfo(filename);

% -----------------------
% Parse options
% -----------------------
headerOnly = false;
varList = [];

if nargin > 1
    if strcmp(varargin{1},'-h')
        headerOnly = true;
    elseif strcmp(varargin{1},'-v')
        varList = varargin{2};
        if ischar(varList)
            varList = {varList};
        end
    end
end

[~, name, ext] = fileparts(filename);
fprintf('netcdf \\%s%s {\n', name, ext);

%% =======================
%% Dimensions
%% =======================
fprintf('dimensions:\n');
for i = 1:length(info.Dimensions)
    dim = info.Dimensions(i);
    if dim.Unlimited
        fprintf('\t%s = UNLIMITED ; // (%d currently)\n', ...
            dim.Name, dim.Length);
    else
        fprintf('\t%s = %d ;\n', dim.Name, dim.Length);
    end
end

%% =======================
%% Variables (Header Part)
%% =======================
fprintf('variables:\n');

for i = 1:length(info.Variables)
    var = info.Variables(i);

    % If -v used, skip header printing of others
    if ~isempty(varList) && ~ismember(var.Name,varList)
        continue
    end

    cdlType = matlab2cdltype(var.Datatype);
    dimStr = strjoin({var.Dimensions.Name}, ', ');

    fprintf('\t%s %s(%s) ;\n', cdlType, var.Name, dimStr);

    for j = 1:length(var.Attributes)
        att = var.Attributes(j);
        val = format_cdl_value(att.Value, cdlType);
        fprintf('\t\t%s:%s = %s ;\n', ...
            var.Name, att.Name, val);
    end
end

%% =======================
%% Global Attributes
%% =======================
if isempty(varList)
    if ~isempty(info.Attributes)
        fprintf('\n// global attributes:\n');
        for i = 1:length(info.Attributes)
            att = info.Attributes(i);
            val = format_cdl_value(att.Value,'');
            fprintf('\t\t:%s = %s ;\n', att.Name, val);
        end
    end
end

%% =======================
%% Data Section
%% =======================
if ~headerOnly
    fprintf('\ndata:\n');

    for i = 1:length(info.Variables)
        var = info.Variables(i);

        if ~isempty(varList) && ~ismember(var.Name,varList)
            continue
        end

        data = ncread(filename,var.Name);

        fprintf('\n %s =\n', var.Name);
        print_cdl_data(data, var.Datatype);
        fprintf(' ;\n');
    end
end

fprintf('}\n');

end

function t = matlab2cdltype(matType)
switch matType
    case 'double'
        t = 'double';
    case 'single'
        t = 'float';
    case 'int8'
        t = 'byte';
    case 'uint8'
        t = 'ubyte';
    case 'int16'
        t = 'short';
    case 'uint16'
        t = 'ushort';
    case 'int32'
        t = 'int';
    case 'uint32'
        t = 'uint';
    case 'int64'
        t = 'int64';
    case 'uint64'
        t = 'uint64';
    case 'char'
        t = 'char';
    otherwise
        t = matType;
end
end

function s = format_cdl_value(val, cdlType)

if ischar(val) || isstring(val)
    s = sprintf('"%s"', val);

elseif isnumeric(val)
    if isscalar(val)
        if strcmp(cdlType,'float')
            s = sprintf('%g.f', val);
        else
            s = sprintf('%g', val);
        end
    else
        if strcmp(cdlType,'float')
            s = sprintf('%g.f, ', val);
        else
            s = sprintf('%g, ', val);
        end
        s = s(1:end-2);
    end
else
    s = '"[unsupported]"';
end

end

function print_cdl_data(data, datatype)

data = data(:);

if strcmp(datatype,'single')
    suffix = '.f';
else
    suffix = '';
end

for i = 1:length(data)
    if mod(i-1,6)==0
        fprintf('\t');
    end

    if isnumeric(data)
        fprintf('%g%s', data(i), suffix);
    elseif ischar(data)
        fprintf('"%s"', data(i));
    end

    if i ~= length(data)
        fprintf(', ');
    end

    if mod(i,6)==0
        fprintf('\n');
    end
end

fprintf('\n');

end

