cmake_minimum_required(VERSION 2.8)

if(NOT PROPERTIES_PATH)
    message(FATAL_ERROR "Path to local Properties.cmake has to be defined as PROPERTIES_PATH=path.")
endif()

include(SBE/helpers/DependenciesParser)
include(SBE/helpers/SvnHelpers)

# include properties    
include(${PROPERTIES_PATH}/Properties.cmake)

file(READ ${PROPERTIES_PATH}/Properties.cmake originalPropertiesInfo)

# set info for modifications
set(propertiesInfo ${originalPropertiesInfo})

function(_updateDependency dependency)
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
        # update dependency in Properties.cmake
        string(REPLACE "${${dependency}_ScmPath}" "${dependencyTagsDirectory}/${newestSubDirectory}" tmp "${propertiesInfo}")
        set(propertiesInfo ${tmp} PARENT_SCOPE)
        # report
        message(STATUS "Processing ${dependency} -- updated to ${newestSubDirectory}")
    else()
        message(STATUS "Processing ${dependency} -- keeping latest")
    endif()
endfunction()  

ParseDependencies("${DEPENDENCIES}" dependenciesIndentifiers)

foreach(dependency ${dependenciesIndentifiers})
    if(NOT ${${dependency}_IsExternal})
        _updateDependency(${dependency})
    endif()
endforeach()

if(NOT "${propertiesInfo}" STREQUAL "${originalPropertiesInfo}")
    message(STATUS "Updating Properties.cmake file")
    
    file(WRITE ${PROPERTIES_PATH}/Properties.cmake "${propertiesInfo}")
endif()

       
