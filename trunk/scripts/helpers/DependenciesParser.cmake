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
#        * LIBRARIES_TO_LINK - it is workaround for packages that contains many libraries. Disadvantage is that 
#            dependant has to know libraries names                 
#
#

if(${isDependenciesParserAlreadyIncluded})
    return()
endif()
set(isDependenciesParserAlreadyIncluded "yes")

include (CMakeParseArguments)

function(ParseDependencies dependencies parsedDependencies)
    set(dependenciesIndentifiers "")
    set(dependencyProperties "")
    
    # split dependencies properties to dependency property and parse it 
    foreach(dep ${dependencies})
        if ("DEPENDENCY" STREQUAL "${dep}")
            if(NOT "" STREQUAL "${dependencyProperties}")
                _parseDependency("${dependencyProperties}" parsedDependecy_ID)
                list(APPEND dependenciesIndentifiers ${parsedDependecy_ID})
                
                set(dependencyProperties "")
            endif()
        else()
            list(APPEND dependencyProperties "${dep}")
        endif()
    endforeach()
    
    if(NOT "" STREQUAL "${dependencyProperties}")
        _parseDependency("${dependencyProperties}" parsedDependecy_ID)
        list(APPEND dependenciesIndentifiers ${parsedDependecy_ID})
    endif()
            
    # export dependencies identifiers
    set(${parsedDependencies} ${dependenciesIndentifiers} PARENT_SCOPE)
endfunction()

macro(_parseDependency dependencyProperties id)
    CMAKE_PARSE_ARGUMENTS(parsedDependecy "EXTERNAL" "URL;SCM" "LIBRARIES_TO_LINK" ${dependencyProperties})
    
#    message(STATUS 
#        "parsing dependency [${dependencyProperties}]"
#        "   SCM [${parsedDependecy_SCM}]"
#        "   URL [${parsedDependecy_URL}]"
#        "   LIBRARIES_TO_LINK [${parsedDependecy_LIBRARIES_TO_LINK}]"
#        "   EXTERNAL [${parsedDependecy_EXTERNAL}]"
#        )
    
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
    set(${dep_ID}_LibrariesToLink ${parsedDependecy_LIBRARIES_TO_LINK} PARENT_SCOPE)
    set(${dep_ID}_isExternal ${parsedDependecy_EXTERNAL} PARENT_SCOPE)
    
    # export dep id
    set(${id} ${dep_ID})
endmacro()