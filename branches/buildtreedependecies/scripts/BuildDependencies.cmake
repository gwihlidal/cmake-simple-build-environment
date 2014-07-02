cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED DEPENDENCIES_PATH)
    message(FATAL_ERROR "DEPENDENCIES_PATH has to be defined to know where are the dependecies to build.")
endif()

if(NOT DEFINED DEPENDENCIES_INFO)
    message(FATAL_ERROR "DEPENDENCIES_INFO has to be defined to know dependecies to build.")
endif()

if(NOT DEFINED DEPENDENCIES_BUILD_SUBDIRECTORY)
    message(FATAL_ERROR "DEPENDENCIES_BUILD_SUBDIRECTORY has to be defined to know build subdirectory under dependency build directory.")
endif()

if(NOT DEFINED MAIN_DEPENDENCY)
    message(FATAL_ERROR "MAIN_DEPENDENCY has to be defined to know for which dependecy dependecies are build.")
endif()

find_program(SED_TOOL sed)
if(NOT SED_TOOL)
    message(FATAL_ERROR "error: could not find sed.")
endif()

include(${DEPENDENCIES_INFO})


set(dependenciesToRebuild ${${MAIN_DEPENDENCY}_OverallDependencies})

# rebuild dependencies
message("${MAIN_DEPENDENCY} - ${dependenciesToRebuild}")
foreach(dependency ${dependenciesToRebuild})
    message("${MAIN_DEPENDENCY} - ${dependency} - ${DEPENDENCIES_PATH}/${${dependency}_Name}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}")
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build .
        WORKING_DIRECTORY ${DEPENDENCIES_PATH}/${${dependency}_Name}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}
        )
endforeach()


