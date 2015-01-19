cmake_minimum_required(VERSION 2.8)

if (DEFINED PackageExporterGuard)
    return()
endif()

set(PackageExporterGuard yes)

include(SBE/helpers/ContextParser)
include(SBE/helpers/SvnHelpers)
include(SBE/helpers/ArgumentParser)

function(sbeExportDependencies dependency propertyFile)
    # properties file must exist
    sbeReportErrorWhenFileDoesntExists(propertyFile "Properties file must exist to export dependencies.")
    
    unset(Name)
    unset(Dependencies)
    include(${propertyFile})
    
    # if Name is given as argument then it has to be same is in ContextFile
    if(NOT "${dependency}" STREQUAL "${Name}")
        message(FATAL_ERROR
            "Name in Properties file [${Name}] is different as in Context [${dependency}]." 
        )        
    endif()

    set_property(GLOBAL PROPERTY Export_${Name}_DirectDependencies ${Dependencies})
    file(TIMESTAMP "${propertyFile}" ts "%Y-%m-%dT%H:%M:%S")
    set_property(GLOBAL PROPERTY Export_${Name}_PropertiesTimestamp ${ts})
    
    foreach(dependency ${Dependencies})
        sbeExportDependency(${dependency})
    endforeach()
endfunction()

function(sbeExportDependency name)
    # do NOT process already processed dependency
    get_property(OverallDependencies GLOBAL PROPERTY Export_OverallDependencies)
    if("${OverallDependencies}" MATCHES "${name}")
        return()
    endif()
    
    set_property(GLOBAL APPEND PROPERTY Export_OverallDependencies ${name})
    
    # context file must exist
    sbeReportErrorWhenContextFileIsNotLoaded()
    
    sbeGetPackageLocalPath(${name} packagePath)
    sbeGetPackageUrl(${name} packageUrl)
    
    if(NOT EXISTS ${packagePath})
        svnCheckout(LocalDirectory ${packagePath} Url ${packageUrl}
            StartMessage "Checking out ${name} ${packageUrl}"
            StopOnErrorWithMessage "Could NOT checkout ${packageUrl} for ${name}")
    else()
        svnGetRepositoryForLocalDirectory(${packagePath} url)
        
        svnIsUrlTag(${url} isTag)
        
        if(isTag)
            if(NOT "${url}" STREQUAL "${packageUrl}")
                svnSwitch(LocalDirectory ${packagePath} Url ${packageUrl}
                    StartMessage "Switching ${name} ${packageUrl}"
                    StopOnErrorWithMessage "Could NOT switch to ${packageUrl} for ${name}" 
                )
            endif()
        else()
            message("Ignoring ${name} due to trunk")
        endif()        
    endif()
    
    sbeExportDependencies(${name} ${packagePath}/Properties.cmake)    
endfunction()

function(sbeExportDependenciesInPackage name propertyFile)
    # When Context file is modified recheck all dependencies
    getContextTimestamp(actualContextTimestamp)
    
    set(IsExportNecessary no)
    
    if("${actualContextTimestamp}" STREQUAL "${Export_ContextTimestamp}")
        foreach(exportedDependency ${Export_OverallDependencies})
            sbeGetPackagePropertiesTimestamp(${exportedDependency} ts)
            if("${ts}" STREQUAL "${Export_${exportedDependency}_PropertiesTimestamp}")
                set_property(GLOBAL APPEND PROPERTY Export_OverallDependencies ${exportedDependency})
                set_property(GLOBAL PROPERTY Export_${exportedDependency}_DirectDependencies ${Export_${exportedDependency}_DirectDependencies})
                set_property(GLOBAL PROPERTY Export_${exportedDependency}_PropertiesTimestamp ${Export_${exportedDependency}_PropertiesTimestamp})
            else()
                set(IsExportNecessary yes)
            endif()
        endforeach()
    else()
        set(IsExportNecessary yes)
    endif()
    
    if(IsExportNecessary)
        sbeExportDependencies(${name} ${propertyFile})

        # set cached variables for usage in next run    
        set(Export_ContextTimestamp ${actualContextTimestamp} CACHE "" INTERNAL FORCE)
        
        get_property(Export_UnorderedOverallDependencies GLOBAL PROPERTY Export_OverallDependencies)

        foreach(exportedDependency ${Export_UnorderedOverallDependencies})
            get_property(deps GLOBAL PROPERTY Export_${exportedDependency}_DirectDependencies)
            set(Export_${exportedDependency}_DirectDependencies ${deps} CACHE "" INTERNAL FORCE)
            get_property(ts GLOBAL PROPERTY Export_${exportedDependency}_PropertiesTimestamp)
            set(Export_${exportedDependency}_PropertiesTimestamp ${ts} CACHE "" INTERNAL FORCE)
        endforeach()
        
        OrderDependecies("${Export_UnorderedOverallDependencies}")
        get_property(Export_OrderedOverallDependencies GLOBAL PROPERTY Export_OrderedOverallDependencies)
        set(Export_OverallDependencies ${Export_OrderedOverallDependencies} CACHE "" INTERNAL FORCE)
    endif()
endfunction()

function(OrderDependecies dependencies)
    if("" STREQUAL "${dependencies}")
        return()
    endif()
    
    set(isLoop yes)
    get_property(Export_OrderedOverallDependencies GLOBAL PROPERTY Export_OrderedOverallDependencies)
    
    foreach(dependency ${dependencies})
        if("" STREQUAL "${Export_${dependency}_DirectDependencies}")
            set(isLoop no)
            set_property(GLOBAL APPEND PROPERTY Export_OrderedOverallDependencies ${dependency})
        elseif(NOT "" STREQUAL "${Export_OrderedOverallDependencies}")
            set(directDependencies ${Export_${dependency}_DirectDependencies})
            list(REMOVE_ITEM directDependencies ${Export_OrderedOverallDependencies})
            list(LENGTH directDependencies directDependenciesNumber)
            if (${directDependenciesNumber} EQUAL 0)
                set(isLoop no)
                set_property(GLOBAL APPEND PROPERTY Export_OrderedOverallDependencies ${dependency})
            endif()
       endif()
    endforeach()
    
    if(${isLoop})
        return()
    endif()
  
    set(dependenciesLeft ${dependencies})
    get_property(Export_OrderedOverallDependencies GLOBAL PROPERTY Export_OrderedOverallDependencies)
    list(REMOVE_ITEM dependenciesLeft ${Export_OrderedOverallDependencies})
    OrderDependecies("${dependenciesLeft}")
endfunction()

#    
#if(NOT DEFINED SBE_MAIN_DEPENDANT_SOURCE_DIR)
#    message(FATAL_ERROR "Path to Properties.txt has to be DEFINED as SBE_MAIN_DEPENDANT_SOURCE_DIR=path.")
#endif()
#
#if(NOT DEFINED SBE_MAIN_DEPENDANT)
#    include(${SBE_MAIN_DEPENDANT_SOURCE_DIR}/Properties.cmake)
#    set(MAIN_DEPENDANT ${NAME})
#else()
#    set(MAIN_DEPENDANT ${SBE_MAIN_DEPENDANT})
#endif()
#
# in case of stand alone script
#if(NOT DEFINED PROJECT_SOURCE_DIR)
#    set(PROJECT_SOURCE_DIR ${SBE_MAIN_DEPENDANT_SOURCE_DIR})
#endif()
#
# set export directories
#set(DEP_SOURCES_PATH "${SBE_MAIN_DEPENDANT_SOURCE_DIR}/dependencies/sources")
#set(DEP_SRC_INFO_PATH "${SBE_MAIN_DEPENDANT_SOURCE_DIR}/dependencies/info")
#set(DEP_INFO_FILE "${DEP_SRC_INFO_PATH}/info.cmake")
#
# find all necessary tools
#find_package(Subversion QUIET)
#if(NOT Subversion_SVN_EXECUTABLE)
#    message(FATAL_ERROR "error: could NOT find svn.")
#endif()
#
#include(SBE/helpers/DependenciesParser)
#
# create export directories    
#if(NOT EXISTS "${DEP_SRC_INFO_PATH}")
#    file(MAKE_DIRECTORY "${DEP_SRC_INFO_PATH}")
#endif()
#
#if(NOT EXISTS "${DEP_SOURCES_PATH}")
#    file(MAKE_DIRECTORY "${DEP_SOURCES_PATH}")
#endif()
#
#include(${DEP_INFO_FILE} OPTIONAL)
#
# export all properties files    
#function(ExportProperties dependencies)
#    if(EXISTS ${DEP_INFO_FILE} AND ${DEP_INFO_FILE} IS_NEWER_THAN ${PROJECT_SOURCE_DIR}/Properties.cmake)
#        return()
#    endif()
#
#    if ("${MAIN_DEPENDANT}" STREQUAL "${NAME}")
#        set_property(GLOBAL PROPERTY New_${NAME}_Name "${NAME}")
#        set_property(GLOBAL PROPERTY New_${NAME}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
#        set_property(GLOBAL PROPERTY New_${NAME}_Type "${TYPE}")
#        set_property(GLOBAL PROPERTY New_${NAME}_ScmPath "")
#        set_property(GLOBAL PROPERTY New_${NAME}_ScmType "")
#        set_property(GLOBAL PROPERTY New_${NAME}_IsExternal "no")
#        set_property(GLOBAL PROPERTY New_${NAME}_DependenciesDescription ${dependencies})
#        set(${NAME}_Name "${NAME}")
#        set(${NAME}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
#        set(${NAME}_Type "${TYPE}")
#        set(${NAME}_ScmPath "")
#        set(${NAME}_ScmType "")
#        set(${NAME}_IsExternal "no")
#        set(${NAME}_DependenciesDescription ${dependencies})
#    else()
#        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_Name "${${MAIN_DEPENDANT}_Name}")
#        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_Version "${${MAIN_DEPENDANT}_Version}")
#        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_Type "${${MAIN_DEPENDANT}_Type}")
#        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_ScmPath "")
#        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_ScmType "")
#        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_IsExternal "no")
#        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_DependenciesDescription ${${MAIN_DEPENDANT}_DependenciesDescription})
#    endif()
#            
#    _areOwnDependenciesChanged("${dependencies}" areChanged areExternalFlagsChanged)
#    
#    if(NOT areChanged)
#        if(NOT areExternalFlagsChanged)
            # nothing to do
#            _cleanup()
#            return()
#        endif()
#        
        # setup new dependencies data
#        _getOverallDependenciesProperties(isLoopDetected)
#                
#        _exposePropertiesAsVariables("New")
#        
        # generate picture
#        _printDependencies(${MAIN_DEPENDANT})
#        
#        _storeNewInfoFile()
#        
        # only picture is chaged, nothing else has to be done
#        _cleanup()
#        return()
#    endif()
#    
#    _getOverallDependenciesProperties(isLoopDetected)
#    
#    _exposePropertiesAsVariables("New")
#        
#    _printDependencies(${MAIN_DEPENDANT})
#    
#    if(isLoopDetected)        
#        _exit("Check dependencies picture for loops.")
#    endif()
#    
#    _checkDependenciesVersionsAndStopOnError()
#
#    _removeUnusedDependencies()
#    
#    _exportRequiredDependencies()
#
#    _storeNewInfoFile()
#        
#    _cleanup()
#endfunction(ExportProperties)
#
#function(_getOverallDependenciesProperties ild)
#    _getDependenciesInfo(${MAIN_DEPENDANT} "${${MAIN_DEPENDANT}_DependenciesDescription}")
#
#    _orderDependeniesAndCheckLoops(isLoopDetected)
#    
#    if (NOT isLoopDetected)
#        _getDependantsInfo()
#        
#       _createInfoAboutExternalFlag()
#    endif()
#    
#    set(${ild} ${isLoopDetected} PARENT_SCOPE)
#endfunction()
#
#macro(_exposePropertiesAsVariables prefix)
    # properties to variable
#    
#    get_property(${prefix}_OverallDependencies GLOBAL PROPERTY New_${MAIN_DEPENDANT}_OverallDependencies)
#    
#    if(DEFINED ${prefix}_OverallDependencies)
#        list(REMOVE_DUPLICATES ${prefix}_OverallDependencies)
#    endif()
#    
#    foreach(dep ${${prefix}_OverallDependencies} ${MAIN_DEPENDANT})
#        _exposeDependencyPropertiesAsVariable(${dep} "${prefix}")
#    endforeach()
#            
#    get_property(${prefix}_OverallDependenciesNames GLOBAL PROPERTY New_OverallDependenciesNames)
#    if(DEFINED ${prefix}_OverallDependenciesNames)
#        list(REMOVE_DUPLICATES ${prefix}_OverallDependenciesNames)
#    endif()
#    
#    foreach(dep ${${prefix}_OverallDependenciesNames})
#        get_property(${prefix}_${dep}_Packages GLOBAL PROPERTY New_${dep}_Packages)
#    endforeach()
#   
#    get_property(${prefix}_ExternalDependencies GLOBAL PROPERTY New_ExternalDependencies)
#    if(DEFINED ${prefix}_ExternalDependencies)
#        list(REMOVE_DUPLICATES ${prefix}_ExternalDependencies)
#    endif()
#    
#    get_property(${prefix}_ParallelBuildGroups GLOBAL PROPERTY New_OrderedOverallDependenciesGroups)
#    foreach(group ${${prefix}_ParallelBuildGroups})
#        get_property(${prefix}_ParallelBuildGroup_${group} GLOBAL PROPERTY New_ParallelBuildGroup_${group})
#    endforeach()
#endmacro()
#
#macro(_exposeDependencyPropertiesAsVariable dep prefix)
#    get_property(${prefix}_${dep}_Dependants GLOBAL PROPERTY New_${dep}_Dependants)
#    if(DEFINED ${prefix}_${dep}_Dependants)
#        list(REMOVE_DUPLICATES ${prefix}_${dep}_Dependants)
#    endif()
#    
#    get_property(${prefix}_${dep}_OverallDependants GLOBAL PROPERTY New_${dep}_OverallDependants)
#    if(DEFINED ${prefix}_${dep}_OverallDependants)
#        list(REMOVE_DUPLICATES ${prefix}_${dep}_OverallDependants)
#    endif()
#    
#    get_property(${prefix}_${dep}_Dependencies GLOBAL PROPERTY New_${dep}_Dependencies)
#    if(DEFINED ${prefix}_${dep}_Dependencies)
#        list(REMOVE_DUPLICATES ${prefix}_${dep}_Dependencies)
#    endif()
#    
#    get_property(${prefix}_${dep}_OverallDependencies GLOBAL PROPERTY New_${dep}_OverallDependencies)
#    if(DEFINED ${prefix}_${dep}_OverallDependencies)
#        list(REMOVE_DUPLICATES ${prefix}_${dep}_OverallDependencies)
#    endif()
#
#    get_property(${prefix}_${dep}_Name GLOBAL PROPERTY New_${dep}_Name)
#    get_property(${prefix}_${dep}_Type GLOBAL PROPERTY New_${dep}_Type)
#    get_property(${prefix}_${dep}_Version GLOBAL PROPERTY New_${dep}_Version)
#    get_property(${prefix}_${dep}_ScmPath GLOBAL PROPERTY New_${dep}_ScmPath)
#    get_property(${prefix}_${dep}_ScmType GLOBAL PROPERTY New_${dep}_ScmType)
#    get_property(${prefix}_${dep}_DependenciesDescription GLOBAL PROPERTY New_${dep}_DependenciesDescription)
#    get_property(${prefix}_${dep}_IsExternal GLOBAL PROPERTY New_${dep}_IsExternal)
#endmacro()
#
#function(_storeNewInfoFile)
#    set(info "")
#
#    list(APPEND info "if(DEFINED isInfoFileIncluded)\n")
#    list(APPEND info "   return()\n")
#    list(APPEND info "endif()\n")
#    list(APPEND info "set(isInfoFileIncluded yes)\n")
#    list(APPEND info "\n")
#    
#    list(APPEND info "set(MAIN_DEPENDANT ${MAIN_DEPENDANT})\n")
#    
#    set(tmp ${New_OverallDependencies} ${MAIN_DEPENDANT})
#    list(REMOVE_DUPLICATES tmp)
#    foreach(dependency ${tmp})
#        set(dep ${New_${dependency}_Name})
#        list(APPEND info "# Begin of info for dependecy ${dep}\n")
#        list(APPEND info "set(${dependency}_Name \"${New_${dependency}_Name}\")\n")
#        list(APPEND info "set(${dep}_Id \"${dependency}\")\n")
#        list(APPEND info "set(${dep}_Name \"${New_${dependency}_Name}\")\n")
#        list(APPEND info "set(${dep}_Type \"${New_${dependency}_Type}\")\n")
#        list(APPEND info "set(${dep}_Version \"${New_${dependency}_Version}\")\n")
#        list(APPEND info "set(${dep}_ScmPath \"${New_${dependency}_ScmPath}\")\n")
#        list(APPEND info "set(${dep}_ScmType \"${New_${dependency}_ScmType}\")\n")
#        list(APPEND info "set(${dep}_IsExternal \"${New_${dependency}_IsExternal}\")\n")
#        list(APPEND info "set(${dep}_DependenciesDescription \"\")\n")
#        foreach(dependencyDescriptionItem ${New_${dependency}_DependenciesDescription})
#            list(APPEND info "list(APPEND ${dep}_DependenciesDescription \"${dependencyDescriptionItem}\")\n")
#        endforeach()
#        list(APPEND info "set(${dep}_Dependencies \"\")\n")
#        foreach(dependencyId ${New_${dependency}_Dependencies})
#            list(APPEND info "list(APPEND ${dep}_Dependencies \"${New_${dependencyId}_Name}\")\n")
#        endforeach()
#        list(APPEND info "set(${dep}_OverallDependencies \"\")\n")
#        foreach(dependencyId ${New_${dependency}_OverallDependencies})
#            list(APPEND info "list(APPEND ${dep}_OverallDependencies \"${New_${dependencyId}_Name}\")\n")
#        endforeach()
#        list(APPEND info "set(${dep}_Dependants \"\")\n")
#        foreach(dependencyId ${New_${dependency}_Dependants})
#            list(APPEND info "list(APPEND ${dep}_Dependants \"${New_${dependencyId}_Name}\")\n")
#        endforeach()
#        list(APPEND info "set(${dep}_OverallDependants \"\")\n")
#        foreach(dependencyId ${New_${dependency}_OverallDependants})
#            list(APPEND info "list(APPEND ${dep}_OverallDependants \"${New_${dependencyId}_Name}\")\n")
#        endforeach()                
#        list(APPEND info "# End of info for dependecy ${dep}\n")
#    endforeach()
#
#    list(APPEND info "# Begin of Overall dependnecnies\n")    
#    list(APPEND info "set(OverallDependencies \"\")\n")
#    foreach(dep ${New_OverallDependencies})
#        list(APPEND info "list(APPEND OverallDependencies \"${New_${dep}_Name}\")\n")
#    endforeach()
#    list(APPEND info "# End of Overall dependnecnies\n")
#    
#    list(APPEND info "# Begin of External dependnecnies\n")    
#    list(APPEND info "set(ExternalDependencies \"\")\n")
#    foreach(dep ${New_ExternalDependencies})
#        list(APPEND info "list(APPEND ExternalDependencies \"${New_${dep}_Name}\")\n")
#    endforeach()
#    list(APPEND info "# End of External dependnecnies\n")
#    
#    list(APPEND info "# Begin of parallel build groups\n")    
#    list(APPEND info "set(ParallelBuildGroups \"\")\n")
#    foreach(group ${New_ParallelBuildGroups})
#        list(APPEND info "list(APPEND ParallelBuildGroups \"${group}\")\n")
#        list(APPEND info "set(ParallelBuildGroup_${group} \"\")\n")
#        foreach(dep ${New_ParallelBuildGroup_${group}})
#            list(APPEND info "list(APPEND ParallelBuildGroup_${group} \"${New_${dep}_Name}\")\n")
#        endforeach()
#    endforeach()
#    list(APPEND info "# End of parallel build groups\n")
#        
#    file(WRITE ${DEP_INFO_FILE} ${info})
#endfunction()
#
#
#
#    _getDependenciesInfo
#        export all dependencies for package with name dependant
#
#
#function(_getDependenciesInfo dependant dependencies)
#    ParseDependencies("${dependencies}" dependenciesIndentifiers "ad")
#
    # remember dependant dependecies
#    set_property(GLOBAL PROPERTY New_${dependant}_Dependencies ${dependenciesIndentifiers})
#   
    # remember data   
#    foreach(dependecyIdentifier ${dependenciesIndentifiers})
        # once any dependency set external, it stays external
#        get_property(isAlreadyExternal GLOBAL PROPERTY New_${dependecyIdentifier}_IsExternal)
#        if (NOT isAlreadyExternal AND ${ad_${dependecyIdentifier}_IsExternal})
#            set_property(GLOBAL PROPERTY New_${dependecyIdentifier}_IsExternal "yes")
#        endif()
#        
#        set_property(GLOBAL PROPERTY New_${dependecyIdentifier}_ScmPath ${ad_${dependecyIdentifier}_ScmPath})
#        set_property(GLOBAL PROPERTY New_${dependecyIdentifier}_ScmType ${ad_${dependecyIdentifier}_ScmType})
#    endforeach()
#    
    # get data recursively
#    foreach(dependecyIdentifier ${dependenciesIndentifiers})
        # export dependecy property
#        _getDependencyInfo(${dependant} ${dependecyIdentifier}) 
#
#        get_property(dependencyDependencies GLOBAL PROPERTY New_${dependecyIdentifier}_OverallDependencies)
#        set(tmp ${dependecyIdentifier} ${dependencyDependencies})
#        list(REMOVE_DUPLICATES tmp)
#        set_property(GLOBAL APPEND PROPERTY New_${dependant}_OverallDependencies ${tmp})
#    endforeach()
#endfunction(_getDependenciesInfo)
#
#function(_getDependantsInfo)
#    get_property(overallDeps GLOBAL PROPERTY New_${MAIN_DEPENDANT}_OverallDependencies)
#    set(overallDepsReversed ${overallDeps})
#    list(REVERSE overallDepsReversed)
#    foreach(dep ${overallDepsReversed})
#        get_property(depDirectDependants GLOBAL PROPERTY New_${dep}_Dependants)
#        foreach(dependant ${depDirectDependants})
#            get_property(dependantDependants GLOBAL PROPERTY New_${dependant}_OverallDependants)
#            set(tmp ${dependant} ${dependantDependants})
#            list(REMOVE_DUPLICATES tmp)
#            set_property(GLOBAL APPEND PROPERTY New_${dep}_OverallDependants ${tmp})
#        endforeach()
        # sort
#        get_property(oad GLOBAL PROPERTY New_${dep}_OverallDependants)
#        if (NOT "" STREQUAL "${oad}")
#            set(tmp ${overallDeps} ${MAIN_DEPENDANT})
#            list(REMOVE_ITEM tmp ${oad})
#            set(sorted ${overallDeps} ${MAIN_DEPENDANT})
#            list(REMOVE_ITEM sorted ${tmp})
#            set_property(GLOBAL PROPERTY New_${dep}_OverallDependants ${sorted})
#        endif()
#    endforeach()
#endfunction()
#
# export one dependency for given dependant
#function(_getDependencyInfo dependant dependency)
#
#    get_property(dependencyName GLOBAL PROPERTY New_${dependency}_Name)
#
#    if(NOT "${dependencyName}" STREQUAL "")
        # depenedency already processed in this turn, add only dependant
#        set_property(GLOBAL APPEND PROPERTY New_${dependency}_Dependants ${dependant})
#        return()
#    endif()
#    
#    if(NOT "${${dependency}_Name}" STREQUAL "")
        # depenedency already processed in previous turn, fill all stored data
#        _fillNewDependecyFromStoredOne(${dependency})
#    else()
#        get_property(scmPath GLOBAL PROPERTY New_${dependency}_ScmPath)
#        get_property(scmType GLOBAL PROPERTY New_${dependency}_ScmType)
#        _fillNewDependecyFromScm(${dependency} ${scmType} ${scmPath})
#    endif()
#    
    # remember its dependant and overall dependants
#    set_property(GLOBAL PROPERTY New_${dependency}_Dependants ${dependant})
#    get_property(dependencyDependants GLOBAL PROPERTY New_${dependant}_Dependants)    
#    set_property(GLOBAL PROPERTY New_${dependency}_OverallDependants ${dependant} ${dependencyDependants})
#    
    # store dependency name in list for further check
#    set_property(GLOBAL APPEND PROPERTY New_OverallDependenciesNames ${dependencyName})
    # for each name store more different svn packages if any
#    set_property(GLOBAL APPEND PROPERTY New_${dependencyName}_Packages ${dependency})
#    
    # export dependencies of dependency via recursion
#    get_property(dependencyDependencies GLOBAL PROPERTY New_${dependency}_DependenciesDescription)    
#    _getDependenciesInfo("${dependency}" "${dependencyDependencies}")
#endfunction(_getDependencyInfo)
#
#function(_fillNewDependecyFromStoredOne dependency)
#    set(depName ${${dependency}_Name})
#    
#    if(EXISTS ${DEP_INFO_FILE} AND ${DEP_INFO_FILE} IS_NEWER_THAN ${DEP_SOURCES_PATH}/${depName}/Properties.cmake)
#        set_property(GLOBAL PROPERTY New_${dependency}_Name ${${depName}_Name})
#        set_property(GLOBAL PROPERTY New_${dependency}_Type ${${depName}_Type})
#        set_property(GLOBAL PROPERTY New_${dependency}_Version ${${depName}_Version})
#        set_property(GLOBAL PROPERTY New_${dependency}_ScmPath ${${depName}_ScmPath})
#        set_property(GLOBAL PROPERTY New_${dependency}_ScmType ${${depName}_ScmType})
#        set_property(GLOBAL PROPERTY New_${dependency}_DependenciesDescription ${${depName}_DependenciesDescription})
#        set_property(GLOBAL PROPERTY New_${dependency}_Dependencies ${${depName}_Dependencies})
#    else()
#        set(DEPENDENCIES "")
#        set(NAME "")
#        set(TYPE "")
#        set(VERSION_MAJOR "")
#        set(VERSION_MINOR "")
#        set(VERSION_PATCH "")
#        include(${DEP_SOURCES_PATH}/${depName}/Properties.cmake)
#    
#        ParseDependencies("${DEPENDENCIES}" ddi "exp")
#            
        # store exported info
#        set_property(GLOBAL PROPERTY New_${dependency}_Name "${NAME}")
#        set_property(GLOBAL PROPERTY New_${dependency}_Type "${TYPE}")
#        set_property(GLOBAL PROPERTY New_${dependency}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
#        set_property(GLOBAL PROPERTY New_${dependency}_ScmPath "${exp_${dependency}_ScmPath}")
#        set_property(GLOBAL PROPERTY New_${dependency}_ScmType "${exp_${dependency}_ScmType}")
#        set_property(GLOBAL PROPERTY New_${dependency}_DependenciesDescription ${DEPENDENCIES})
#        set_property(GLOBAL PROPERTY New_${dependency}_Dependencies ${ddi})
#    endif()
#endfunction(_fillNewDependecyFromStoredOne)
#
#function(_fillNewDependecyFromScm dependency scmType scmPath)
    # log
#    message(STATUS "Exporting Properties for dependency ${dependency}")
    # export dependecy property file
#    set(localFile "${DEP_SRC_INFO_PATH}/properties.cmake")
#    set(scmFile "${scmPath}/Properties.cmake")
#    file(REMOVE ${localFile})
#    _exportFromScm(${scmType} ${scmFile} ${localFile})
    # include properties file of dependecy
#    set(DEPENDENCIES "")
#    set(NAME "")
#    set(TYPE "")
#    set(VERSION_MAJOR "")
#    set(VERSION_MINOR "")
#    set(VERSION_PATCH "")
#    include(${localFile})
#
#    ParseDependencies("${DEPENDENCIES}" ddi "")
#        
    # store exported info
#    set_property(GLOBAL PROPERTY New_${dependency}_Name "${NAME}")
#    set_property(GLOBAL PROPERTY New_${dependency}_Type "${TYPE}")
#    set_property(GLOBAL PROPERTY New_${dependency}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
#    set_property(GLOBAL PROPERTY New_${dependency}_ScmPath "${scmPath}")
#    set_property(GLOBAL PROPERTY New_${dependency}_ScmType "${scmType}")
#    set_property(GLOBAL PROPERTY New_${dependency}_DependenciesDescription ${DEPENDENCIES})
#    set_property(GLOBAL PROPERTY New_${dependency}_Dependencies ${ddi})
#    file(REMOVE ${localFile})
#endfunction(_fillNewDependecyFromScm)
#
#function(_exportFromScm scmType scmFile localFile)
#    if("svn" STREQUAL "${scmType}")
#        _exportFromSvn(${scmFile} ${localFile})
#    else()
#        _exit("Scm \"${scmType}\" is NOT supported")
#    endif()
#endfunction()
#
#function(_checkoutFromScm scmType scmFile localFile)
#    if("svn" STREQUAL "${scmType}")
#        _checkoutFromSvn(${scmFile} ${localFile})
#    else()
#        _exit("Scm \"${scmType}\" is NOT supported")
#    endif()
#endfunction()
#
#
#function(_exportFromSvn svnFile localFile)
    # export
#    execute_process(COMMAND svn export ${svnFile} ${localFile}
#        RESULT_VARIABLE svnResult
#        OUTPUT_VARIABLE out
#        ERROR_VARIABLE out)
#    if(${svnResult} GREATER 0)
#        _exit("SVN Export Fails:\n${out}")
#    endif()
#endfunction(_exportFromSvn)
#
#function(_checkoutFromSvn svnFile localFile)
    # export
#    execute_process(COMMAND svn checkout ${svnFile} ${localFile}
#        RESULT_VARIABLE svnResult
#        OUTPUT_VARIABLE out
#        ERROR_VARIABLE out)
#    if(${svnResult} GREATER 0)
#        _exit("SVN checkout Fails:\n${out}")
#    endif()
#endfunction()
#
#
#
#    _areOwnDependenciesChanged
#        Return yes when own dependencies are changed 
#
#
#function(_areOwnDependenciesChanged dependencies areChanged areExternalFlagsChanged)
#    ParseDependencies("${dependencies}" actualOwnDependencies aod)
#    
#    set(oldOwnDependencies "")
#    foreach(oldDep ${${NAME}_Dependencies})
#        list(APPEND oldOwnDependencies ${${oldDep}_Id}) 
#    endforeach()
#    set(newOwnDependencies "${actualOwnDependencies}")
#            
#    list(SORT oldOwnDependencies)
#    list(SORT newOwnDependencies)
#    
#    if ("${oldOwnDependencies}" STREQUAL "${newOwnDependencies}")
#        set(${areChanged} "no" PARENT_SCOPE)
#        
        # dependencies are NOT changed, check if External flag is changed
#        set(${areExternalFlagsChanged} "no" PARENT_SCOPE)
#        foreach(ownDep ${oldOwnDependencies})
#            if (NOT "${${ownDep}_IsExternal}" STREQUAL "${aod_${ownDep}_IsExternal}")
                # external flag is changed, updtae in cache
#                set(${areExternalFlagsChanged} "yes" PARENT_SCOPE)
#                break()
#            endif()
#        endforeach()     
#    else()
#        set(${areChanged} "yes" PARENT_SCOPE)
#        set(${areExternalFlagsChanged} "yes" PARENT_SCOPE)
#    endif()
#endfunction()
#
#
#
#    _printDependencies
#        print all dependencies relations as UML component diagram 
#
#
#function(_printDependencies projectName)
#    message(STATUS "Generating Dependecies picture.")
#    
#    set(plantumlContent "@startuml\n")
#    
#    list(APPEND plantumlContent "skinparam component {\n")
#    list(APPEND plantumlContent "BackgroundColor<<Container>> LightGreen\n")
#    list(APPEND plantumlContent "BackgroundColor<<External Container>> LightGreen\n")
#    list(APPEND plantumlContent "BorderColor<<External Container>> Black\n")
#    list(APPEND plantumlContent "BackgroundColor<<Executable>> LightBlue\n")
#    list(APPEND plantumlContent "BackgroundColor<<External Executable>> LightBlue\n")
#    list(APPEND plantumlContent "BorderColor<<External Executable>> Black\n")
#    list(APPEND plantumlContent "BorderColor<<External>> Black\n")
#    list(APPEND plantumlContent "}\n")
#    
#    set(stereotypedPackages "")
#    foreach(dependency ${New_OverallDependencies})
#        if ("Container" STREQUAL "${New_${dependency}_Type}")
#            list(APPEND stereotypedPackages ${dependency})
#        elseif ("Executable" STREQUAL "${New_${dependency}_Type}")
#            list(APPEND stereotypedPackages ${dependency})
#        elseif (${New_${dependency}_IsExternal})
#            list(APPEND stereotypedPackages ${dependency})
#        endif()        
#    endforeach()
#    
    # create packages with version mismatch
#    foreach(name ${New_OverallDependenciesNames})
#        list(LENGTH New_${name}_Packages packagesCount)
#        if(${packagesCount} GREATER 1)
#            list(APPEND plantumlContent "package \"${name}\" {\n")
#            list(APPEND plantumlContent "note \"<img:${CMAKE_ROOT}/Modules/SBE/tools/stop.png> <b><color:Red><size:16>Version mismatch</size></color></b>\" as N${name}\n")
#            foreach(package ${New_${name}_Packages})
                # calculate stereotypes
#                set(stereotype "")
#                
#                if (${New_${package}_IsExternal})
#                    set(stereotype "External")
#                endif()
#                
#                if ("Container" STREQUAL "${New_${package}_Type}")
#                    if("" STREQUAL "${stereotype}")
#                        set(stereotype "Container")
#                    else()
#                        set(stereotype "${stereotype} Container")
#                    endif()
#                elseif ("Executable" STREQUAL "${New_${package}_Type}")
#                    if("" STREQUAL "${stereotype}")
#                        set(stereotype "Executable")
#                    else()
#                        set(stereotype "${stereotype} Executable")
#                    endif()
#                endif()
#                
#                if("Development" STREQUAL "${SBE_MODE}" OR "RelaxedDevelopment" STREQUAL "${SBE_MODE}")
#                    set(versionText "")
#                else()
#                    set(versionText "\\n${New_${package}_Version}")
#                endif()
#                if("" STREQUAL "${stereotype}")
#                    list(APPEND plantumlContent "[${New_${package}_Name}${versionText}] .. N${name}\n")
#                else()
#                    list(APPEND plantumlContent "[${New_${package}_Name}${versionText}] <<${stereotype}>> .. N${name}\n")
#                    list(REMOVE_ITEM stereotypedPackages ${package})                    
#                endif()
#            endforeach()
#
#            list(APPEND plantumlContent "}\n")
#        endif()
#    endforeach()
#    
    # create packages with stereotypes that have no version mismatch
#    foreach(dependency ${stereotypedPackages})
        # calculate stereotypes
#        set(stereotype "")
#        if (${New_${dependency}_IsExternal})
#            set(stereotype "External")
#        endif()
#        
#        if ("Container" STREQUAL "${New_${dependency}_Type}")
#            if("" STREQUAL "${stereotype}")
#                set(stereotype "Container")
#            else()
#                set(stereotype "${stereotype} Container")
#            endif()
#        elseif ("Executable" STREQUAL "${New_${dependency}_Type}")
#            if("" STREQUAL "${stereotype}")
#                set(stereotype "Executable")
#            else()
#                set(stereotype "${stereotype} Executable")
#            endif()
#        endif()
#
#        if("Development" STREQUAL "${SBE_MODE}" OR "RelaxedDevelopment" STREQUAL "${SBE_MODE}")
#            set(versionText "")
#        else()
#            set(versionText "\\n${New_${dependency}_Version}")
#        endif()
#        list(APPEND plantumlContent "[${New_${dependency}_Name}${versionText}] <<${stereotype}>>\n")
#    endforeach()
#    
#    foreach(dependency ${New_${projectName}_Dependencies})
#        if("Development" STREQUAL "${SBE_MODE}" OR "RelaxedDevelopment" STREQUAL "${SBE_MODE}")
#            set(versionText "")
#        else()
#            set(versionText "\\n${New_${dependency}_Version}")
#        endif()
#        
#        list(APPEND plantumlContent "[${projectName}]-->[${New_${dependency}_Name}${versionText}]\n")
#    endforeach()
#    
#    foreach(dependency ${New_OverallDependencies})
#        foreach(dependencyOfDependecy ${New_${dependency}_Dependencies})
#            if("Development" STREQUAL "${SBE_MODE}" OR "RelaxedDevelopment" STREQUAL "${SBE_MODE}")
#                set(versionText "")
#                set(versionTextd "")
#            else()
#                set(versionText "\\n${New_${dependency}_Version}")
#                set(versionTextd "\\n${New_${dependencyOfDependecy}_Version}")
#            endif()
#            if ("Container" STREQUAL "${New_${dependency}_Type}")
#                list(APPEND plantumlContent "[${New_${dependency}_Name}${versionText}]-->[${New_${dependencyOfDependecy}_Name}${versionTextd}] : contains\n")
#            else()
#                list(APPEND plantumlContent "[${New_${dependency}_Name}${versionText}]-->[${New_${dependencyOfDependecy}_Name}${versionTextd}]\n")
#            endif()                
#        endforeach()
#    endforeach()
#    
#    list(APPEND plantumlContent "@enduml\n")
#    
#    file(WRITE ${DEP_SRC_INFO_PATH}/DependecyGraph.txt ${plantumlContent})
#    
#    execute_process(
#        COMMAND plantuml ${DEP_SRC_INFO_PATH}/DependecyGraph.txt
#        RESULT_VARIABLE result)
#    
#    file(REMOVE ${DEP_SRC_INFO_PATH}/DependecyGraph.txt)
#endfunction (_printDependencies)
#
#
#
#    _checkDependenciesVersionsAndStopOnError
#        checks if all dependencies are used in same version by its dependants 
#
#    
#function(_checkDependenciesVersionsAndStopOnError)
#    set(report "")
#    
    # check if all dependencies are used in same version
#    foreach(name ${New_OverallDependenciesNames})
#        list(LENGTH New_${name}_Packages packagesCount)
#        if(${packagesCount} GREATER 1)
#            set(report "${report}\nDependency ${name} is inconsistent.")
#            foreach(package ${New_${name}_Packages})
#                set(report "${report}\n    In version ${package} is used by")
#                foreach(dependant ${New_${package}_Dependants})
#                    set(report "${report}\n        ${dependant}")
#                endforeach()
#            endforeach()
#        endif()
#    endforeach()
#    
#    if(NOT "${report}" STREQUAL "")
#        _exit("Dependencies error:\n${report}")
#    endif()
#endfunction(_checkDependenciesVersionsAndStopOnError)
#
#
#
#    _orderDependeniesAndCheckLoops
#        order dependencies to installation order 
#
#
#function(_orderDependeniesAndCheckLoops isLoop)
    # Expose properties as variables to acces them easily.
    # Exposed properites will be modified later in recursion. Originals have to stay untached.
#    _exposePropertiesAsVariables("Ord")
#    
    # define variables modifed in recursion in this scope
#    set(containsLoops "no")
#        
    # order dependencies In recursion
#    _orderDependenciesInRecursion(0)
#    
    # exposes loop flag
#    get_property(containsLoops GLOBAL PROPERTY DependenciesLoop)
#    set(${isLoop} ${containsLoops} PARENT_SCOPE)
#
#    if (NOT containsLoops)
#        get_property(orderedDependencies GLOBAL PROPERTY New_OrderedOverallDependencies)
        # propagate order to properties
#        set_property(GLOBAL PROPERTY New_OverallDependencies ${orderedDependencies})
#        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_OverallDependencies ${orderedDependencies})
        # order dependencies in each dependency
#        foreach(dep ${orderedDependencies})
#            if (NOT "" STREQUAL "${Ord_${dep}_OverallDependencies}") 
#                set(tmp ${orderedDependencies})
#                list(REMOVE_ITEM tmp ${Ord_${dep}_OverallDependencies})
#                set(orderedDependencyDependencies ${orderedDependencies})
#                list(REMOVE_ITEM orderedDependencyDependencies ${tmp})
#                set_property(GLOBAL PROPERTY New_${dep}_OverallDependencies ${orderedDependencyDependencies})
#            endif()
#        endforeach()
#    endif()
#endfunction()
#
#function(_orderDependenciesInRecursion recursionDepth)
#    set(dependenciesWithoutDependencies "")
#    foreach(dep ${Ord_OverallDependencies})
#        list(LENGTH Ord_${dep}_Dependencies dependencyDependenciesNumber)
#        if (0 EQUAL ${dependencyDependenciesNumber})
#            list(APPEND dependenciesWithoutDependencies ${dep})
#        endif()
#    endforeach()
#    
    # check loop
#    if ("" STREQUAL "${dependenciesWithoutDependencies}" AND NOT "" STREQUAL "${Ord_OverallDependencies}")
#        set_property(GLOBAL PROPERTY DependenciesLoop "yes")
#        return()
#    endif()
#    
#    list(REMOVE_ITEM Ord_OverallDependencies ${dependenciesWithoutDependencies})
#    set_property(GLOBAL APPEND PROPERTY New_OrderedOverallDependencies ${dependenciesWithoutDependencies})
#    set_property(GLOBAL APPEND PROPERTY New_OrderedOverallDependenciesGroups ${recursionDepth})
#    set_property(GLOBAL PROPERTY New_ParallelBuildGroup_${recursionDepth} ${dependenciesWithoutDependencies})
#    
    # all dependencies are sorted?
#    if("" STREQUAL "${Ord_OverallDependencies}")
#        return()
#    endif()
#    
#    foreach(dep ${Ord_OverallDependencies})
#        list(REMOVE_ITEM Ord_${dep}_Dependencies ${dependenciesWithoutDependencies})
#    endforeach()
#    
    # continue with recursion to sort all dependencies
#    math(EXPR recursionDepth "${recursionDepth} + 1")
#    _orderDependenciesInRecursion(${recursionDepth})
#endfunction()
#
#
#
#    _createInfoAboutExternalFlag
#        claculates external dependencies
#            * dependency is external if is flaged as external in own dependencies
#
#
#function (_createInfoAboutExternalFlag)
#    set(externalDependencies "")
#    
#    get_property(New_OverallDependencies GLOBAL PROPERTY New_${MAIN_DEPENDANT}_OverallDependencies)
#    if(DEFINED New_OverallDependencies)
#        list(REMOVE_DUPLICATES New_OverallDependencies)
#    endif()
#    
#    foreach(dep ${New_OverallDependencies})
#        get_property(isExternal GLOBAL PROPERTY New_${dep}_IsExternal)
#        if(isExternal)
#            list(APPEND externalDependencies ${dep})
#            get_property(depDependencies GLOBAL PROPERTY New_${dep}_OverallDependencies)
#            foreach(depDependency ${depDependencies})
#                set_property(GLOBAL PROPERTY New_${depDependency}_IsExternal "yes")
#                list(APPEND externalDependencies ${depDependency})
#            endforeach()
#        endif()
#    endforeach()
#    
#    list(REMOVE_DUPLICATES externalDependencies)
#        
#    set_property(GLOBAL PROPERTY New_ExternalDependencies ${externalDependencies})
#endfunction ()
#
#
#
#
#    _removeUnusedDependencies
#        removes dependency 
#
#
#function(_removeUnusedDependencies)
#    if(NOT DEFINED OverallDependencies)
#        return()
#    endif()
#    
#    set(dependenciesToRemove ${OverallDependencies})
#    
#    foreach(newDep ${New_OverallDependencies})
#        list(REMOVE_ITEM dependenciesToRemove ${New_${newDep}_Name})
#    endforeach()
#    
#    foreach(dependency ${dependenciesToRemove})
#        message(STATUS "Removing unused dependency sources ${dependency}")
#        
#        file(REMOVE_RECURSE ${DEP_SOURCES_PATH}/${dependency}})
#    endforeach()
#
#        if(EXISTS ${COV_DIR_DATA})
#            execute_process(
#                COMMAND cov-manage-emit --verbose 0 --dir ${COV_DIR_DATA} --tu-pattern "file('${${dependency}_SourcePath}/*')" delete
#                COMMAND ${SED_TOOL} -u -e "s/.*/    &/"
#                ERROR_VARIABLE err)
#        endif()
#    
#endfunction(_removeUnusedDependencies)
#
#
#
#    _exportRequiredDependencies
#        export dependencies sources 
#
#
#function(_exportRequiredDependencies)
#    foreach(dependecy ${New_OverallDependencies})
#        if(NOT EXISTS ${DEP_SOURCES_PATH}/${New_${dependecy}_Name})
            # export dependecy from svn 
#            message(STATUS "Exporting Sources for dependency ${dependecy}")
#            _checkoutFromScm(${New_${dependecy}_ScmType} ${New_${dependecy}_ScmPath} ${DEP_SOURCES_PATH}/${New_${dependecy}_Name})
#        endif()
#    endforeach()
#endfunction(_exportRequiredDependencies)
#
#function(_exit reason)
#    _cleanup()
#    message(STATUS "${reason}")
#    message(FATAL_ERROR "exit")
#endfunction(_exit)
#
#function(_cleanup)
#    unset(isInfoFileIncluded)
#endfunction(_cleanup)
#
#ExportProperties("${DEPENDENCIES}")
  
