cmake_minimum_required(VERSION 2.8)

if (DEFINED PackageConfiguratorGuard)
    return()
endif()

set(PackageConfiguratorGuard yes)

find_program(SED_TOOL sed)
if(NOT SED_TOOL)
    message(FATAL_ERROR "error: could not find sed.")
endif()

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
function(sbeConfigurePackage)

    # Property file is mandratory for each project
    sbeReportErrorWhenFileDoesntExists(PackagePropertyFile
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
    sbeFindContextFile(${Name} contextFile)
    sbeLoadContextFile(${contextFile})
    sbeExportPackageDependencies(${Name} ${PackagePropertyFile})
    set(DirectDependencies ${Dependencies} CACHE "" INTERNAL FORCE)
endfunction()

function(sbeConfigureDependencies)
    # if package has no dependencies do nothing
    if(NOT DEFINED OverallDependencies)
        return()
    endif()
    
    # get packages to configure
    set(dependenciesToConfigure ${OverallDependencies})
    if(DEFINED Configured_OverallDependencies)
        list(REMOVE_ITEM dependenciesToConfigure ${Configured_OverallDependencies})
    endif()
    
    foreach(dep ${dependenciesToConfigure})
        sbeConfigureDependency(${dep})
    endforeach()
    set(Configured_OverallDependencies ${OverallDependencies} CACHE "" INTERNAL FORCE)
    
    # load configured dependencies
    foreach(dep ${OverallDependencies})
        sbeGetPackageConfigPath(${name} configPath)
        find_package(${dep} REQUIRED CONFIG PATHS "${configPath}" NO_DEFAULT_PATH)
    endforeach()
    
    # add dependecies targets that ensure dependency build
    foreach(dep ${OverallDependencies})
        sbeGetPackageBuildPath(${dep} buildPath)
        sbeGetPackageBuildTimestamp(${dep} timestamp)
        
        set(dependencyTimestamps "")
        foreach(d (${dep}_DirectDependencies})
            sbeGetPackageBuildTimestamp(${d} t)
            list(APPEND dependencyTimestamps ${t})
        endforeach()
        
        add_custom_command(
            OUTPUT ${timestamp}
            COMMAND ${CMAKE_COMMAND} --build . --use-stderr
            DEPENDS ${dependencyTimestamps}
            WORKING_DIRECTORY ${buildPath}
        )
    endforeach()
    
    # setup denepdencies for own package
    set(dependencyTimestamps "")
    foreach(dep ${DirectDependencies})
        sbeGetPackageBuildTimestamp(${d} t)
        list(APPEND dependencyTimestamps ${t})
    endforeach()
    
    add_custom_command(
            OUTPUT dependencies.buildtimestamp
            COMMAND ${CMAKE_COMMAND} -E touch dependencies.buildtimestamp
            DEPENDS ${dependencyTimestamps}
    )
 endfunction()

function(sbeConfigureDependency name)
    sbeGetPackageBuildPath(${name} buildPath)
    
    # if dependency is configured skip dependency
    if(EXISTS "${buildPath}/Makefile")
        return()
    endif()
    
    message(STATUS "Configuring dependency ${name}")

    # create build directory    
    file(MAKE_DIRECTORY ${buildPath})
    
    # create arguments for configuring
    list(APPEND configurationArgs "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    list(APPEND configurationArgs "-DSBE_CoverityIsRequested=${Coverity_IsConfigured}")
    list(APPEND configurationArgs "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
    if(RULE_LAUNCH_COMPILE)
        list(APPEND configurationArgs "-DRULE_LAUNCH_COMPILE=${RULE_LAUNCH_COMPILE}")
    endif()
    if(RULE_LAUNCH_LINK)
        list(APPEND configurationArgs "-DRULE_LAUNCH_LINK=${RULE_LAUNCH_LINK}")
    endif()

    # configure dependency
    execute_process(
        COMMAND cmake -E chdir ${buildPath} 
            cmake ${configurationArgs}
            ${packagePath}
        COMMAND ${SED_TOOL} -u -e "s/.*/    &/"
        RESULT_VARIABLE configureResult)
    
    # handle configuration result
    if((${configureResult} GREATER 0) OR (NOT EXISTS ${buildPath}/Makefile))
        message(FATAL_ERROR "Error during configuration of dependency ${name}")
    endif()
endfunction()
