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

# each project has to have properties.cmake file, where project is described
set(PackagePropertyFile ${CMAKE_SOURCE_DIR}/Properties.cmake)

include(SBE/helpers/ArgumentParser)
include(SBE/helpers/ContextParser)
include(SBE/PackageExporter)
include(SBE/TargetTag)
include(SBE/TargetGraph)
include(SBE/helpers/ColorMessage)

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
        
    cmake_parse_arguments(prj "" "JiraUrl" "Languages;JiraProjectKeys" ${ARGN})
    
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
    sbeGetDependenciesNames(directDependencies "${Dependencies}")
    set(DirectDependencies ${directDependencies} CACHE "" INTERNAL FORCE)
    
    # configure dependencies
    sbeConfigureDependencies()
    sbeLoadDependencies()
    
    # add defalt targets
    sbeGetPackageLocationType(${Name} locationType)
    if("repository" STREQUAL "${locationType}")
        sbeAddTagTarget(JiraProjectKeys ${prj_JiraProjectKeys} JiraUrl ${prj_JiraUrl})
    endif()
    
    sbeAddGraphTarget()
   
    # add target build timestamp that is used also by dependencies
    sbeGetPackageAllBuildTimestamp(${PROJECT_NAME} allbuildtimestamp)
    sbeGetPackageBuildTimestamp(${PROJECT_NAME} buildtimestamp)
    add_custom_target(buildtimestamp ALL 
        COMMAND ${CMAKE_COMMAND} -E touch ${allbuildtimestamp} 
        COMMAND ${CMAKE_COMMAND} -E touch ${buildtimestamp}
        COMMENT "")
    
    # directory for public files of this project    
    file(MAKE_DIRECTORY  ${PROJECT_BINARY_DIR}/Export)        
endmacro()

function(sbeConfigureDependencies)
    # if package has no dependencies do nothing
    if("" STREQUAL "${OverallDependencies}")
        return()
    endif()
    
    # get packages to configure
    # remove from Configured dependencies, dependencies that have deleted build directory
    set(dependenciesToConfigure "")
    foreach(dep ${OverallDependencies})
        sbeGetPackageBuildPath(${dep} buildPath)
    
        if(NOT EXISTS "${buildPath}/Makefile")
            sbeConfigureDependency(${dep} ${buildPath})
        endif() 
    endforeach()

    # add dependencies rebuild target
    add_custom_target(dependencies_touch COMMENT "Touching dependencies")
    # add dependencies clean target
    add_custom_target(dependencies_clean COMMENT "Clean dependencies")
    
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
            COMMAND + ${CMAKE_COMMAND} --build ${buildPath} --use-stderr
            DEPENDS ${dependencyTimestamps} ${timestamp}
            COMMENT "Building ${dep}")
            
        add_custom_command(TARGET dependencies_touch
            COMMAND ${CMAKE_COMMAND} -E remove ${allbuildtimestamp}
            COMMENT "Touching ${dep}")
            
        add_custom_command(TARGET dependencies_clean
            COMMAND + ${CMAKE_COMMAND} --build ${buildPath} --target clean --use-stderr
            COMMENT "Cleaning ${dep}")            
    endforeach()
    
    if(NOT "" STREQUAL "${DirectDependencies}")
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
    else()
        add_custom_target(dependencies COMMENT "")
    endif()
 endfunction()

function(sbeConfigureDependency name buildPath)
    colormsg(HIBLUE "Configuring ${name}")
    
    # create build directory    
    file(MAKE_DIRECTORY ${buildPath})
    
    # create arguments for configuring
    if(DEFINED CMAKE_BUILD_TYPE)
        list(APPEND configurationArgs "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    endif()
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
        COMMAND ${CMAKE_COMMAND} -E chdir ${buildPath} ${CMAKE_COMMAND} ${configurationArgs} ${packagePath}
        RESULT_VARIABLE configureResult)
    
    # handle configuration result
    if((${configureResult} GREATER 0) OR (NOT EXISTS ${buildPath}/Makefile))
        message(FATAL_ERROR "Error during configuration of dependency ${name}")
    endif()
    
    colormsg(HIBLUE "Configuring ${name} -- done")
endfunction()

macro(sbeLoadDependencies)
    # load configured dependencies
    message(STATUS "Loading Dependencies")
    foreach(dep ${OverallDependencies})
        sbeGetPackageConfigPath(${dep} configPath)
        find_package(${dep} CONFIG PATHS "${configPath}" NO_DEFAULT_PATH QUIET)
        if(NOT ${dep}_FOUND)
            sbeGetToolChainName(toolchainName)
            message(STATUS "   ${dep} provides nothing for ${toolchainName}")
        endif()
    endforeach()
endmacro()