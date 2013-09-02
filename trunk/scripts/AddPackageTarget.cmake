add_custom_target(package)

function(addPackageTarget)
    if(NOT isAddInstallCalled)
        add_custom_command(TARGET package
            COMMENT "No install target, nothing to package.")
        return()    
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
        COMMAND cmake -DCMAKE_INSTALL_COMPONENT=Binaries -DBUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${PROJECT_BINARY_DIR}/package${PACKAGE_INSTALL_PREFIX} ${DO_STRIP} -P cmake_install.cmake 
        COMMENT "Preinstalling...")
        
    # reinstall
    if(NOT "${OverallDependencies}" STREQUAL "")
        
        foreach(dep ${OverallDependencies})
            set(depName ${${dep}_Name})
            
            if(("${${dep}_Type}" STREQUAL "Library") OR ("${${dep}_Type}" STREQUAL "Executable"))
                if(${${dep}_IsExternal})
                    add_custom_command(TARGET package
                        COMMENT "Skipping external dependecy ${depName}...")
                else()
                    add_custom_command(TARGET package
                        COMMAND cmake -DCMAKE_INSTALL_COMPONENT=Binaries -DBUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${PROJECT_BINARY_DIR}/package${PACKAGE_INSTALL_PREFIX} ${DO_STRIP} -P ${${dep}_BuildPath}/build/cmake_install.cmake
                        COMMENT "Adding dependecy ${depName} to package...")
                endif()
            endif()
            
        endforeach()
    endif()    
        
    set(PACKAGE_FILE_NAME "${PROJECT_NAME}-${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}-${CMAKE_SYSTEM_PROCESSOR}-${CMAKE_BUILD_TYPE}.tar.gz")
    
    if(EXISTS ./package)
        add_custom_command(TARGET package
            COMMAND cmake -E chdir ./package tar --exclude=${PACKAGE_FILE_NAME} -czf ${PACKAGE_FILE_NAME} .
            COMMENT "Tar ${PACKAGE_FILE_NAME}...")
    else()
        add_custom_command(TARGET package
            COMMENT "There is nothing to package...")
    endif()
endfunction()                
