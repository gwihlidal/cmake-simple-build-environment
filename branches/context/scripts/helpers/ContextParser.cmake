if(DEFINED ContextParserGuard)
    return()
endif()

set(ContextParserGuard yes)

include(SBE/helpers/ArgumentParser)

# Context file contains context description
# Each package is described in Context variable with following line
# Project|Package itsName ([Svn|Git] Url itsUrlInRepository | Local itsDirectory)

# It finds context file 
# It search for in package root and in package source directory 
function(sbeFindContextFile name contextFile)
    if(DEFINED SBEContextFile)
        set(${contextFile} ${SBEContextFile} PARENT_SCOPE)
    else()
        set(contextFileBaseOnName ${name})
        string(REPLACE "." "/" contextFileBaseOnName ${contextFileBaseOnName})
        string(REGEX REPLACE "[^/]+" ".." contextFileBaseOnName ${contextFileBaseOnName})
        set(contextFileBaseOnName "${contextFileBaseOnName}/../Context.cmake")
    
        if(EXISTS ${contextFileBaseOnName})
            set(${contextFile} ${contextFileBaseOnName} PARENT_SCOPE)
        elseif(EXISTS Context.cmake)
            set(${contextFile} "Context.cmake" PARENT_SCOPE)
        else()
            message(FATAL_ERROR
               "Context.cmake file is missing." 
               "It is not given on command line as variable SBEContextFile."
               "It is not found in source directory neither in ${pathToContextFileBaseOnName}."
               )                        
        endif()
    endif()
endfunction()

# It loads context file into properties 
function(sbeLoadContextFile contextFile)
    # check input arguments
    sbeReportErrorWhenFileDoesntExists(contextFile "Context file has to exists.")
    
    include(${contextFile})
    
    # wrap Project or Package (the keywords are similar) into list of project descriptions
    set(descriptions ${Context})
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

        set_property(GLOBAL PROPERTY Context_${name}_Description ${description})
    endforeach()
    
    get_filename_component(cf "${contextFile}" ABSOLUTE)
    set_property(GLOBAL PROPERTY ContextFile ${cf})
    get_filename_component(cp "${cf}" PATH)
    set_property(GLOBAL PROPERTY ContextPath "${cp}/context")
endfunction()

# It reports error when context file is not loaded
function(sbeReportErrorWhenContextFileIsNotLoaded)
    get_property(ContextFile GLOBAL PROPERTY ContextFile)
    if(NOT DEFINED ContextFile)
        message(FATAL_ERROR
            "Context file must be loaded." 
        )
    endif()
endfunction()
    
# It gets package description for given name
function(sbeGetPackageDescription name description)
    get_property(d GLOBAL PROPERTY Context_${name}_Description)
    if(DEFINED d)
        set(${description} ${d} PARENT_SCOPE)
    endif()
endfunction()


# It gets url package description for given name
function(sbeGetPackageUrl name url)
    sbeGetPackageDescription(${name} description)

    if(DEFINED description)
        cmake_parse_arguments(desc "" "Url" "" ${description})
        set(${url} ${desc_Url} PARENT_SCOPE)
    endif()
endfunction()

# It gets local package path for its name
function(sbeGetPackageLocalPath name localPath)
    get_property(ContextPath GLOBAL PROPERTY ContextPath)
    string(REPLACE "." "/" pathInContext ${name})
    
    set(${localPath} "${ContextPath}/${pathInContext}" PARENT_SCOPE)
endfunction()

# It gets local package properties file
function(sbeGetPackagePropertiesFile name propertiesFile)
    sbeGetPackageLocalPath(${name} packagePath)
    set(${propertiesFile} "${packagePath}/Properties.cmake" PARENT_SCOPE)
endfunction()

# It gets local package properties file timestamp
function(sbeGetPackagePropertiesTimestamp name timestamp)
    sbeGetPackagePropertiesFile(${name} propertiesFile)
    
    file(TIMESTAMP "${propertiesFile}" ts "%Y-%m-%dT%H:%M:%S")
    set(${timestamp} ${ts} PARENT_SCOPE)
endfunction()

function(getContextTimestamp timestamp)
    get_property(ContextFile GLOBAL PROPERTY ContextFile)
    file(TIMESTAMP ${ContextFile} ts "%Y-%m-%dT%H:%M:%S")
    set(${timestamp} ${ts} PARENT_SCOPE)
endfunction()