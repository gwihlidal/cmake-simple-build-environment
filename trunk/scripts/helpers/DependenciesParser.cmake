#
#
# Function will parse dependencies and returns list of dependencies identifiers in out variable.
#    Other dependency properties are set in Parent scope.
#    Properties that can be used are:
#        * URL - url in scm
#        * SCM - type of scm svn, git
#        * EXTERNAL - external dependency will be not 
#            * automatically updated
#            * included into package target
#
#

if(${isDependenciesParserAlreadyIncluded})
    return()
endif()

set(isDependenciesParserAlreadyIncluded "yes")

include (SBE/helpers/ArgumentParser)

function(ParseDependencies dependencies parsedDependencies)
    set(dependenciesIndentifiers "")
    set(dependencyProperties "")
    
    sbeParseArguments(depProperties "" "" "" "DEPENDENCY" "${dependencies}")
    
    # parse properties for each dependency
    foreach(depProperties ${depProperties_DEPENDENCY})
        string(REPLACE "," ";" depProperties "${depProperties}")
        _parseDependency("${depProperties}" parsedDependecy_ID)
        list(APPEND dependenciesIndentifiers ${parsedDependecy_ID})
    endforeach()
    
    # export dependencies identifiers
    set(${parsedDependencies} ${dependenciesIndentifiers} PARENT_SCOPE)
endfunction()

function(GetOverallDependencies dependencies parsedDependencies)
    ParseDependencies("${dependencies}" ids)
    
    foreach(dependencyId ${ids})
        set(dependencyDependencies "")
        GetOverallDependencies("${${dependencyId}_DependenciesDescription}" dependencyDependencies)
        list(APPEND ids ${dependencyDependencies})
    endforeach()
    
    if(NOT "" STREQUAL "${ids}")
        list(REMOVE_DUPLICATES ids)
    endif()
    
    # export dependencies identifiers
    set(${parsedDependencies} ${ids} PARENT_SCOPE)
endfunction()

macro(_parseDependency dependencyProperties id)
    CMAKE_PARSE_ARGUMENTS(parsedDependecy "EXTERNAL" "URL;SCM" "" ${dependencyProperties})
    
    # set defaults
    if (NOT DEFINED parsedDependecy_SCM)
        set(parsedDependecy_SCM "svn")
    endif()
    string(TOLOWER parsedDependecy_SCM "${parsedDependecy_SCM}")
        
    # create dependency identifier
    set(dep_ID "${parsedDependecy_SCM}-${parsedDependecy_URL}")
    
    # export dependency properties to parent scope
    set(${dep_ID}_ScmType ${parsedDependecy_SCM} PARENT_SCOPE)
    set(${dep_ID}_ScmPath ${parsedDependecy_URL} PARENT_SCOPE)
    set(${dep_ID}_IsExternal ${parsedDependecy_EXTERNAL} PARENT_SCOPE)
    
    # export dep id
    set(${id} ${dep_ID})
endmacro()