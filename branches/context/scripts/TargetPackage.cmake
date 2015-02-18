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
        
    add_custom_target(src
        COMMAND cpack --config ${PROJECT_BINARY_DIR}/CPackConfig-Source.cmake
        COMMENT "Generating sources")        
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
    set(CPACK_INSTALL_CMAKE_PROJECTS "")
    foreach(comp ${components})
        list(APPEND CPACK_INSTALL_CMAKE_PROJECTS ${PROJECT_BINARY_DIR} ${PROJECT_NAME} ${comp} /)
    endforeach()
    # add dependencies to package
    foreach(dep ${OverallDependencies})
        if(NOT ${${dep}_IsProvided})
            sbeGetPackageBuildPath(${dep} buildPath)
            foreach(comp ${components})
                list(APPEND CPACK_INSTALL_CMAKE_PROJECTS "${buildPath}" ${dep} ${comp} /)
            endforeach()            
        endif()
    endforeach()
    
    # setup source packaging
    set(CPACK_SOURCE_OUTPUT_CONFIG_FILE "${CMAKE_BINARY_DIR}/CPackConfig-Source.cmake")
    set(CPACK_SOURCE_GENERATOR "GTGZ")
    set(CPACK_SOURCE_IGNORE_FILES /RemoteSystemsTempFiles/ /build/ /\\\\.metadata/ /CVS/ /\\\\.svn/ /\\\\.bzr/ /\\\\.hg/ /\\\\.git/ \\\\.swp\\\$ )
    set(CPACK_SOURCE_PACKAGING_INSTALL_PREFIX "")
    set(CPACK_SOURCE_PACKAGE_FILE_NAME "${PROJECT_NAME}-${version}-Source")
    # add own application into package
    string(REPLACE "${ContextRoot}" "" relativePathIncontext "${PROJECT_SOURCE_DIR}")
    list(APPEND CPACK_SOURCE_INSTALLED_DIRECTORIES ${PROJECT_SOURCE_DIR} ${relativePathIncontext})
    # add all dependencies to package
    foreach(dep ${OverallDependencies})
        sbeGetPackageLocalPath(${dep} sourcePath)
        string(REPLACE "${ContextRoot}" "" relativePathIncontext "${sourcePath}")
        list(APPEND CPACK_SOURCE_INSTALLED_DIRECTORIES "${sourcePath}" ${relativePathIncontext})
    endforeach()
    # copy context file
    foreach(gen ${CPACK_SOURCE_GENERATOR})
        set(CPACK_INSTALL_COMMANDS "${CMAKE_COMMAND} -E copy ${ContextFile} ${CPACK_PACKAGE_DIRECTORY}/_CPack_Packages/${CMAKE_SYSTEM_NAME}-Source/${gen}/${CPACK_SOURCE_PACKAGE_FILE_NAME}")
    endforeach()    
    # create config
    include(CPack)      
endfunction()