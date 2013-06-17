
add_custom_target(package)

foreach(lib ${INSTALL_LIBRARIES})
    add_dependencies(package ${lib})
endforeach()

foreach(exe ${INSTALL_EXECUTABLE})
    add_dependencies(package ${exe})
endforeach()        
 
if(DEFINED INSTALL_TEST_EXECUTABLE)
    add_dependencies(package ${INSTALL_TEST_EXECUTABLE})
endif()
 
add_custom_command(TARGET package
    COMMAND cmake -DCMAKE_INSTALL_COMPONENT=Binaries -DBUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${PROJECT_BINARY_DIR}/package${PACKAGE_INSTALL_PREFIX} -P cmake_install.cmake 
    COMMENT "Preinstalling...")
    
# reinstall
if(NOT "${DEPENDENCIES}" STREQUAL "")
    foreach(dep ${OverallDependencies})
        set(depName ${${dep}_Name})
        
        if(("${${dep}_Type}" STREQUAL "Library") OR ("${${dep}_Type}" STREQUAL "Executable"))
            add_custom_command(TARGET package
                COMMAND cmake -DCMAKE_INSTALL_COMPONENT=Binaries -DBUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${PROJECT_BINARY_DIR}/package${PACKAGE_INSTALL_PREFIX} -P ${${dep}_BuildPath}/build/cmake_install.cmake
                COMMENT "Adding dependecy ${depName} to package...")
        endif()
        
    endforeach()
endif()    
    
set(PACKAGE_FILE_NAME "${PROJECT_NAME}-${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}-${CMAKE_SYSTEM_PROCESSOR}-${CMAKE_BUILD_TYPE}.tar.gz")

add_custom_command(TARGET package
    COMMAND cmake -E chdir ./package tar --exclude=${PACKAGE_FILE_NAME} -czf ${PACKAGE_FILE_NAME} .
    COMMENT "Tar ${PACKAGE_FILE_NAME}...")    
