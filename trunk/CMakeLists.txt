#
# Cmake instructions file
#
cmake_minimum_required(VERSION 2.8)
 
project(CMakeScripts NONE)

file(GLOB TARGETS_SCRIPTS scripts/*.cmake)
file(GLOB TOOLS tools/*)
list(REMOVE_ITEM TOOLS "${CMAKE_SOURCE_DIR}/tools/.svn")
file(GLOB HELPERS_SCRIPTS scripts/helpers/*.cmake)
file(GLOB TEMPLATES templates/*.in)
file(GLOB TOOLCHAINS toolchains/*.cmake)
configure_file(shellScripts/sbeExportDependencies.in "${PROJECT_BINARY_DIR}/sbeExportDependencies" @ONLY)
configure_file(shellScripts/sbeUpdateToLatestDependencies.in "${PROJECT_BINARY_DIR}/sbeUpdateToLatestDependencies" @ONLY)
configure_file(shellScripts/sbeCheckNewDependencies.in "${PROJECT_BINARY_DIR}/sbeCheckNewDependencies" @ONLY)


install(FILES ${TARGETS_SCRIPTS} DESTINATION ${CMAKE_ROOT}/Modules/SBE)
install(FILES ${HELPERS_SCRIPTS} DESTINATION ${CMAKE_ROOT}/Modules/SBE/helpers)
install(FILES ${TEMPLATES} DESTINATION ${CMAKE_ROOT}/Modules/SBE/templates)
install(FILES ${TOOLCHAINS} DESTINATION ${CMAKE_ROOT}/Modules/SBE/toolchains)
install(FILES ${TOOLS} DESTINATION ${CMAKE_ROOT}/Modules/SBE/tools)
install(FILES "${PROJECT_BINARY_DIR}/sbeExportDependencies" 
        DESTINATION /usr/local/bin 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
install(FILES "${PROJECT_BINARY_DIR}/sbeUpdateToLatestDependencies" 
        DESTINATION /usr/local/bin 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)        
install(FILES "${PROJECT_BINARY_DIR}/sbeCheckNewDependencies" 
        DESTINATION /usr/local/bin 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)        
