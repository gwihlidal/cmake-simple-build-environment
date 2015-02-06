cmake_minimum_required(VERSION 2.8)

if (DEFINED PackageExporterGuard)
    return()
endif()

set(PackageExporterGuard yes)

include(SBE/helpers/ContextParser)
include(SBE/helpers/PropertiesParser)
include(SBE/helpers/SvnHelpers)
include(SBE/helpers/ArgumentParser)


# It exports ovearall package dependencies
function(sbeExportPackageDependencies name propertyFile)
    message(STATUS "Checking exported Dependencies")
    # When Context file or properties file is modified recheck all dependencies
    getContextTimestamp(actualContextTimestamp)
    sbeGetPackagePropertiesTimestamp(${name} actualPropertiesTimestamp)
    
    set(IsExportNecessary no)
    
    if("${actualContextTimestamp}" STREQUAL "${Export_ContextTimestamp}" AND "${actualPropertiesTimestamp}" STREQUAL "${Export_PropertiesTimestamp}")
        foreach(exportedDependency ${OverallDependencies})
            sbeGetPackageLocalPath(${exportedDependency} lp)
            if(NOT EXISTS ${lp})
                set(IsExportNecessary yes)
                break()    
            endif()
            sbeGetPackagePropertiesTimestamp(${exportedDependency} ts)
            if("${ts}" STREQUAL "${${exportedDependency}_PropertiesTimestamp}")
                set_property(GLOBAL APPEND PROPERTY Export_OverallDependencies ${exportedDependency})
                set_property(GLOBAL PROPERTY Export_${exportedDependency}_DirectDependencies ${${exportedDependency}_DirectDependencies})
                set_property(GLOBAL PROPERTY Export_${exportedDependency}_PropertiesTimestamp ${${exportedDependency}_PropertiesTimestamp})
                set_property(GLOBAL PROPERTY Export_${exportedDependency}_IsProvided ${${exportedDependency}_IsProvided})
                set_property(GLOBAL PROPERTY Export_${exportedDependency}_IsPinned ${${exportedDependency}_IsPinned})
            else()
                set(IsExportNecessary yes)
                break()
            endif()
        endforeach()
    else()
        set(IsExportNecessary yes)
    endif()
    
    if(IsExportNecessary)
        set_property(GLOBAL PROPERTY Export_OverallDependencies )
        
        exportDependencies(${name} ${propertyFile})

        # set cached variables for usage in next run    
        set(Export_ContextTimestamp ${actualContextTimestamp} CACHE "" INTERNAL FORCE)
        set(Export_PropertiesTimestamp ${actualPropertiesTimestamp} CACHE "" INTERNAL FORCE)
        
        publishDependenciesProperties()        
    endif()
endfunction()

# It exports given package and its dependencies
# It is used in scripts 
function(sbeExportPackage name)
    message(STATUS "Checking exported Dependencies")
    exportDependency(${name})
    publishDependenciesProperties()
endfunction()

# it walks through exported dependencies and get its properties
# when package is not found then it sends error
# it is used in scripts
function(sbeGetPackageProperties name)
    getDependency(${name})
    publishDependenciesProperties()
endfunction()

function(publishDependenciesProperties)
    get_property(UnorderedOverallDependencies GLOBAL PROPERTY Export_OverallDependencies)

    foreach(exportedDependency ${UnorderedOverallDependencies})
        get_property(deps GLOBAL PROPERTY Export_${exportedDependency}_DirectDependencies)
        set(${exportedDependency}_DirectDependencies ${deps} CACHE "" INTERNAL FORCE)
        get_property(v GLOBAL PROPERTY Export_${exportedDependency}_VersionText)
        set(${exportedDependency}_VersionText ${v} CACHE "" INTERNAL FORCE)        
        get_property(ts GLOBAL PROPERTY Export_${exportedDependency}_PropertiesTimestamp)
        set(${exportedDependency}_PropertiesTimestamp ${ts} CACHE "" INTERNAL FORCE)
        get_property(p GLOBAL PROPERTY Export_${exportedDependency}_IsProvided)
        set(${exportedDependency}_IsProvided ${p} CACHE "" INTERNAL FORCE)
        get_property(pi GLOBAL PROPERTY Export_${exportedDependency}_IsPinned)
        set(${exportedDependency}_IsPinned ${pi} CACHE "" INTERNAL FORCE)         
    endforeach()
    
    OrderDependecies("${UnorderedOverallDependencies}")
    get_property(Export_OrderedOverallDependencies GLOBAL PROPERTY Export_OrderedOverallDependencies)
    set(OverallDependencies ${Export_OrderedOverallDependencies} CACHE "" INTERNAL FORCE)
endfunction()

# it exports given dependency and its all dependencies 
function(exportDependencies dependency propertyFile)
    
    storeDependencyProperties(${dependency} ${propertyFile} "Properties file must exist to export dependencies.")

    # variable directDependencies is set in macro storeDependencyProperties
    foreach(dd ${directDependencies})
        exportDependency(${dd})
    endforeach()
endfunction()

# function read dpendency properties
function(getDependencies dependency propertyFile)
    
    storeDependencyProperties(${dependency} ${propertyFile} "Properties file must exist to export dependencies.")

    # variable directDependencies is set in macro storeDependencyProperties
    foreach(dd ${directDependencies})
        getDependency(${dd})
    endforeach()
endfunction()

macro(storeDependencyProperties dependency propertyFile errorTextWhenPropertyFileIsMissing)
    # properties file must exist
    sbeReportErrorWhenFileDoesntExists(propertyFile "${errorTextWhenPropertyFileIsMissing}")
    
    unset(Name)
    unset(Dependencies)
    unset(DateVersion)
    unset(SemanticVersion)
    include(${propertyFile})
    
    # if Name is given as argument then it has to be same is in ContextFile
    if(NOT "${dependency}" STREQUAL "${Name}")
        message(FATAL_ERROR
            "Name in Properties file [${Name}] is different as in Context [${dependency}]." 
        )        
    endif()
    
    sbeGetDependenciesNames(directDependencies)
    set_property(GLOBAL PROPERTY Export_${Name}_DirectDependencies ${directDependencies})
    set_property(GLOBAL PROPERTY Export_${Name}_VersionText "${DateVersion}${SemanticVersion}")
    
    file(TIMESTAMP "${propertyFile}" ts "%Y-%m-%dT%H:%M:%S")
    set_property(GLOBAL PROPERTY Export_${Name}_PropertiesTimestamp ${ts})    
endmacro()

# it exports package with given name and all its dependencies
function(exportDependency name)
    storeDependencyContextProperties(${name})

    # Variables packagePath,packageUrl is set in macro storeDependencyContextProperties
    sbeGetPackageLocationType(${name} locationType)
    
    if("repository" STREQUAL "${locationType}")     
        if(NOT EXISTS ${packagePath})
            svnCheckout(LocalDirectory ${packagePath} Url ${packageUrl}
                StartMessage "   Checking out ${name} ${packageUrl}"
                StopOnErrorWithMessage "Could NOT checkout ${packageUrl} for ${name}")
        else()
            svnGetRepositoryForLocalDirectory(${packagePath} url)
            
            if(DEFINED url)
                svnIsUrlTag(${url} isTag)
                
                if(isTag)
                    if(NOT "${url}" STREQUAL "${packageUrl}")
                        svnSwitch(LocalDirectory ${packagePath} Url ${packageUrl}
                            StartMessage "   Switching ${name} ${packageUrl}"
                            StopOnErrorWithMessage "Could NOT switch to ${packageUrl} for ${name}" 
                        )
                    endif()
                else()
                    message(STATUS "   Ignoring ${name} due to trunk")
                endif()
            else()
                    message(STATUS "   Ignoring ${name} due to not in repository")
            endif()
        endif()
    elseif("local" STREQUAL "${locationType}")
        if(NOT EXISTS ${packagePath})
            message(FATAL_ERROR "Local dependency ${name} could not be found")
        else()
            message(STATUS "   Ignoring ${name} due to local")
        endif()
    else()
        message(FATAL_ERROR "Not supported location type for ${name}")
    endif()
    
    exportDependencies(${name} ${packagePath}/Properties.cmake)    
endfunction()

# function get dependency properties
function(getDependency name)
    storeDependencyContextProperties(${name})

    # Variables packagePath is set in macro storeDependencyContextProperties
    if(NOT EXISTS ${packagePath})
        message(FATAL_ERROR "Dependency ${name} is not exported.")                    
    endif()
    
    getDependencies(${name} ${packagePath}/Properties.cmake)    
endfunction()

macro(storeDependencyContextProperties name)
    sbeIsDependencyInContext(${name} isInContext)
    
    if(NOT isInContext)
        message(FATAL_ERROR "Dependency ${name} is not in context file")    
    endif()
    
    # do NOT process already processed dependency
    get_property(Export_OverallDependencies GLOBAL PROPERTY Export_OverallDependencies)
    if(DEFINED Export_OverallDependencies)
        list(FIND Export_OverallDependencies ${name} found)
        if(${found} GREATER 0)
            return()
        endif()
    endif()
    
    set_property(GLOBAL APPEND PROPERTY Export_OverallDependencies ${name})
    
    # context file must exist
    sbeReportErrorWhenContextFileIsNotLoaded()
    
    sbeGetPackageLocalPath(${name} packagePath)
    sbeGetPackageUrl(${name} packageUrl)
    sbeGetProvidedFlag(${name} isProvided)
    set_property(GLOBAL PROPERTY Export_${name}_IsProvided ${isProvided})
    sbeGetPinnedFlag(${name} isPinned)
    set_property(GLOBAL PROPERTY Export_${name}_IsPinned ${isPinned})
endmacro()

function(OrderDependecies dependencies)
    if("" STREQUAL "${dependencies}")
        return()
    endif()
    
    set(isLoop yes)
    get_property(Export_OrderedOverallDependencies GLOBAL PROPERTY Export_OrderedOverallDependencies)
    
    foreach(dependency ${dependencies})
        if("" STREQUAL "${${dependency}_DirectDependencies}")
            set(isLoop no)
            set_property(GLOBAL APPEND PROPERTY Export_OrderedOverallDependencies ${dependency})
        elseif(NOT "" STREQUAL "${Export_OrderedOverallDependencies}")
            set(directDependencies ${${dependency}_DirectDependencies})
            list(REMOVE_ITEM directDependencies ${Export_OrderedOverallDependencies})
            list(LENGTH directDependencies directDependenciesNumber)
            if (${directDependenciesNumber} EQUAL 0)
                set(isLoop no)
                set_property(GLOBAL APPEND PROPERTY Export_OrderedOverallDependencies ${dependency})
            endif()
       endif()
    endforeach()
    
    if(isLoop)
        message(FATAL_ERROR "Loop detected in packages ${dependencies}")
    endif()
  
    set(dependenciesLeft ${dependencies})
    get_property(Export_OrderedOverallDependencies GLOBAL PROPERTY Export_OrderedOverallDependencies)
    list(REMOVE_ITEM dependenciesLeft ${Export_OrderedOverallDependencies})
    OrderDependecies("${dependenciesLeft}")
endfunction()


  
