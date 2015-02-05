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
    set(isAddPackageCalled yes PARENT_SCOPE)
    
    cmake_parse_arguments(pkg "" "Name" "" ${ARGN})
    
    add_custom_target(package)
    sbeAddHelpForTarget(Other package "Create tar.gz")
    
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
