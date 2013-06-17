cmake_minimum_required(VERSION 2.8)

if(NOT PROPERTIES_PATH)
    message(FATAL_ERROR "Path to Properties.txt has to be defined as PROPERTIES_PATH=path.")
endif()

include(SBE/helpers/DependenciesParser)

# get Properties from scm
execute_process(COMMAND svn export ${PROPERTIES_PATH}/Properties.cmake Properties.cmake
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out
    ERROR_VARIABLE out)
if(${svnResult} GREATER 0)
    message(FATAL_ERROR "Error: Could not export ${PROPERTIES_PATH}/Properties.cmake")
endif()

# include properties    
include(Properties.cmake)

ParseDependencies("${DEPENDENCIES}" dependenciesIndentifiers)

function(_checkDependency dependency isChanged)
    message(STATUS "Checking dependency ${dependency}")
    # get tags directory of dependency
    # get actual revision of tags directory
    # get actual revision of actual released directory
    # if not equal return changed
    set(${isChanged} "no" PARENT_SCOPE)    
endfunction()  

set(isChanged "no")

foreach(dependency ${dependenciesIndentifiers})
    if(NOT ${${dependency}_IsExternal} AND NOT isChanged)
        _checkDependency(${dependency} isChanged)
    endif()
endforeach()

execute_process(COMMAND cmake -E remove -f Properties.cmake)

if(isChanged)
    message(STATUS "Some new releases")
else()
    message(STATUS "No new releases")
endif()
        
