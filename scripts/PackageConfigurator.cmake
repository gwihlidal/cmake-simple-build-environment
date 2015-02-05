cmake_minimum_required(VERSION 2.8)

if (DEFINED PackageConfiguratorGuard)
    return()
endif()

set(PackageConfiguratorGuard yes)

# suppress unused variables warning
if(CMAKE_TOOLCHAIN_FILE)
endif()
if(RULE_LAUNCH_COMPILE)
endif()
if(RULE_LAUNCH_LINK)
endif()
if(SBE_CoverityIsRequested)
endif()

find_program(SED_TOOL sed)
if(NOT SED_TOOL)
    message(FATAL_ERROR "error: could not find sed.")
endif()

# each project has to have properties.cmake file, where project is described
set(PackagePropertyFile ${CMAKE_SOURCE_DIR}/Properties.cmake)

include(SBE/helpers/ArgumentParser)
include(SBE/helpers/ContextParser)
include(SBE/PackageExporter)
include(SBE/TargetTag)
include(SBE/TargetGraph)
include(SBE/TargetHelp)
include(SBE/TargetCoverity)

# macro calculates mandratory variables if not given
# - sets project laguage to C and CXX
# - finds Context.cmake file
# macro checks mandratory variables in property file
# - Name
# - SemanticVersion or DateVersion
macro(sbeConfigurePackage)

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
    
    # define project
    project(${Name} ${projectLanguages})
    
    # export dependencies
    sbeFindContextFile(${Name} contextFile)
    sbeLoadContextFile(${contextFile})
    sbeExportPackageDependencies(${Name} ${PackagePropertyFile})
    sbeGetDependenciesNames(directDependencies)
    set(DirectDependencies ${directDependencies} CACHE "" INTERNAL FORCE)
    
    # configure dependencies
    sbeConfigureDependencies()
    sbeLoadDependencies()
    
    # add defalt targets
    sbeGetPackageLocationType(${Name} locationType)
    if("repository" STREQUAL "${locationType}")
        sbeAddTagTarget()
    endif()
    if(Coverity_IsRequestedByDependant)
        sbeConfigureCoverity()
    endif()
    sbeAddGraphTarget()
    sbeAddHelpTarget()
endmacro()

function(sbeConfigureDependencies)
    # if package has no dependencies do nothing
    if("" STREQUAL "${OverallDependencies}")
        set(Configured_OverallDependencies ${OverallDependencies} CACHE "" INTERNAL FORCE)
        return()
    endif()
    
    message(STATUS "Configuring Dependencies")
    
    # get packages to configure
    # remove from Configured dependencies, dependencies that have deleted build directory
    set(dependenciesToConfigure "")
    foreach(dep ${OverallDependencies})
        sbeGetPackageBuildPath(${dep} buildPath)
    
        if(NOT EXISTS "${buildPath}/Makefile")
            list(APPEND dependenciesToConfigure ${dep})
        endif() 
    endforeach()

    foreach(dep ${dependenciesToConfigure})
        sbeConfigureDependency(${dep})
    endforeach()
    set(Configured_OverallDependencies ${OverallDependencies} CACHE "" INTERNAL FORCE)
    
    # add dependencies rebuild target
    add_custom_target(dependencies_force COMMENT "Force dependencies build")
    sbeAddHelpForTarget(Dependencies dependencies_force "Force dependencies build")
    # add dependencies clean target
    add_custom_target(dependencies_clean COMMENT "Clean dependencies")
    sbeAddHelpForTarget(Dependencies dependencies_clean "Clean dependencies")
    
    # add dependecies targets that ensure dependency build
    foreach(dep ${OverallDependencies})
        sbeGetPackageBuildPath(${dep} buildPath)
        sbeGetPackageBuildTimestamp(${dep} timestamp)
        sbeGetPackageAllBuildTimestamp(${dep} allbuildtimestamp)
        
        set(dependencyTimestamps "")
        foreach(d ${${dep}_DirectDependencies})
            sbeGetPackageAllBuildTimestamp(${d} t)
            list(APPEND dependencyTimestamps ${t})
        endforeach()

        add_custom_command(
            OUTPUT ${timestamp}
            COMMENT "")
                        
        add_custom_command(
            OUTPUT ${allbuildtimestamp}
            COMMAND ${CMAKE_COMMAND} --build . --use-stderr
            DEPENDS ${dependencyTimestamps} ${timestamp}
            WORKING_DIRECTORY ${buildPath}
            COMMENT "Building ${dep}")
            
        add_custom_command(TARGET dependencies_force
            COMMAND ${CMAKE_COMMAND} --build . --use-stderr
            WORKING_DIRECTORY ${buildPath}
            COMMENT "Building ${dep}")

        add_custom_command(TARGET dependencies_clean
            COMMAND ${CMAKE_COMMAND} --build . --target clean --use-stderr
            WORKING_DIRECTORY ${buildPath}
            COMMENT "Cleaning ${dep}")            
    endforeach()
    
    # setup dependencies for own package
    set(dependencyTimestamps "")
    foreach(dep ${DirectDependencies})
        sbeGetPackageAllBuildTimestamp(${dep} t)
        list(APPEND dependencyTimestamps ${t})
    endforeach()
    
    add_custom_command(
        OUTPUT dependencies.buildtimestamp
        COMMAND ${CMAKE_COMMAND} -E touch dependencies.buildtimestamp
        DEPENDS ${dependencyTimestamps}
        COMMENT "")
    
    add_custom_target(dependencies DEPENDS dependencies.buildtimestamp COMMENT "")
    sbeAddHelpForTarget(Dependencies dependencies "Build traversely dependants of changed dependency")
 endfunction()

function(sbeConfigureDependency name)
    sbeGetPackageBuildPath(${name} buildPath)
    
    # if dependency is configured skip dependency
    if(EXISTS "${buildPath}/Makefile")
        return()
    endif()

    message(STATUS "   ${name}")

    # create build directory    
    file(MAKE_DIRECTORY ${buildPath})
    
    # create arguments for configuring
    if(DEFINED CMAKE_BUILD_TYPE)
        list(APPEND configurationArgs "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    endif()
    list(APPEND configurationArgs "-DSBE_CoverityIsRequested=${Coverity_IsConfigured}")
    if(DEFINED CMAKE_TOOLCHAIN_FILE)
        list(APPEND configurationArgs "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
    endif()
    if(RULE_LAUNCH_COMPILE)
        list(APPEND configurationArgs "-DRULE_LAUNCH_COMPILE=${RULE_LAUNCH_COMPILE}")
    endif()
    if(RULE_LAUNCH_LINK)
        list(APPEND configurationArgs "-DRULE_LAUNCH_LINK=${RULE_LAUNCH_LINK}")
    endif()

    # configure dependency
    sbeGetPackageLocalPath(${name} packagePath)
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E chdir ${buildPath} 
            ${CMAKE_COMMAND} ${configurationArgs}
            ${packagePath}
        COMMAND ${SED_TOOL} -u -e "s/.*/      &/"
        RESULT_VARIABLE configureResult)
    
    # handle configuration result
    if((${configureResult} GREATER 0) OR (NOT EXISTS ${buildPath}/Makefile))
        message(FATAL_ERROR "Error during configuration of dependency ${name}")
    endif()
endfunction()

macro(sbeLoadDependencies)
    # load configured dependencies
    foreach(dep ${OverallDependencies})
        sbeGetPackageConfigPath(${dep} configPath)
        find_package(${dep} REQUIRED CONFIG PATHS "${configPath}" NO_DEFAULT_PATH)
    endforeach()
endmacro()