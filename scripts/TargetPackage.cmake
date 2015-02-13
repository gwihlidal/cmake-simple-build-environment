# minimal version should be 3.1.3 because in this version GTGZ target is added 
cmake_minimum_required(VERSION 3.1.3)

if (DEFINED TargetPackageGuard)
    return()
endif()

set(TargetPackageGuard yes)

set(isAddPackageCalled no)

include(SBE/helpers/PropertiesParser)
include(SBE/helpers/ContextParser)
include(SBE/helpers/ArgumentParser)

function(sbeAddPackageTarget)
    _CreateCPackConfig(SRE Production yes)
    
    add_custom_target(sre
        COMMAND cpack --config ${PROJECT_BINARY_DIR}/CPackConfig-SRE.cmake
        COMMENT "Generating SRE")

    _CreateCPackConfig(SDK "Configs;Production;Tests;Mocks;Headers" no)
    
    add_custom_target(sdk
        COMMAND cpack --config ${PROJECT_BINARY_DIR}/CPackConfig-SDK.cmake
        COMMENT "Generating SDK")
    
endfunction()                

function(_CreateCPackConfig packageType components strip)
    set(CPACK_OUTPUT_CONFIG_FILE "${CMAKE_BINARY_DIR}/CPackConfig-${packageType}.cmake")
    # set type of package
    set(CPACK_GENERATOR "GTGZ")
    # set basic package data
    set(CPACK_PACKAGE_DIRECTORY ${CMAKE_BINARY_DIR}/package)
    sbeGetVersionText(version)
    set(CPACK_PACKAGE_VERSION ${version})    
    set(CPACK_PACKAGE_NAME "${PROJECT_NAME}-${version}-${CMAKE_BUILD_TYPE}-${SBE_BOARD_FAMILY_NAME}-${SBE_SYSTEM_NAME}-${SBE_SYSTEM_EXTENSION_NAME}-${packageType}")
    set(CPACK_PACKAGE_FILE_NAME ${CPACK_PACKAGE_NAME})
    if(strip)
        set(CPACK_STRIP_FILES yes) 
    endif()
    if(DEFINED SemanticVersion)
        include(SBE/helpers/VersionParser)    
        sbeSplitSemanticVersion(${SemanticVersion} major minor bugfix)
        set(CPACK_PACKAGE_VERSION_MAJOR ${major})
        set(CPACK_PACKAGE_VERSION_MINOR ${minor})
        set(CPACK_PACKAGE_VERSION_PATCH ${bugfix})       
    endif()
    set(CPACK_PACKAGING_INSTALL_PREFIX ${SBE_DEFAULT_PACKAGE_PATH})
    set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY no)
    set(CPACK_COMPONENTS_ALL ${components})
    # add dependencies to package
    set(CPACK_INSTALL_CMAKE_PROJECTS ${PROJECT_BINARY_DIR} ${PROJECT_NAME} "ALL" /)
    foreach(dep ${OverallDependencies})
        if(NOT ${${dep}_IsProvided})
            sbeGetPackageBuildPath(${dep} buildPath)
            list(APPEND CPACK_INSTALL_CMAKE_PROJECTS "${buildPath}" ${dep} "ALL" /)
        endif()
    endforeach()
    
    # setup source packaging
    set(CPACK_SOURCE_OUTPUT_CONFIG_FILE "${CMAKE_BINARY_DIR}/CPackSourceConfig-${packageType}.cmake")
    set(CPACK_SOURCE_GENERATOR "GTGZ")
    set(CPACK_SOURCE_IGNORE_FILES /build/ /CVS/ /\\\\.svn/ /\\\\.bzr/ /\\\\.hg/ /\\\\.git/ \\\\.swp\\\$ )
    
    # create config
    include(CPack)      
endfunction()