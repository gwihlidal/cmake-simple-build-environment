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
function(sbeFindContextFile)
    cmake_parse_arguments(ctx "" "ContextFile;Name" "" ${ARGN})
    
     # check input arguments
     sbeReportErrorWhenVariablesNotDefined(Var ctx_ContextFile ctx_Name 
         Message "ContextFile variable and Name has to be given.")
        
    if(DEFINED SBEContextFile)
        set(${ctx_ContextFile} ${SBEContextFile} PARENT_SCOPE)
    else()
        set(contextFileBaseOnName ${Name})
        string(REPLACE "." "/" contextFileBaseOnName ${contextFileBaseOnName})
        string(REGEX REPLACE "[^/]+" ".." contextFileBaseOnName ${contextFileBaseOnName})
        set(contextFileBaseOnName "${contextFileBaseOnName}/../Context.cmake")
    
        if(EXISTS ${contextFileBaseOnName})
            set(${ctx_ContextFile} ${contextFileBaseOnName} PARENT_SCOPE)
        elseif(EXISTS Context.cmake)
            set(${ctx_ContextFile} "Context.cmake" PARENT_SCOPE)
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
function(sbeLoadContextFile)
    cmake_parse_arguments(ctx "" "ContextFile" "" ${ARGN})
    
    # check input arguments
    sbeReportErrorWhenFileDoesntExists(File ctx_ContextFile Message "Context file has to exists.")
    
    include(${ctx_ContextFile})
    
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
    
    get_filename_component(ctx_ContextFile "${ctx_ContextFile}" ABSOLUTE)
    set_property(GLOBAL PROPERTY ContextFile ${ctx_ContextFile})
    get_filename_component(ContextPath "${ctx_ContextFile}" PATH)
    set_property(GLOBAL PROPERTY ContextPath "${ContextPath}/context")
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
function(sbeGetPackageDescription)
    cmake_parse_arguments(pkg "" "Description;Name" "" ${ARGN})
    
    # check input arguments
    if(NOT DEFINED pkg_Description OR NOT DEFINED pkg_Name)
        return()
    endif()

    get_property(description GLOBAL PROPERTY Context_${pkg_Name}_Description)
    if(DEFINED description)
        set(${pkg_Description} ${description} PARENT_SCOPE)
    endif()
endfunction()


# It gets url package description for given name
function(sbeGetPackageUrl)
    cmake_parse_arguments(pkg "" "Url;Name" "" ${ARGN})
    
    # check input arguments
    if(NOT DEFINED pkg_Name OR NOT DEFINED pkg_Url)
        return()
    endif()

    sbeGetPackageDescription(Description description Name ${pkg_Name})

    if(DEFINED description)
        cmake_parse_arguments(desc "" "Url" "" ${description})
        if(DEFINED desc_Url)
            set(${pkg_Url} ${desc_Url} PARENT_SCOPE)
        endif()
    endif()
endfunction()

# It gets local package path for its name
function(sbeGetPackageLocalPath)
    cmake_parse_arguments(pkg "" "LocalPath;Name" "" ${ARGN})
    
    # check input arguments
    if(NOT DEFINED pkg_LocalPath OR NOT DEFINED pkg_Name)
        return()
    endif()

    get_property(ContextPath GLOBAL PROPERTY ContextPath)
    string(REPLACE "." "/" pathInContext ${pkg_Name})
    
    set(${pkg_LocalPath} "${ContextPath}/${pathInContext}" PARENT_SCOPE)
endfunction()

# It gets local package properties file
function(sbeGetPackagePropertiesFile)
    cmake_parse_arguments(pkg "" "PropertiesFile;Name" "" ${ARGN})
    
    # check input arguments
    if(NOT DEFINED pkg_PropertiesFile OR NOT DEFINED pkg_Name)
        return()
    endif()

    sbeGetPackageLocalPath(LocalPath packagePath Name ${pkg_Name})
    
    
    set(${pkg_PropertiesFile} "${packagePath}/Properties.cmake" PARENT_SCOPE)
endfunction()

# It gets local package properties file timestamp
function(sbeGetPackagePropertiesTimestamp)
    cmake_parse_arguments(pkg "" "Timestamp;Name" "" ${ARGN})
    
    # check input arguments
    if(NOT DEFINED pkg_Timestamp OR NOT DEFINED pkg_Name)
        return()
    endif()

    sbeGetPackagePropertiesFile(PropertiesFile propertiesFile Name ${pkg_Name})
    
    file(TIMESTAMP "${propertiesFile}" ts "%Y-%m-%dT%H:%M:%S")
    set(${pkg_Timestamp} ${ts} PARENT_SCOPE)
endfunction()

function(getContextTimestamp)
    cmake_parse_arguments(pkg "" "Timestamp" "" ${ARGN})
    
    if(NOT DEFINED pkg_Timestamp)
        return()
    endif()
    
    get_property(ContextFile GLOBAL PROPERTY ContextFile)
    file(TIMESTAMP ${ContextFile} ts "%Y-%m-%dT%H:%M:%S")
    set(${pkg_Timestamp} ${ts} PARENT_SCOPE)
endfunction()