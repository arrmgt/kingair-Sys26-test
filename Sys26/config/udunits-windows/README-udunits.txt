UDUNITS2 Portable MATLAB Package
=================================

This folder contains a ready-to-use MATLAB interface for the UDUNITS2 C library.
No installation or compilation is required if you're on a 64-bit Windows machine
and using a compatible MATLAB version.

Files included:
---------------
- mex_udunits2.mexw64        : Compiled MEX gateway to the UDUNITS2 C library
- convertUnits.m            : User-friendly MATLAB wrapper function
- setup_udunits.m            : Initializes UDUNITS2 by setting the XML path
- udunits2.xml               : Main UDUNITS2 XML configuration
- udunits2-*.xml             : Required XML subfiles imported by udunits2.xml
- (Optional) libudunits2.dll, libexpat.dll if not statically linked

Usage:
------

1. Open MATLAB.
2. Navigate to this folder in MATLAB.
3. Run:

    >> setup_udunits;
    >> convertUnits(1, 'km', 'm')   % Returns: 1000

Note:
-----
If you get an error like "Failed to initialize UDUNITS2", ensure all the
`.xml` files are present in the same directory as `mex_udunits2.mexw64`.

Contact:
--------
Packaged by: [Your Name]
Original UDUNITS2 library: https://www.unidata.ucar.edu/software/udunits/
