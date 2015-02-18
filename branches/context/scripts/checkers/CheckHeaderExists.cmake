cmake_minimum_required(VERSION 2.8)

if (DEFINED CheckHeaderExistsGuard)
    return()
endif()

set(CheckHeaderExistsGuard yes)

include(SBE/helpers/ArgumentParser)

function(CheckHeaderExists)
    cmake_parse_arguments(chk "Mock;Production" "Header;ExistsInDependency" "InDependencies" ${ARGN})
    
    if(NOT chk_Mock AND NOT chk_Production)
        set(chk_Production yes)
    endif()
    
    message(STATUS "Looking for ${chk_Header}") 
    
    include(CheckIncludeFile)
    
    set(found no)
         
    foreach(dep ${chk_InDependencies})
        # load dependency to get include dirs
        if(chk_Production)
            list(APPEND CMAKE_REQUIRED_INCLUDES ${${dep}_INCLUDE_DIRS})
        endif()        
        if(chk_Mock)
            list(APPEND CMAKE_REQUIRED_INCLUDES ${${dep}_MOCK_INCLUDE_DIRS})
        endif()
        
        set(CMAKE_REQUIRED_QUIET yes)
        unset(HAVE-${chk_Header} CACHE)
       
        check_include_file("${chk_Header}" HAVE-${chk_Header})
        
        if(HAVE-${chk_Header})
            set(found yes)
            message(STATUS "Looking for ${chk_Header} - found in ${dep}")
            if(DEFINED chk_ExistsInDependency)
                set(${chk_ExistsInDependency} ${dep} PARENT_SCOPE)
            endif()
            break()
        endif()
    endforeach()
    
    if(NOT found)
        message(STATUS "Looking for ${chk_Header} - not found")
    endif()
endfunction()