kingair-Sys26 (1/22/2026)

Matlab scripts for processing past University of Wyoming aircraft data utilizing new air motion equations and updated scripts by Al Rodi based on Sys09. 
Raw aircraft .tdms data file must have been previously converted to the _raw.nc file.

Procedure (specifically for medicinebow, though kingair-Sys26 should also work on windows):

0.	Initial setup of kingair-Sys26 on the medicinebow cluster:
	- Unzip kingair-Sys26 in your home directory, if necessary rename to kingair-Sys26
	- Edit permissions for kingair-Sys26 recursively to octal mode 775 (to also allow write for user and group)
	- Copy udunits-linux from /project/uwka/src/ into your kingair-Sys26/Sys26/ folder: cp -r /project/uwka/src/udunits-linux /home/<username>/kingair-Sys26/Sys26/
	- Within each project, e.g. kingair-Sys26/snowie17/, modify do_batch25.m: replace rodi or nkille with your username in the paths for Repo and scratchDir
	- At the main folder level (kingair-Sys26/), modify do_all.m: update Source path for medicinebow
	- Open Matlab, change current folder to /home/<username>/kingair-Sys26/Sys26/udunits-linux/ and run make_mex.m
	
1. Prepare kingair-Sys26 for processing:
	- At the main folder level (kingair-Sys26), edit do_all.m: change projes_out, rawnames, and projs to process specific files. Use initials in projs_out to avoid overwriting existing files!
	- Open Matlab, change current folder to /home/<username>/kingair-Sys26/ and run do_all.m
		
2. Processing begins, data groupings are computed in modules
  get_varTAS(X);	% Compute temp, pressure,flow angle, and pressure correction     
  get_varAV410RT(X);	% Retrieve real-time applanix IMU/GPS data     
  get_varAV410PP(X);	% Retrieve PosPac applanix post-processed IMU/GPS data     
  get_varWINDRT(X);	% Compute winds from real-time IMU/GPS data     
  get_varWINDPP(X);	% Compute winds from post-processed IMU/GPS data     
  get_varLWC301(X);	% Compute LWC from DMT LWC301 system     
  % etc.  

3. On medicinebow, processed netcdf output will be located in the folder /alcova/kingairfacility/kingair_data/<project>/work/ with the file name that was specified in projs_out within do_all.m (see step 1.)
	- Note: there are additional, simulated variables in the netcdf created by Sys26 compared to Sys09 (such as dp1New858), as Sys26 is going to be the basis for Sys26 for the new aircraft with the new R858 transducers
