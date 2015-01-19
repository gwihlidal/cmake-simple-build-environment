cmake_minimum_required(VERSION 2.8)

if (DEFINED PackageGuard)
    return()
endif()

set(PackageGuard yes)

# each project has to have properties.cmake file, where project is described
set(PackagePropertyFile Properties.cmake)

include(SBE/helpers/ArgumentParser)
include(SBE/helpers/ContextParser)
include(SBE/ExportDependencies)

# macro calculates mandratory variables if not given
# - sets CMAKE_TOOLCHAN_FILE to host-linux-vcxi-default-default-default.cmake
# - sets CMAKE_BUILD_TYPE to Debug
# - sets project laguage to C and CXX
# - finds Context.cmake file
# macro checks mandratory variables in property file
# - Name
# - SemanticVersion or DateVersion
function(sbeSetupPackage)

    # Property file is mandratory for each project
    sbeReportErrorWhenFileDoesntExists(File PackagePropertyFile
        Message
           "File ${PackagePropertyFile} is missing." 
           "Each project has to have Properties.cmake file on the same location as CMakeLists.txt.")

    include(${PackagePropertyFile})
    
    # SemanticVersion or DateVersion has to be present
    sbeReportErrorWhenVariablesNotDefined(OneOf SemanticVersion DateVersion
        Message
           "SemanticVersion or DateVersion is missing in ${PackagePropertyFile}." 
           "One of SemanticVersion or DateVersion is mandratory.")
    
    # Name has to be present
    sbeReportErrorWhenVariablesNotDefined(Var Name
        Message
           "Name is missing in ${PackagePropertyFile}." 
           "Name is mandratory."
    )        
        
    cmake_parse_arguments(prj "" "" "Languages" ${ARGN})
    
    # set Languages if not given
    set(projectLanguages ${prj_Languages})
    if (NOT projectLanguages)
        set(projectLanguages C CXX)
    endif()
    
    # set CMAKE_TOOLCHAN_FILE if not given
    if(NOT DEFINED CMAKE_TOOLCHAN_FILE)
        set(CMAKE_TOOLCHAN_FILE SBE/toolchains/host-linux-vcxi-default-default-default.cmake)
    endif()
    
    # set CMAKE_BUILD_TYPE if not given
    if(NOT DEFINED CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Debug)
    endif()

    # define project    
    project(${Name} ${projectLanguages})
    
    # export dependencies
    sbeFindContextFile(ContextFile contextFile Name ${Name})
    sbeLoadContextFile(ContextFile ${contextFile})
    sbeExportDependenciesInPackage(PropertyFile ${PackagePropertyFile})
endfunction()

