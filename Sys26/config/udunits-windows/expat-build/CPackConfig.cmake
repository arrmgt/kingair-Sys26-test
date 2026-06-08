# This file will be configured to contain variables for CPack. These variables
# should be set in the CMake list file of the project before CPack module is
# included. The list of available CPACK_xxx variables and their associated
# documentation may be obtained using
#  cpack --help-variable-list
#
# Some variables are common to all generators (e.g. CPACK_PACKAGE_NAME)
# and some are specific to a generator
# (e.g. CPACK_NSIS_EXTRA_INSTALL_COMMANDS). The generator specific variables
# usually begin with CPACK_<GENNAME>_xxxx.


set(CPACK_BUILD_SOURCE_DIRS "C:/Users/rodi/Github/kingair-Sys26/Sys26/config/udunits-windows/expat-2.7.4;C:/Users/rodi/Github/kingair-Sys26/Sys26/config/udunits-windows/expat-build")
set(CPACK_CMAKE_GENERATOR "MinGW Makefiles")
set(CPACK_COMPONENT_UNSPECIFIED_HIDDEN "TRUE")
set(CPACK_COMPONENT_UNSPECIFIED_REQUIRED "TRUE")
set(CPACK_DEFAULT_PACKAGE_DESCRIPTION_FILE "C:/Program Files/mingw64/share/cmake-3.28/Templates/CPack.GenericDescription.txt")
set(CPACK_DEFAULT_PACKAGE_DESCRIPTION_SUMMARY "expat built using CMake")
set(CPACK_GENERATOR "ZIP")
set(CPACK_INNOSETUP_ARCHITECTURE "x64")
set(CPACK_INSTALL_CMAKE_PROJECTS "C:/Users/rodi/Github/kingair-Sys26/Sys26/config/udunits-windows/expat-build;expat;ALL;/")
set(CPACK_INSTALL_PREFIX "C:/Users/rodi/Github/kingair-Sys26/Sys26/config/udunits-windows/expat-install")
set(CPACK_MODULE_PATH "")
set(CPACK_NSIS_DISPLAY_NAME "expat 2.7.4")
set(CPACK_NSIS_INSTALLER_ICON_CODE "")
set(CPACK_NSIS_INSTALLER_MUI_ICON_CODE "")
set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
set(CPACK_NSIS_PACKAGE_NAME "expat 2.7.4")
set(CPACK_NSIS_UNINSTALL_NAME "Uninstall")
set(CPACK_OBJCOPY_EXECUTABLE "C:/ProgramData/MATLAB/SupportPackages/R2025b/3P.instrset/mingw_w64.instrset/bin/objcopy.exe")
set(CPACK_OBJDUMP_EXECUTABLE "C:/ProgramData/MATLAB/SupportPackages/R2025b/3P.instrset/mingw_w64.instrset/bin/objdump.exe")
set(CPACK_OUTPUT_CONFIG_FILE "C:/Users/rodi/Github/kingair-Sys26/Sys26/config/udunits-windows/expat-build/CPackConfig.cmake")
set(CPACK_PACKAGE_DEFAULT_LOCATION "/")
set(CPACK_PACKAGE_DESCRIPTION_FILE "C:/Program Files/mingw64/share/cmake-3.28/Templates/CPack.GenericDescription.txt")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "expat built using CMake")
set(CPACK_PACKAGE_FILE_NAME "expat-2.7.4-win64")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "expat 2.7.4")
set(CPACK_PACKAGE_INSTALL_REGISTRY_KEY "expat 2.7.4")
set(CPACK_PACKAGE_NAME "expat")
set(CPACK_PACKAGE_RELOCATABLE "true")
set(CPACK_PACKAGE_VENDOR "Humanity")
set(CPACK_PACKAGE_VERSION "2.7.4")
set(CPACK_PACKAGE_VERSION_MAJOR "2")
set(CPACK_PACKAGE_VERSION_MINOR "7")
set(CPACK_PACKAGE_VERSION_PATCH "4")
set(CPACK_READELF_EXECUTABLE "C:/ProgramData/MATLAB/SupportPackages/R2025b/3P.instrset/mingw_w64.instrset/bin/readelf.exe")
set(CPACK_RESOURCE_FILE_LICENSE "C:/Program Files/mingw64/share/cmake-3.28/Templates/CPack.GenericLicense.txt")
set(CPACK_RESOURCE_FILE_README "C:/Program Files/mingw64/share/cmake-3.28/Templates/CPack.GenericDescription.txt")
set(CPACK_RESOURCE_FILE_WELCOME "C:/Program Files/mingw64/share/cmake-3.28/Templates/CPack.GenericWelcome.txt")
set(CPACK_SET_DESTDIR "OFF")
set(CPACK_SOURCE_GENERATOR "''")
set(CPACK_SOURCE_OUTPUT_CONFIG_FILE "C:/Users/rodi/Github/kingair-Sys26/Sys26/config/udunits-windows/expat-build/CPackSourceConfig.cmake")
set(CPACK_SYSTEM_NAME "win64")
set(CPACK_THREADS "1")
set(CPACK_TOPLEVEL_TAG "win64")
set(CPACK_WIX_SIZEOF_VOID_P "8")

if(NOT CPACK_PROPERTIES_FILE)
  set(CPACK_PROPERTIES_FILE "C:/Users/rodi/Github/kingair-Sys26/Sys26/config/udunits-windows/expat-build/CPackProperties.cmake")
endif()

if(EXISTS ${CPACK_PROPERTIES_FILE})
  include(${CPACK_PROPERTIES_FILE})
endif()
