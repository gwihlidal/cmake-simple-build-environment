cmake_minimum_required(VERSION 2.8)

if(NOT DEP_SRC_DEPLOYMENT_PATH)
    set(DEP_SOURCE_DIR ${PROJECT_SOURCE_DIR})
    
    include(SBE/ExportDependencies)
else()
    set(DEP_SOURCES_PATH "${DEP_SRC_DEPLOYMENT_PATH}/sources")
    set(DEP_INFO_FILE "${DEP_SRC_DEPLOYMENT_PATH}/info/info.cmake")    
endif()
    
include(SBE/ConfigureDependencies)
    
include(${DEP_INFO_FILE} OPTIONAL)
#include(${DEP_INST_INFO_FILE} OPTIONAL)

# load variables of all dependencies
include(SBE/helpers/DependenciesParser)

GetOverallDependencies("${DEPENDENCIES}" MyOverallDependencies)

foreach(dep ${MyOverallDependencies})
    set(depName ${${dep}_Name})

    list(APPEND depNames ${depName})
endforeach()

unset(MyOverallDependencies)

include(ExternalProject)

if(DEFINED depNames)
    foreach(depName ${depNames})
        ExternalProject_Add(${depName}
        SOURCE_DIR ${DEP_SOURCES_PATH}/${depName}
        BINARY_DIR ${DEP_SOURCES_PATH}/${depName}/build/${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}
        INSTALL_COMMAND ""
        TEST_COMMAND ""
        UPDATE_COMMAND "hhh" 
        )
         
        #find_package(${depName} REQUIRED CONFIG PATHS ${DEP_SOURCES_PATH}/${depName}/build/${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}/Export/config NO_DEFAULT_PATH)
    endforeach()
    
    unset(depNames)
endif()













