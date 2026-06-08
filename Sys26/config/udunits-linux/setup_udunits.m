function setup_udunits(xml_path)
%SETUP_UDUNITS Sets the UDUNITS2_XML_PATH environment variable
    if ~isfile(xml_path)
        error("setup_udunits:invalidPath", "XML file does not exist: %s", xml_path);
    end
    setenv('UDUNITS2_XML_PATH', xml_path);
    fprintf("✅ UDUNITS2_XML_PATH set to: %s\n", xml_path);
end

