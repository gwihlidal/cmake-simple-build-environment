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

### 
# get dependencies of MAIN_DEPENDENCY
###
# if no overall  dependencies then nothing to do
if ("" STREQUAL "${DEP_INSTALLATION_ORDER}")
    return()
endif()

foreach(dep ${OverallDependencies})
    if("${MAIN_DEPENDENCY}" STREQUAL "${${dep}_Name}")
        set(MAIN_DEPENDENCY_ID ${dep})
        break()
    endif()
endforeach()

if(DEFINED MAIN_DEPENDENCY_ID)
    set(MAIN_DEPENDENCY ${MAIN_DEPENDENCY_ID})
endif()

# get depencies from installation order
set(dependencies "")
foreach(dependency ${DEP_INSTALLATION_ORDER})
    if("${MAIN_DEPENDENCY}" STREQUAL "${dependency}")
        break()
    endif()
    
    list(APPEND dependencies ${dependency})
endforeach()

# if no dependencies of MAIN_DEPENDENCY then nothing to do
if("" STREQUAL "${dependencies}")
    return()
endif()

# remove dependecies that are not dependecies of MAIN_DEPENDECY
set(reversedDepenecies ${dependencies})
list(REVERSE reversedDepenecies)
foreach(dependency ${reversedDepenecies})
    list(FIND ${MAIN_DEPENDENCY}_Dependencies ${dependency} isFound)
    if(isFound)
        break()
    else()
        list(REMOVE_ITEM dependencies ${dependency})
    endif()
endforeach()

set(dependenciesToRebuild ${dependencies})

# if no dependencies of MAIN_DEPENDENCY then nothing to do
list(LENGTH dependencies dependenciesNumber)

# get dependencies that have to be re builded
set(dependenciesToRebuild ${dependencies})
list(LENGTH dependencies dependenciesNumber)
math(EXPR dependenciesNumber "${dependenciesNumber} - 1")

foreach(id RANGE 0 ${dependenciesNumber})
    list(GET dependencies ${id} depOfDep)
    math(EXPR nextId "${id} + 1")
    list(GET dependencies ${nextId} dep)

    set(depOfDepTimestampFile "${DEPENDENCIES_PATH}/${${depOfDep}_Name}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}/Export/buildtimestamp")
    set(depTimestampFile "${DEPENDENCIES_PATH}/${${dep}_Name}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}/Export/buildtimestamp")
        
    if(NOT EXISTS ${depTimestampFile})
        break()    
    endif()     
    
    if("${depOfDep}" STREQUAL "${dep}")
        # end of list of dependencies
        set(dependenciesToRebuild "")
        break()
    endif() 
                
    # check dependencies
    if(${depOfDepTimestampFile} IS_NEWER_THAN ${depTimestampFile})
        list(REMOVE_AT dependenciesToRebuild ${id})
    else()
        break()
    endif()
endforeach()

# rebuild dependencies
message("${NNNN} - ${dependenciesToRebuild}")
foreach(dependency ${dependenciesToRebuild})
    message("${NNNN} - ${dependency} - ${DEPENDENCIES_PATH}/${${dependency}_Name}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}")
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build .
        WORKING_DIRECTORY ${DEPENDENCIES_PATH}/${${dependency}_Name}/build/${DEPENDENCIES_BUILD_SUBDIRECTORY}
        )
endforeach()


