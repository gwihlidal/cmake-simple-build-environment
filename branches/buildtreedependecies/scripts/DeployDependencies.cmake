cmake_minimum_required(VERSION 2.8)

if(SBE_MODE)
endif()
if(RULE_LAUNCH_COMPILE)
endif()
if(RULE_LAUNCH_LINK)
endif()

set(DEP_SOURCE_DIR ${PROJECT_SOURCE_DIR})
include(SBE/ExportDependencies)
    
include(SBE/ConfigureDependencies)
    
include(${DEP_INFO_FILE} OPTIONAL)

# load variables of all dependencies
include(SBE/helpers/DependenciesParser)

GetOverallDependencies("${DEPENDENCIES}" MyOverallDependencies)

foreach(dep ${MyOverallDependencies})
    set(depName ${${dep}_Name})

    list(APPEND depNames ${depName})
endforeach()

unset(MyOverallDependencies)

add_custom_target(dependencies
    COMMAND ${CMAKE_COMMAND}
        -DNNNN=${PROJECT_NAME} 
        -DDEPENDENCIES_PATH=${DEP_SOURCES_PATH} 
        -DDEPENDENCIES_INFO=${DEP_INFO_FILE} 
        -DDEPENDENCIES_BUILD_SUBDIRECTORY=${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}
        -DMAIN_DEPENDENCY=${PROJECT_NAME}
        -P 
        ${CMAKE_ROOT}/Modules/SBE/BuildDependencies.cmake)

if(DEFINED depNames)
    foreach(depName ${depNames})
        find_package(${depName} REQUIRED CONFIG PATHS ${DEP_SOURCES_PATH}/${depName}/build/${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}/Export/config NO_DEFAULT_PATH)
    endforeach()
    
    unset(depNames)
endif()













