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
    if(NOT EXISTS ${DEPENDENCIES_PATH}/${dependency}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}/Export/buildtimestamp)
        list(APPEND dependenciesToRebuild ${dependency} ${${dependency}_OverallDependants})
    elseif (${DEPENDENCIES_PATH}/${dependency}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}/Export/buildtimestamp IS_NEWER_THAN ${PROJECT_TIMESTAMPFILE})
        list(APPEND dependenciesToRebuild ${${dependency}_OverallDependants})
    endif()
endforeach()

# remove not my dependencies
list(REMOVE_DUPLICATES dependenciesToRebuild)
if(NOT "" STREQUAL "${dependenciesToRebuild}")
    set(tmp ${dependenciesToRebuild})
    list(REMOVE_ITEM tmp ${${PROJECT_NAME}_OverallDependencies})
    list(REMOVE_ITEM dependenciesToRebuild ${tmp})

    if (NOT "" STREQUAL "${dependenciesToRebuild}")
        # order dependenciesToRebuild
        set(tmp ${${PROJECT_NAME}_OverallDependencies})
        list(REMOVE_ITEM tmp ${dependenciesToRebuild})
        
        if (NOT "" STREQUAL "${tmp}")
            set(orderedDependenciesToRebuild ${${PROJECT_NAME}_OverallDependencies})
            list(REMOVE_ITEM orderedDependenciesToRebuild ${tmp})
            set(dependenciesToRebuild ${orderedDependenciesToRebuild})
        endif()
   endif()
endif()
 
foreach(dependency ${dependenciesToRebuild})
    message(STATUS "Building dependency ${dependency}")
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build . --use-stderr
        COMMAND ${SED_TOOL} -u -e "s/.*/    &/"
        WORKING_DIRECTORY ${DEPENDENCIES_PATH}/${dependency}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}
        )
endforeach()        


