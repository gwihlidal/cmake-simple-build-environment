cmake_minimum_required(VERSION 2.8)

if(NOT DEP_SRC_DEPLOYMENT_PATH)
    set(DEP_SOURCE_DIR ${PROJECT_SOURCE_DIR})
    
    include(SBE/ExportDependencies)
else()
    set(DEP_SOURCES_PATH "${DEP_SRC_DEPLOYMENT_PATH}/sources")
    set(DEP_INFO_FILE "${DEP_SRC_DEPLOYMENT_PATH}/info/info.cmake")    
endif()
    
include(SBE/InstallDependencies)
    
include(${DEP_INFO_FILE} OPTIONAL)
include(${DEP_INST_INFO_FILE} OPTIONAL)

include(SBE/helpers/DependenciesParser)

GetOverallDependencies("${DEPENDENCIES}" MyOverallDependencies)

foreach(dep ${MyOverallDependencies})
    set(depName ${${dep}_Name})

    list(APPEND depNames ${depName})
endforeach()

unset(MyOverallDependencies)

if(DEFINED depNames)
    message(STATUS "Loading dependencies ${depNames}...")
    
    foreach(depName ${depNames})
        find_package(${depName} REQUIRED CONFIG PATHS ${DEP_INSTALL_PATH}/config NO_DEFAULT_PATH)
    endforeach()
    
    unset(depNames)
endif()













