cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetPackageGuard)
    return()
endif()

set(TargetPackageGuard yes)

set(isAddPackageCalled no)

include(SBE/helpers/PropertiesParser)
include(SBE/helpers/ContextParser)
include(SBE/helpers/ArgumentParser)

function(sbeAddPackageTarget)
#    _CreateCPackConfig(SRE Distribution yes)
#    
#    add_custom_target(sre
#        COMMAND cpack --config ${PROJECT_BINARY_DIR}/CPackConfig-SRE.cmake
#        COMMENT "Generating SRE")
#
#    _CreateCPackConfig(SDK "Configs;Distribution;Mocks;Headers" no)
#    
#    add_custom_target(sdk
#        COMMAND cpack --config ${PROJECT_BINARY_DIR}/CPackConfig-SDK.cmake
#        COMMENT "Generating SDK")
    
   
    set(isAddPackageCalled yes PARENT_SCOPE)
    
    cmake_parse_arguments(pkg "" "Name" "" ${ARGN})
    
    add_custom_target(package)
    
    if(TARGET dependencies)
        add_dependencies(package dependencies)
    endif()
    
    foreach(target ${InstalledTargets})
        add_dependencies(package ${target})
    endforeach()

    set(DO_STRIP "")
    if(${CMAKE_CROSSCOMPILING})
       # usually we have no much space on tagret platform
        set(DO_STRIP "-DCMAKE_INSTALL_DO_STRIP=yes") 
    endif()

    add_custom_command(TARGET package
        COMMAND cmake -E remove_directory ${PROJECT_BINARY_DIR}/package
        COMMAND cmake -E make_directory ${PROJECT_BINARY_DIR}/package/data/${SBE_DEFAULT_PACKAGE_PATH}
        COMMAND cmake -DCMAKE_INSTALL_COMPONENT=Distribution -DBUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${PROJECT_BINARY_DIR}/package/data/${SBE_DEFAULT_PACKAGE_PATH} ${DO_STRIP} -P cmake_install.cmake 
        COMMENT "Preinstalling...")
    
   # reinstall
    foreach(dep ${OverallDependencies})
        if(${${dep}_IsProvided})
            add_custom_command(TARGET package
                COMMENT "Skipping provided dependecy ${dep}...")
        else()
            sbeGetPackageBuildPath(${dep} buildPath)
            add_custom_command(TARGET package
                COMMAND cmake -DCMAKE_INSTALL_COMPONENT=Distribution -DBUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${PROJECT_BINARY_DIR}/package/data/${SBE_DEFAULT_PACKAGE_PATH} ${DO_STRIP} -P ${buildPath}/cmake_install.cmake
                COMMENT "Adding dependecy ${dep} to package...")
        endif()
        
    endforeach()
    
    sbeGetVersionText(version)    
    if(DEFINED pkg_Name)
        set(packageFileName "${pkg_Name}-${version}-${CMAKE_BUILD_TYPE}-${SBE_BOARD_FAMILY_NAME}-${SBE_SYSTEM_NAME}-${SBE_SYSTEM_EXTENSION_NAME}.tar.gz")
    else()
        set(packageFileName "${PROJECT_NAME}-${version}-${CMAKE_BUILD_TYPE}-${SBE_BOARD_FAMILY_NAME}-${SBE_SYSTEM_NAME}-${SBE_SYSTEM_EXTENSION_NAME}.tar.gz")
    endif()
    
    add_custom_command(TARGET package
        COMMAND cmake -E chdir ./package/data tar -czf ../${packageFileName} .
        COMMENT "Tar ${packageFileName}...")

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