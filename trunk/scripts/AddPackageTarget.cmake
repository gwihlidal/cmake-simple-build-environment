if(isAddPackageTargetIncluded)
    return()
endif()

set(isAddPackageTargetIncluded yes)
set(isAddPackageCalled no)

include(SBE/helpers/DependenciesParser)

add_custom_target(package)

function(addPackageTarget)
    set(isAddPackageCalled yes PARENT_SCOPE)
    
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
    foreach(dep ${${NAME}_OverallDependencies})
        if("${${dep}_Type}" STREQUAL "")
            if(${${dep}_IsExternal})
                add_custom_command(TARGET package
                    COMMENT "Skipping external dependecy ${dep}...")
            else()
                add_custom_command(TARGET package
                    COMMAND cmake -DCMAKE_INSTALL_COMPONENT=Distribution -DBUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${PROJECT_BINARY_DIR}/package/data/${SBE_DEFAULT_PACKAGE_PATH} ${DO_STRIP} -P ${DEP_SOURCES_PATH}/${dep}/build/${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}/cmake_install.cmake
                    COMMENT "Adding dependecy ${dep} to package...")
            endif()
        endif()
        
    endforeach()
        
    set(PACKAGE_FILE_NAME "${PROJECT_NAME}-${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}-${CMAKE_BUILD_TYPE}-${SBE_ARCHITECTURE_NAME}-${SBE_SYSTEM_NAME}-${SBE_SYSTEM_EXTENSION_NAME}.tar.gz")
    
    add_custom_command(TARGET package
        COMMAND cmake -E chdir ./package/data tar -czf ../${PACKAGE_FILE_NAME} .
        COMMENT "Tar ${PACKAGE_FILE_NAME}...")

endfunction()                
