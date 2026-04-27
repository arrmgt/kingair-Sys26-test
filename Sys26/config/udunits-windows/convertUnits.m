function y = convertUnits(x, fromUnit, toUnit)
%CONVERT_UNITS Converts a value using UDUNITS2 via MEX
    xml_path = getenv("UDUNITS2_XML_PATH");
    if isempty(xml_path)
        error("UDUNITS2_XML_PATH is not set");
    end
    y = mex_udunits2(x, fromUnit, toUnit, xml_path);
    if isnan(y)
	x = y;
    end
end

