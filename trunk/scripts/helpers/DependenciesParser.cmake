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

function(ParseDependencies dependencies parsedDependencies p)
    set(dependenciesIndentifiers "")
    set(dependencyProperties "")
    
    sbeParseArguments(depProperties "" "" "" "DEPENDENCY" "${dependencies}")
    
    # parse properties for each dependency
    foreach(depProperties ${depProperties_DEPENDENCY})
        string(REPLACE "," ";" depProperties "${depProperties}")
        _parseDependency("${depProperties}" parsedDependecy_ID "${p}")
        list(APPEND dependenciesIndentifiers ${parsedDependecy_ID})
    endforeach()
    
    # export dependencies identifiers
    set(${parsedDependencies} ${dependenciesIndentifiers} PARENT_SCOPE)
endfunction()

macro(_parseDependency dependencyProperties id p)
    CMAKE_PARSE_ARGUMENTS(parsedDependecy "EXTERNAL" "URL;SCM" "" ${dependencyProperties})
    
    # set defaults
    if (NOT DEFINED parsedDependecy_SCM)
        set(parsedDependecy_SCM "svn")
    endif()
    string(TOLOWER parsedDependecy_SCM "${parsedDependecy_SCM}")
        
    # create dependency identifier
    if("Development" STREQUAL "${SBE_MODE}")
        set(url "${parsedDependecy_URL}")
        string(REGEX REPLACE "/tags/.*$" "" url "${url}")
        string(REGEX REPLACE "/trunk$" "" url "${url}")
        set(dep_ID "${parsedDependecy_SCM}-${url}")
    else()
        set(dep_ID "${parsedDependecy_SCM}-${parsedDependecy_URL}")
    endif()
    
    if("" STREQUAL "${p}")
        set(prf "")
    else()
        set(prf "${p}_")
    endif()
    # export dependency properties to parent scope
    set(${prf}${dep_ID}_ScmType ${parsedDependecy_SCM} PARENT_SCOPE)
    set(${prf}${dep_ID}_ScmPath ${parsedDependecy_URL} PARENT_SCOPE)
    set(${prf}${dep_ID}_IsExternal ${parsedDependecy_EXTERNAL} PARENT_SCOPE)
    
    # export dep id
    set(${id} ${dep_ID})
endmacro()