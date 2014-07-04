cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED SBE_MAIN_DEPENDANT_SOURCE_DIR)
    # this project is main dependant
    set(SBE_MAIN_DEPENDANT_SOURCE_DIR ${PROJECT_SOURCE_DIR})
    set(SBE_MAIN_DEPENDANT ${PROJECT_NAME})
endif()

include(SBE/ExportDependencies)
    
include(SBE/ConfigureDependencies)
    
include(${DEP_INFO_FILE} OPTIONAL)

# load variables of all dependencies
include(SBE/helpers/DependenciesParser)

add_custom_target(dependencies
    COMMAND ${CMAKE_COMMAND}
        -DPROJECT_NAME=${PROJECT_NAME}
        -DPROJECT_TIMESTAMPFILE=${PROJECT_BINARY_DIR}/Export/buildtimestamp
        -DDEPENDENCIES_PATH=${DEP_SOURCES_PATH} 
        -DDEPENDENCIES_INFO=${DEP_INFO_FILE} 
        -DDEPENDENCIES_BUILD_SUBDIRECTORY=${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}
        -P 
        ${CMAKE_ROOT}/Modules/SBE/BuildDependencies.cmake)

foreach(dep ${${NAME}_OverallDependencies})
    find_package(${dep} REQUIRED CONFIG PATHS ${DEP_SOURCES_PATH}/${dep}/build/${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}/Export/config NO_DEFAULT_PATH)
endforeach()















