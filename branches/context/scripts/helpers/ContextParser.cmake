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
        set(contextFileBaseOnName "${CMAKE_CURRENT_LIST_DIR}/${contextFileBaseOnName}/../Context.cmake")
        get_filename_component(contextFileBaseOnName "${contextFileBaseOnName}" ABSOLUTE)
    
        if(EXISTS "${contextFileBaseOnName}")
            set(${contextFile} ${contextFileBaseOnName} PARENT_SCOPE)
        elseif(EXISTS ${CMAKE_CURRENT_LIST_DIR}/Context.cmake)
            set(${contextFile} "${CMAKE_CURRENT_LIST_DIR}/Context.cmake" PARENT_SCOPE)
        else()
            message(FATAL_ERROR
               "Context.cmake file is missing." 
               "It is not given on command line as variable SBEContextFile."
               "It is not found in source directory neither in ${contextFileBaseOnName}."
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
    set(ContextFile ${cf} CACHE "" INTERNAL FORCE)
    get_filename_component(cp "${cf}" PATH)
    set_property(GLOBAL PROPERTY ContextPath "${cp}/context")
    set(ContextPath ${cp}/context CACHE "" INTERNAL FORCE)
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

function(sbeIsDependencyInContext name isInContext)
    get_property(d GLOBAL PROPERTY Context_${name}_Description)
    if(DEFINED d)
        set(${isInContext} yes PARENT_SCOPE)
    else()
        set(${isInContext} no PARENT_SCOPE)
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

# It gets pinned flag for given name
function(sbeGetPinnedFlag name isPinned)
    sbeGetPackageDescription(${name} description)

    if(DEFINED description)
        cmake_parse_arguments(desc "Pinned" "" "" ${description})
        if(desc_Pinned)
            set(${isPinned} yes PARENT_SCOPE)
        else()
            set(${isPinned} no PARENT_SCOPE)
        endif()
    endif()
endfunction()

# It gets provided flag for given name
function(sbeGetProvidedFlag name isProvided)
    sbeGetPackageDescription(${name} description)

    if(DEFINED description)
        cmake_parse_arguments(desc "Provided" "" "" ${description})
        if(desc_Provided)
            set(${isProvided} yes PARENT_SCOPE)
        else()
            set(${isProvided} no PARENT_SCOPE)
        endif()
    endif()
endfunction()

# It gets local package path for its name
function(sbeGetPackageLocalPath name localPath)
    get_property(ContextPath GLOBAL PROPERTY ContextPath)
    string(REPLACE "." "/" pathInContext ${name})
    
    set(${localPath} "${ContextPath}/${pathInContext}" PARENT_SCOPE)
endfunction()

# It gets local package path to build directory for its name
function(sbeGetPackageBuildPath name buildPath)
    sbeGetPackageLocalPath(${name} packagePath)
    
    if(DEFINED CMAKE_TOOLCHAIN_FILE)
        get_filename_component(toolchainName ${CMAKE_TOOLCHAIN_FILE} NAME)
        string(REPLACE ".cmake" "" toolchainName "${toolchainName}")
    else()
        set(toolchainName "default")
    endif()
    
    if(DEFINED CMAKE_BUILD_TYPE)
        set(buildType ${CMAKE_BUILD_TYPE})
    else()
        set(buildType "default")
    endif()
    
    set(${buildPath} "${packagePath}/build/${toolchainName}/${buildType}" PARENT_SCOPE)
endfunction()

# It gets local package path to config directory for its name
function(sbeGetPackageConfigPath name configPath)
    sbeGetPackageBuildPath(${name} buildPath)

    if(NOT DEFINED buildPath)
        return()
    endif()
   
    set(${configPath} "${buildPath}/Export/config" PARENT_SCOPE)
endfunction()


# It gets package timestamp file for its name
function(sbeGetPackageBuildTimestamp name timestampFile)
    sbeGetPackageBuildPath(${name} buildPath)

    if(NOT DEFINED buildPath)
        return()
    endif()
    
    set(${timestampFile} "${buildPath}/Export/${name}.buildtimestamp" PARENT_SCOPE)
endfunction()

# It gets package all build timestamp file for its name
function(sbeGetPackageAllBuildTimestamp name timestampFile)
    sbeGetPackageBuildPath(${name} buildPath)

    if(NOT DEFINED buildPath)
        return()
    endif()
    
    set(${timestampFile} "${buildPath}/Export/${name}.allbuildtimestamp" PARENT_SCOPE)
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

function(sbeUpdateUrlInContextFile contextFile name url)
    file(READ ${contextFile} context)
    string(REGEX REPLACE "(Project|Package)([ \t]+${name}[^\n]+Url[ \t]+)[^ \t\n]+" "\\1\\2${url}" context "${context}")
    file(WRITE ${contextFile} ${context})    
endfunction()