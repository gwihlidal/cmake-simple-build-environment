cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED PROJECT_NAME)
    message(FATAL_ERROR "PROJECT_NAME dependency name that has to be checked.")
endif()

if(NOT DEFINED DEPENDENCIES_PATH)
    message(FATAL_ERROR "DEPENDENCIES_PATH has to be defined to know where are the dependecies to build.")
endif()

if(NOT DEFINED PROJECT_TIMESTAMPFILE)
    message(FATAL_ERROR "PROJECT_TIMESTAMPFILE has to be defined to know to check against.")
endif()

if(NOT DEFINED DEPENDENCIES_INFO)
    message(FATAL_ERROR "DEPENDENCIES_INFO has to be defined to know dependecies to build.")
endif()

if(NOT DEFINED DEPENDENCIES_BUILD_SUBDIRECTORY)
    message(FATAL_ERROR "DEPENDENCIES_BUILD_SUBDIRECTORY has to be defined to know build subdirectory under dependency build directory.")
endif()

find_program(SED_TOOL sed)
if(NOT SED_TOOL)
    message(FATAL_ERROR "error: could not find sed.")
endif()

include(${DEPENDENCIES_INFO})

# get dependencies that are build after this project
set(dependenciesToRebuild "")

foreach(dependency ${${PROJECT_NAME}_OverallDependencies})
    set(DEPENDENCY_TIMESTAMPFILE ${DEPENDENCIES_PATH}/${dependency}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}/Export/buildtimestamp)
    
    if(NOT EXISTS ${DEPENDENCY_TIMESTAMPFILE})
        list(APPEND dependenciesToRebuild ${dependency})
        list(APPEND ${${dependency}_OverallDependants})
    # when timestamp files are equal do not add dependency        
    elseif (EXISTS ${PROJECT_TIMESTAMPFILE} AND ${DEPENDENCY_TIMESTAMPFILE} IS_NEWER_THAN ${PROJECT_TIMESTAMPFILE} AND NOT ${PROJECT_TIMESTAMPFILE} IS_NEWER_THAN ${DEPENDENCY_TIMESTAMPFILE})
        list(APPEND dependenciesToRebuild ${${dependency}_OverallDependants})
    endif()
endforeach()

# remove not my dependencies, and sort accorind to installation oredr
list(REMOVE_ITEM dependenciesToRebuild ${PROJECT_NAME})

if("" STREQUAL "${dependenciesToRebuild}")
    return()
endif()

list(REMOVE_DUPLICATES dependenciesToRebuild)
set(tmp ${${PROJECT_NAME}_OverallDependencies})
list(REMOVE_ITEM tmp ${dependenciesToRebuild})
if(NOT "" STREQUAL "${tmp}")
    set(dependenciesToRebuild ${${PROJECT_NAME}_OverallDependencies})
    list(REMOVE_ITEM dependenciesToRebuild ${tmp})
endif() 


foreach(dependency ${dependenciesToRebuild})
    message(STATUS "${PROJECT_NAME} Building dependency ${dependency}")

    execute_process(
            COMMAND ${CMAKE_COMMAND} -E touch ${DEPENDENCIES_PATH}/${dependency}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}/Export/buildtimestamp)
            
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build . --use-stderr
        WORKING_DIRECTORY ${DEPENDENCIES_PATH}/${dependency}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}
        RESULT_VARIABLE result
        )
        
    if(NOT ${result} EQUAL 0)
        # remove build timestamp
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E remove ${DEPENDENCIES_PATH}/${dependency}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}/Export/buildtimestamp)        
        message( SEND_ERROR "Error in ${dependency}" )
    endif()
endforeach()

execute_process(COMMAND ${CMAKE_COMMAND} -E touch ${PROJECT_TIMESTAMPFILE})        
