function copyRawAtts(rawpath,rawvar, outpath,outvar )
% COPYANALOGATTS - copy attributes from variables in the raw file
% to the processed file, excluding ones that we don't want.

x=ncinfo(rawpath,rawvar);
anames={x.Attributes.Name};
attrs={x.Attributes.Value};


% Loop through the attributes from the raw variable
  for j = 1:numel(anames);
        % Convert cell to ncatt;
        name = anames{j};
        attr = attrs{j};

        switch name
% Exclude the attributes we don't want in the output file
        case { ...
        'group','DataType','DataTypeCode', ...
        'ExternalCutoff','ExternalGain','ExternalMax','ExternalMin', ...
        'InternalCutoff','InternalGain','InternalMax','InternalMin', ...
        'AnalogCalibration','AnalogCalibrationDate', ...
        'Used','VariableName','tdms_name', 'SampleRate' }
       % Do nothing
% Copy the attribute to the header.IDENT.nc file
        otherwise
            name=strrep(name,'_FillValue','FillValue'); 
            ncwriteatt(outpath,outvar,name,attr);
        end
  end
