#
# Cmake instructions file
#
cmake_minimum_required(VERSION 2.8)
 
project(CMakeScripts NONE)

file(GLOB TARGETS_SCRIPTS scripts/*.cmake)
file(GLOB DOCUMENTATION_SCRIPTS scripts/documentation/*.cmake)
file(GLOB TOOLS tools/*)
list(REMOVE_ITEM TOOLS "${CMAKE_SOURCE_DIR}/tools/.svn")
file(GLOB HELPERS_SCRIPTS scripts/helpers/*.cmake)
file(GLOB SHELL_SCRIPTS shellScripts/*.cmake)
file(GLOB TEMPLATES templates/*.in)

configure_file(shellScripts/sbeExportPackage.in "${PROJECT_BINARY_DIR}/sbeExportPackage" @ONLY)
configure_file(shellScripts/sbeUpdateToLatestDependencies.in "${PROJECT_BINARY_DIR}/sbeUpdateToLatestDependencies" @ONLY)
configure_file(shellScripts/sbeCheckNewDependencies.in "${PROJECT_BINARY_DIR}/sbeCheckNewDependencies" @ONLY)
configure_file(shellScripts/sbeConfigurePackage.in "${PROJECT_BINARY_DIR}/sbeConfigurePackage" @ONLY)
configure_file(shellScripts/sbeDecorateDoxygen.in "${PROJECT_BINARY_DIR}/sbeDecorateDoxygen" @ONLY)


install(FILES ${TARGETS_SCRIPTS} DESTINATION ${CMAKE_ROOT}/Modules/SBE)
install(FILES ${DOCUMENTATION_SCRIPTS} DESTINATION ${CMAKE_ROOT}/Modules/SBE/documentation)
install(FILES ${HELPERS_SCRIPTS} DESTINATION ${CMAKE_ROOT}/Modules/SBE/helpers)
install(FILES ${SHELL_SCRIPTS} DESTINATION ${CMAKE_ROOT}/Modules/SBE/shellScripts)
install(FILES ${TEMPLATES} DESTINATION ${CMAKE_ROOT}/Modules/SBE/templates)
install(FILES ${TOOLS} DESTINATION ${CMAKE_ROOT}/Modules/SBE/tools)
install(FILES "${CMAKE_SOURCE_DIR}/shellScripts/printAndExecuteCommand" 
        DESTINATION ${CMAKE_ROOT}/Modules/SBE/tools 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
install(FILES "${CMAKE_SOURCE_DIR}/shellScripts/coverityLauncher.in"
        DESTINATION ${CMAKE_ROOT}/Modules/SBE/tools
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
install(FILES "${PROJECT_BINARY_DIR}/sbeConfigurePackage" 
        DESTINATION /usr/local/bin 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
install(FILES "${PROJECT_BINARY_DIR}/sbeExportPackage" 
        DESTINATION /usr/local/bin 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
install(FILES "${PROJECT_BINARY_DIR}/sbeUpdateToLatestDependencies" 
        DESTINATION /usr/local/bin 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)        
install(FILES "${PROJECT_BINARY_DIR}/sbeCheckNewDependencies" 
        DESTINATION /usr/local/bin 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)        
install(FILES "${PROJECT_BINARY_DIR}/sbeDecorateDoxygen" 
        DESTINATION /usr/local/bin 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)        
