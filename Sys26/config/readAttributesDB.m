function [varargout] = readAttributesDB(varargin)
%function [name, type, OutputRate,attributes, values] = readAttributeDB(dbfile, varName, ProcessingRate, suffixDefaults, suffixValues)
%READATTRIBUTEDB Read variable attributes from an SQLite database.
%
%   Reads all attributes for the variable `varName` from the SQLite
%   database file `dbfile`.
%
%   If only one input variable, then it returns an list
%       of unique variable names. Otherwise:
%
%   Optional Inputs:
%     ProcessingRate   - Processing rate to be sustituted for default XX
%     suffixDefaults   - Cell array of substrings in variable names to replace.
%     suffixValues     - Replacement substrings for suffixDefaults.
%
%   Outputs:
%     names            - Variable names (possibly suffix-edited)
%     attributes       - Attribute names for the matched variables
%     OutputRate       - Actual output rate (some are not the nominal rate)
%     values           - Corresponding attribute values
%     type             - Type of the first matched variable

    cleanupObj = onCleanup(@() close(conn));
    dbfile = varargin{1};
    
    conn = sqlite(dbfile);
        
    % Fetch all records
    try
        data=sqlread(conn,'variables');
    catch ME
        error('Failed to fetch data from table "variables": %s', ME.message);
    end

    % Extract columns
    [name,ia] = unique(data.name,"stable");
    type = data.name(ia(1));
    
    if(numel(varargin)<2)
        varargout{1} = name; 
        return
    end

    % fix up
    data.type(1:52)='Float';
    data.type(1)='Double';
    %Save
    data0=data;
    sqlwrite(conn,'variables1',data0);
    close(conn)
   
    names = data.name;
    varName = varargin{2};
    
    % Find matching variable(s)
    idx = find(strcmp(names, varName));
    if isempty(idx)
        error('Variable "%s" not found in database.', varName);
    end
    
    name = varName;
    attributes = data.attribute(idx);
    values = data.value(idx);
    type = data.type(idx(1)); 

    ProcessingRate = varargin{3};

    % Apply default XX = OutputRate
    if ~isempty(ProcessingRate) 
        values = strrep(values, "XX", num2str(ProcessingRate));
    end

    idx=find(contains(attributes,'OutputRate'));
    OutputRate = str2num(values(idx));
    
    varargout{1} = varName; 
    varargout{2} = type;
    varargout{3} = OutputRate;
    varargout{4} = attributes;
    varargout{5} = values;

    
end

