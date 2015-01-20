cmake_minimum_required(VERSION 2.8)

include(SBE/helpers/ArgumentParser)

find_package(Subversion QUIET)
if(NOT Subversion_SVN_EXECUTABLE)
    message(FATAL_ERROR "error: could not find svn.")
endif()

function(svnGetNewestSubdirectory directoryToCheck newestSubDirectory errorReason)
    # get directory info 
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} list --verbose "${directoryToCheck}"
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        set(${errorReason} "Could not get list for ${directoryToCheck} due to:\n${err}" PARENT_SCOPE)
        return()
    endif()
    
    # create array from lines
    string(REPLACE "\n" ";" out "${out}")
    
    # get newest subrirectory (one with highest revision) 
    set(newestSubdir "")
    set(highestRevision 0)
    foreach(line ${out})
        # get revision and directory from line  
        string(REGEX MATCH "^[^0-9]*([0-9]+) .* [A-Z][a-z]+[ \t]+[0-9]+[ \t]+[0-9:]+[ \t]+(.+)/$" tmp "${line}")
        set(revision ${CMAKE_MATCH_1})
        set(subDirectory "${CMAKE_MATCH_2}")

        if(
            (NOT "" STREQUAL "${subDirectory}") AND  
            (NOT "." STREQUAL "${subDirectory}") AND
            (${revision} GREATER ${highestRevision})
          )
              set(newestSubdir ${subDirectory})
              set(highestRevision ${revision})
        endif() 
    endforeach()
    
    set(${newestSubDirectory} ${newestSubdir} PARENT_SCOPE)
endfunction()  

function(svnIsTrunkChangedAgainstLastTags svnProjectRootDirectory isNecessary errorReason)
    # get trunk directory info 
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} info "${svnProjectRootDirectory}/trunk"
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        set(${errorReason} "Could not get info about ${svnProjectRootDirectory}/trunk due to:\n${err}" PARENT_SCOPE)
        return()
    endif()
    
    # get trunk revision
    string(REGEX MATCH "Last Changed Rev: ([0-9]+)" TRUNK_REVISION "${out}")
    set(TRUNK_REVISION ${CMAKE_MATCH_1})    
    
    # get tag directory info 
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} info "${svnProjectRootDirectory}/tags"
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        set(${errorReason} "Could not get info about ${svnProjectRootDirectory}/tags due to:\n${err}" PARENT_SCOPE)
        return()
    endif()
    
    # get tag revision
    string(REGEX MATCH "Last Changed Rev: ([0-9]+)" TAGS_REVISION "${out}")
    set(TAGS_REVISION ${CMAKE_MATCH_1})
    
    if(${TRUNK_REVISION} GREATER ${TAGS_REVISION})
        set(${isNecessary} yes PARENT_SCOPE)
    else()
        set(${isNecessary} no PARENT_SCOPE)
    endif()   
    
    set(${errorReason} "" PARENT_SCOPE)
endfunction()  

function(svnIsDirectoryContains item directory isThere errorReason)
    # get directory info 
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} list --verbose "${directory}"
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        set(${errorReason} "Could not get list for ${directory} due to:\n${err}" PARENT_SCOPE)
        return()
    endif()
    
    # create array from lines
    string(REPLACE "\n" ";" out "${out}")
    
    # get check if output contains give item 
    foreach(line ${out})
        # get item from line  
        string(REGEX MATCH "^[^0-9]*[0-9]+ .* [A-Z][a-z]+ [0-9]+ [0-9][0-9]:[0-9][0-9] (.+)$" tmp "${line}")
        set(currentItem "${CMAKE_MATCH_1}")
        
        if("${currentItem}" STREQUAL "${item}")
            set(isThere "yes" PARENT_SCOPE)
            return() 
        endif() 
    endforeach()
    
    set(isThere "no" PARENT_SCOPE)
endfunction()  
       
function(svnGetProperty localFileOrDirectory propertyName propertyValue)
    # get directory info 
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} propget ${propertyName} "${localFileOrDirectory}"
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        return()
    endif()

    if(DEFINED out)
        # remove trialing newline from command output
        string(REGEX REPLACE "(.*)\n+$" "\\1" out "${out}")
        set(${propertyValue} ${out} PARENT_SCOPE)
    endif() 
    
endfunction()  

function(svnGetLog localFileOrDirectory svnlog)
    # get directory info 
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} log "${localFileOrDirectory}"
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        return()
    endif()

    set(${svnlog} ${out} PARENT_SCOPE)
endfunction()  

function(svnCheckout)
    cmake_parse_arguments(svn "" "LocalDirectory;Url;IsError" "StopOnErrorWithMessage;StartMessage" ${ARGN})
    
    if(DEFINED svn_StartMessage)
        message(STATUS ${svn_StartMessage})
    endif()
    
    if(NOT DEFINED svn_LocalDirectory AND NOT DEFINED svn_Url)
        if(DEFINED svn_IsError)
            set(${svn_IsError} yes PARENT_SCOPE)
        endif() 
        if(DEFINED svn_StopOnErrorWithMessage)
            message(FATAL_ERROR ${svn_StopOnErrorWithMessage})
        endif()
        
        return()        
    endif()
    
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} checkout ${svn_Url} ${svn_LocalDirectory}
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        set(${svn_IsError} yes PARENT_SCOPE)
        if(DEFINED svn_StopOnErrorWithMessage)
            message(FATAL_ERROR ${svn_StopOnErrorWithMessage})
        endif()
        return()
    endif()
    
    set(${svn_IsError} no PARENT_SCOPE)
endfunction()

function(svnSwitch)
    cmake_parse_arguments(svn "" "LocalDirectory;Url;IsError" "StartMessage;StopOnErrorWithMessage" ${ARGN})
    
    if(DEFINED svn_StartMessage)
        message(STATUS ${svn_StartMessage})
    endif()
    
    if(NOT DEFINED svn_LocalDirectory AND NOT DEFINED svn_Url)
        if(DEFINED svn_IsError)
            set(${svn_IsError} yes PARENT_SCOPE)
        endif() 
        if(DEFINED svn_StopOnErrorWithMessage)
            message(FATAL_ERROR ${svn_StopOnErrorWithMessage})
        endif()
        
        return()        
    endif()
    
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} switch ${svn_Url} ${svn_LocalDirectory}
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        set(${svn_IsError} yes PARENT_SCOPE)
        if(DEFINED svn_StopOnErrorWithMessage)
            message(FATAL_ERROR ${svn_StopOnErrorWithMessage})
        endif()
        return()
    endif()
    
    set(${svn_IsError} no PARENT_SCOPE)
endfunction()

function(svnGetRepositoryForLocalDirectory localDirectory url)
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} info ${localDirectory}
        RESULT_VARIABLE svnResult
        ERROR_VARIABLE err
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        return()
    endif()
    
    if("${out}" MATCHES "URL: ([^\n]+)")
        set(${url} "${CMAKE_MATCH_1}" PARENT_SCOPE)
    endif()
endfunction()

function(svnIsUrlTag url isTag)
    if("${url}" MATCHES "tags/[^/]+$")
        set(${isTag} yes PARENT_SCOPE)
    else()
        set(${isTag} no PARENT_SCOPE)
    endif()
endfunction()

function(svnIsUrlTrunk url isTrunk)
    svnIsUrlTag("${url}" isTag)
    
    if(isTag)
        set(${isTrunk} no PARENT_SCOPE)
    else()
        set(${isTrunk} yes PARENT_SCOPE)
    endif()
endfunction()
