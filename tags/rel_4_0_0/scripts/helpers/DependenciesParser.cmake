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
    set(deps "")
    
    set(__MyOverallDeps "" CACHE INTERNAL "")
    
    GetOverallDependenciesRecursively("${dependencies}")
    
    if(NOT "" STREQUAL "${__MyOverallDeps}")
        list(REMOVE_DUPLICATES __MyOverallDeps)
    endif()
    
    set(${parsedDependencies} ${__MyOverallDeps} PARENT_SCOPE)
    
    unset(__MyOverallDeps CACHE)
endfunction()

function(GetOverallDependenciesRecursively dependencies)
    ParseDependencies("${dependencies}" ids)
    
    foreach(dependencyId ${ids})
        list(FIND __MyOverallDeps ${dependencyId} found)
        if(${found} EQUAL -1)
            list(APPEND tmpList ${__MyOverallDeps} ${dependencyId})
            set(__MyOverallDeps "${tmpList}" CACHE INTERNAL "")
            GetOverallDependenciesRecursively("${${dependencyId}_DependenciesDescription}")
        endif()
    endforeach()
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