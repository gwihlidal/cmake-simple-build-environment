if(DEFINED PropertiesParserGuard)
    return()
endif()

set(PropertiesParserGuard yes)

include(SBE/helpers/ArgumentParser)

function(sbeGetDependenciesNames dependenciesNames dependenciesInfo)
    set(descriptions ${dependenciesInfo})
    string(REPLACE ";" ","  descriptions "${descriptions}")
    string(REPLACE ",Project" ";Project"  descriptions "${descriptions}")
    string(REPLACE ",Package" ";Package"  descriptions "${descriptions}")

    # transform descriptions into properties
    foreach(description ${descriptions})
        string(REPLACE "," ";" description "${description}")
        
        cmake_parse_arguments(pkg "" "Project;Package" "" ${description})
        if(DEFINED pkg_Project)
            set(name ${pkg_Project})
        else()
            set(name ${pkg_Package})
        endif()
        list(APPEND names ${name})
    endforeach()
    
    set(${dependenciesNames} "${names}" PARENT_SCOPE)
endfunction()

function(sbeGetVersionText text)
    if(DEFINED SemanticVersion)
        set(${text} ${SemanticVersion} PARENT_SCOPE)
    elseif(DEFINED DateVersion)
        set(${text} ${DateVersion} PARENT_SCOPE)
    endif()
endfunction()

function(sbeUpdateDateVersion version propertytFile)
    file(READ ${propertytFile} context)
    string(REGEX REPLACE "([ \t]*[sS][eE][tT][ \t]*\\([ \t]*DateVersion[ \t]+)[0-9]+([ \t]*\\))" "\\1${version}\\2" context "${context}")
    file(WRITE ${propertytFile} ${context})
endfunction()
