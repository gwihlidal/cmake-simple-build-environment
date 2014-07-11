cmake_minimum_required(VERSION 2.8)

if(NOT PROPERTIES_PATH)
    message(FATAL_ERROR "URL Path to Properties.cmake or local path has to be defined as PROPERTIES_PATH=path.")
endif()

include(SBE/helpers/DependenciesParser)
include(SBE/helpers/SvnHelpers)

set(localFile no)
if(EXISTS ${PROPERTIES_PATH}/Properties.cmake)
    set(localFile yes)
endif()

if(NOT localFile AND EXISTS ./Properties.cmake)
    message(FATAL_ERROR 
        "Error: Could not export ${PROPERTIES_PATH}/Properties.cmake "
        "because file ./Properties.cmake already exists")
endif()

if(NOT localFile)
    # get Properties from scm
    message(STATUS "Exporting dependency properties ${PROPERTIES_PATH}")
    
    execute_process(COMMAND svn export ${PROPERTIES_PATH}/Properties.cmake Properties.cmake
        RESULT_VARIABLE svnResult
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(${svnResult} GREATER 0)
        message(FATAL_ERROR "Error: Could not export ${PROPERTIES_PATH}/Properties.cmake")
    endif()
endif()

# include properties    
include(Properties.cmake)

if(NOT localFile)
    # remove file, after include it is needed any more
    execute_process(COMMAND cmake -E remove -f Properties.cmake)
endif()    

function(_checkDependency dependency isChanged)
    message(STATUS "Processing ${dependency}")
    
    # get tags directory of dependency
    string(REGEX MATCH "^(.*)/.*$" dependencyTagsDirectory "${${dependency}_ScmPath}")
    set(dependencyTagsDirectory ${CMAKE_MATCH_1})
    
    svnGetNewestSubdirectory(${dependencyTagsDirectory} newestSubDirectory error)
    
    if(NOT DEFINED newestSubDirectory)
        message(FATAL_ERROR "${error}")
    endif()
    
    # get actual tag
    string(REGEX MATCH "^.*/(.*)$" dependencyTag "${${dependency}_ScmPath}")
    set(dependencyTag ${CMAKE_MATCH_1})

    if(NOT "${dependencyTag}" STREQUAL "${newestSubDirectory}")
        set(${isChanged} "yes" PARENT_SCOPE)
        message(STATUS "Processing ${dependency} -- is not latest")
    else()
            set(${isChanged} "no" PARENT_SCOPE)
        message(STATUS "Processing ${dependency} -- is latest")
    endif()
endfunction()  

ParseDependencies("${DEPENDENCIES}" dependenciesIndentifiers)

set(isChanged "no")

foreach(dependency ${dependenciesIndentifiers})
    if(NOT ${${dependency}_IsExternal} AND NOT isChanged)
        _checkDependency(${dependency} isChanged)
    endif()
endforeach()

if(isChanged)
    message(STATUS "Some new releases")
else()
    message(STATUS "No new releases")
endif()
        
