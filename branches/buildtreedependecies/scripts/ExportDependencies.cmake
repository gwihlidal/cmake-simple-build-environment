cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED SBE_MAIN_DEPENDANT_SOURCE_DIR)
    message(FATAL_ERROR "Path to Properties.txt has to be defined as SBE_MAIN_DEPENDANT_SOURCE_DIR=path.")
endif()

if(NOT DEFINED SBE_MAIN_DEPENDANT)
    include(${SBE_MAIN_DEPENDANT_SOURCE_DIR}/Properties.cmake)
    set(MAIN_DEPENDANT ${NAME})
else()
    set(MAIN_DEPENDANT ${SBE_MAIN_DEPENDANT})
endif()

# in case of stand alone script
if(NOT DEFINED PROJECT_SOURCE_DIR)
    set(PROJECT_SOURCE_DIR ${SBE_MAIN_DEPENDANT_SOURCE_DIR})
endif()

# set export directories
set(DEP_SOURCES_PATH "${SBE_MAIN_DEPENDANT_SOURCE_DIR}/dependencies/sources")
set(DEP_SRC_INFO_PATH "${SBE_MAIN_DEPENDANT_SOURCE_DIR}/dependencies/info")
set(DEP_INFO_FILE "${DEP_SRC_INFO_PATH}/info.cmake")

# find all necessary tools
find_package(Subversion QUIET)
if(NOT Subversion_SVN_EXECUTABLE)
    message(FATAL_ERROR "error: could not find svn.")
endif()

include(SBE/helpers/DependenciesParser)

# create export directories    
if(NOT EXISTS "${DEP_SRC_INFO_PATH}")
    file(MAKE_DIRECTORY "${DEP_SRC_INFO_PATH}")
endif()

if(NOT EXISTS "${DEP_SOURCES_PATH}")
    file(MAKE_DIRECTORY "${DEP_SOURCES_PATH}")
endif()

include(${DEP_INFO_FILE} OPTIONAL)

# export all properties files    
function(ExportProperties dependencies)
    if(EXISTS ${DEP_INFO_FILE} AND ${DEP_INFO_FILE} IS_NEWER_THAN ${PROJECT_SOURCE_DIR}/Properties.cmake)
        return()
    endif()

    if ("${MAIN_DEPENDANT}" STREQUAL "${NAME}")
        set_property(GLOBAL PROPERTY New_${NAME}_Name "${NAME}")
        set_property(GLOBAL PROPERTY New_${NAME}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
        set_property(GLOBAL PROPERTY New_${NAME}_Type "${TYPE}")
        set_property(GLOBAL PROPERTY New_${NAME}_ScmPath "")
        set_property(GLOBAL PROPERTY New_${NAME}_ScmType "")
        set_property(GLOBAL PROPERTY New_${NAME}_IsExternal "no")
        set_property(GLOBAL PROPERTY New_${NAME}_DependenciesDescription ${dependencies})
        set(${NAME}_Name "${NAME}")
        set(${NAME}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
        set(${NAME}_Type "${TYPE}")
        set(${NAME}_ScmPath "")
        set(${NAME}_ScmType "")
        set(${NAME}_IsExternal "no")
        set(${NAME}_DependenciesDescription ${dependencies})
    else()
        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_Name "${${MAIN_DEPENDANT}_Name}")
        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_Version "${${MAIN_DEPENDANT}_Version}")
        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_Type "${${MAIN_DEPENDANT}_Type}")
        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_ScmPath "")
        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_ScmType "")
        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_IsExternal "no")
        set_property(GLOBAL PROPERTY New_${MAIN_DEPENDANT}_DependenciesDescription ${${MAIN_DEPENDANT}_DependenciesDescription})
    endif()
            
    _areOwnDependenciesChanged("${dependencies}" areChanged areExternalFlagsChanged)
    
    if(NOT areChanged)
        if(NOT areExternalFlagsChanged)
            # nothing to do
            _cleanup()
            return()
        endif()
        
        # setup new dependencies data
        _getDependenciesInfo(${MAIN_DEPENDANT} "${${MAIN_DEPENDANT}_DependenciesDescription}")

        _createInfoAboutExternalFlag()
        
        _publishPropertiesAsVariable()
        
        # generate picture
        _printDependencies(${MAIN_DEPENDANT})
        
        _orderDependenies()
        
        _storeNewInfoFile()
        
        # only picture is chaged, nothing else has to be done
        _cleanup()
        return()
    endif()
    
    _getDependenciesInfo(${MAIN_DEPENDANT} "${${MAIN_DEPENDANT}_DependenciesDescription}")

    _createInfoAboutExternalFlag()
    
    _publishPropertiesAsVariable()
    
    _printDependencies(${MAIN_DEPENDANT})
        
    _checkDependenciesVersionsAndStopOnError()

    _checkDependenciesLoopsAndStopOnError()
    
    _orderDependenies()
    
    _removeUnusedDependencies()
    
    _exportRequiredDependencies()

    _storeNewInfoFile()
        
    _cleanup()
endfunction(ExportProperties)

macro(_publishPropertiesAsVariable)
    # properties to variable
    
    get_property(New_OverallDependencies GLOBAL PROPERTY New_${MAIN_DEPENDANT}_OverallDependencies)
    if(DEFINED New_OverallDependencies)
        list(REMOVE_DUPLICATES New_OverallDependencies)
    endif()
    
    set(New_MaximumDependenciesLength 0)
    
    foreach(dep ${New_OverallDependencies})
        _publishDependencyPropertiesAsVariable(${dep})
        
        if (${New_${dep}_DependenciesLength} GREATER ${New_MaximumDependenciesLength})
            set(New_MaximumDependenciesLength ${New_${dep}_DependenciesLength})
        endif()
    endforeach()
    
    _publishDependencyPropertiesAsVariable(${MAIN_DEPENDANT})
            
    get_property(New_OverallDependenciesNames GLOBAL PROPERTY New_OverallDependenciesNames)
    if(DEFINED New_OverallDependenciesNames)
        list(REMOVE_DUPLICATES New_OverallDependenciesNames)
    endif()
    
    foreach(dep ${New_OverallDependenciesNames})
        get_property(New_${dep}_Packages GLOBAL PROPERTY New_${dep}_Packages)
    endforeach()
   
    get_property(New_ExternalDependencies GLOBAL PROPERTY New_ExternalDependencies)
    if(DEFINED New_ExternalDependencies)
        list(REMOVE_DUPLICATES New_ExternalDependencies)
    endif()
endmacro()

macro(_publishDependencyPropertiesAsVariable dep)
    get_property(New_${dep}_Dependants GLOBAL PROPERTY New_${dep}_Dependants)
    if(DEFINED New_${dep}_Dependants)
        list(REMOVE_DUPLICATES New_${dep}_Dependants)
    endif()
    
    get_property(New_${dep}_OverallDependants GLOBAL PROPERTY New_${dep}_OverallDependants)
    if(DEFINED New_${dep}_OverallDependants)
        list(REMOVE_DUPLICATES New_${dep}_OverallDependants)
    endif()
    
    get_property(New_${dep}_Dependencies GLOBAL PROPERTY New_${dep}_Dependencies)
    if(DEFINED New_${dep}_Dependencies)
        list(REMOVE_DUPLICATES New_${dep}_Dependencies)
        list(LENGTH New_${dep}_Dependencies New_${dep}_DependenciesLength)
    else()
        set(New_${dep}_DependenciesLength 0)
    endif()
    
    get_property(New_${dep}_OverallDependencies GLOBAL PROPERTY New_${dep}_OverallDependencies)
    if(DEFINED New_${dep}_OverallDependencies)
        list(REMOVE_DUPLICATES New_${dep}_OverallDependencies)
    endif()

    get_property(New_${dep}_Name GLOBAL PROPERTY New_${dep}_Name)
    get_property(New_${dep}_Type GLOBAL PROPERTY New_${dep}_Type)
    get_property(New_${dep}_Version GLOBAL PROPERTY New_${dep}_Version)
    get_property(New_${dep}_ScmPath GLOBAL PROPERTY New_${dep}_ScmPath)
    get_property(New_${dep}_ScmType GLOBAL PROPERTY New_${dep}_ScmType)
    get_property(New_${dep}_DependenciesDescription GLOBAL PROPERTY New_${dep}_DependenciesDescription)
    get_property(New_${dep}_IsExternal GLOBAL PROPERTY New_${dep}_IsExternal)
endmacro()

function(_storeNewInfoFile)
    set(info "")

#    list(APPEND info "if(DEFINED isInfoFileIncluded)\n")
#    list(APPEND info "   return()\n")
#    list(APPEND info "endif()\n")
#    list(APPEND info "set(isInfoFileIncluded yes)\n")
#    list(APPEND info "\n")
    
    list(APPEND info "set(MAIN_DEPENDANT ${MAIN_DEPENDANT})\n")
    
    set(tmp ${New_OverallDependencies} ${MAIN_DEPENDANT})
    list(REMOVE_DUPLICATES tmp)
    foreach(dependency ${tmp})
        set(dep ${New_${dependency}_Name})
        list(APPEND info "# Begin of info for dependecy ${dep}\n")
        list(APPEND info "set(${dependency}_Name \"${New_${dependency}_Name}\")\n")
        list(APPEND info "set(${dep}_Id \"${dependency}\")\n")
        list(APPEND info "set(${dep}_Name \"${New_${dependency}_Name}\")\n")
        list(APPEND info "set(${dep}_Type \"${New_${dependency}_Type}\")\n")
        list(APPEND info "set(${dep}_Version \"${New_${dependency}_Version}\")\n")
        list(APPEND info "set(${dep}_ScmPath \"${New_${dependency}_ScmPath}\")\n")
        list(APPEND info "set(${dep}_ScmType \"${New_${dependency}_ScmType}\")\n")
        list(APPEND info "set(${dep}_IsExternal \"${New_${dependency}_IsExternal}\")\n")
        list(APPEND info "set(${dep}_DependenciesDescription \"\")\n")
        foreach(dependencyDescriptionItem ${New_${dependency}_DependenciesDescription})
            list(APPEND info "list(APPEND ${dep}_DependenciesDescription \"${dependencyDescriptionItem}\")\n")
        endforeach()
        list(APPEND info "set(${dep}_Dependencies \"\")\n")
        foreach(dependencyId ${New_${dependency}_Dependencies})
            list(APPEND info "list(APPEND ${dep}_Dependencies \"${New_${dependencyId}_Name}\")\n")
        endforeach()
        list(APPEND info "set(${dep}_OverallDependencies \"\")\n")
        foreach(dependencyId ${New_${dependency}_OverallDependencies})
            list(APPEND info "list(APPEND ${dep}_OverallDependencies \"${New_${dependencyId}_Name}\")\n")
        endforeach()
        list(APPEND info "set(${dep}_Dependants \"\")\n")
        foreach(dependencyId ${New_${dependency}_Dependants})
            list(APPEND info "list(APPEND ${dep}_Dependants \"${New_${dependencyId}_Name}\")\n")
        endforeach()
        list(APPEND info "set(${dep}_OverallDependants \"\")\n")
        foreach(dependencyId ${New_${dependency}_OverallDependants})
            list(APPEND info "list(APPEND ${dep}_OverallDependants \"${New_${dependencyId}_Name}\")\n")
        endforeach()                
        list(APPEND info "# End of info for dependecy ${dep}\n")
    endforeach()

    list(APPEND info "# Begin of Overall dependnecnies\n")    
    list(APPEND info "set(OverallDependencies \"\")\n")
    foreach(dep ${New_OverallDependencies})
        list(APPEND info "list(APPEND OverallDependencies \"${New_${dep}_Name}\")\n")
    endforeach()
    list(APPEND info "# End of Overall dependnecnies\n")
    
    list(APPEND info "# Begin of External dependnecnies\n")    
    list(APPEND info "set(ExternalDependencies \"\")\n")
    foreach(dep ${New_ExternalDependencies})
        list(APPEND info "list(APPEND ExternalDependencies \"${New_${dep}_Name}\")\n")
    endforeach()
    list(APPEND info "# End of External dependnecnies\n")
    
    list(APPEND info "# Begin of instalation order\n")    
    list(APPEND info "set(DEP_INSTALLATION_ORDER \"\")\n")
    foreach(dep ${New_OverallDependencies})
        list(APPEND info "list(APPEND DEP_INSTALLATION_ORDER \"${New_${dep}_Name}\")\n")
    endforeach()
    list(APPEND info "# End of instalation order\n")
        
    file(WRITE ${DEP_INFO_FILE} ${info})
endfunction()

#
#
#    _getDependenciesInfo
#        export all dependencies for package with name dependant
#
#
function(_getDependenciesInfo dependant dependencies)
    ParseDependencies("${dependencies}" dependenciesIndentifiers "ad")

    # remember dependant dependecies
    set_property(GLOBAL PROPERTY New_${dependant}_Dependencies ${dependenciesIndentifiers})
   
    # remember data   
    foreach(dependecyIdentifier ${dependenciesIndentifiers})
        # once any dependency set external, it stays external
        get_property(isAlreadyExternal GLOBAL PROPERTY New_${dependecyIdentifier}_IsExternal)
        if (NOT isAlreadyExternal AND ${ad_${dependecyIdentifier}_IsExternal})
            set_property(GLOBAL PROPERTY New_${dependecyIdentifier}_IsExternal "yes")
        endif()
        
        set_property(GLOBAL PROPERTY New_${dependecyIdentifier}_ScmPath ${ad_${dependecyIdentifier}_ScmPath})
        set_property(GLOBAL PROPERTY New_${dependecyIdentifier}_ScmType ${ad_${dependecyIdentifier}_ScmType})
    endforeach()
    
    # get data recursively
    foreach(dependecyIdentifier ${dependenciesIndentifiers})
        # export dependecy property
        _getDependencyInfo(${dependant} ${dependecyIdentifier}) 

        get_property(dependencyDependencies GLOBAL PROPERTY New_${dependecyIdentifier}_Dependencies)
        set_property(GLOBAL APPEND PROPERTY New_${dependant}_OverallDependencies ${dependencyDependencies} ${dependecyIdentifier})
    endforeach()
endfunction(_getDependenciesInfo)


# export one dependency for given dependant
function(_getDependencyInfo dependant dependency)

    get_property(dependencyName GLOBAL PROPERTY New_${dependency}_Name)
    
    if(NOT "${dependencyName}" STREQUAL "")
        # depenedency already processed in this turn, add only dependant
        set_property(GLOBAL APPEND PROPERTY New_${dependency}_Dependants ${dependant})
        
        get_property(dependencyDependants GLOBAL PROPERTY New_${dependant}_Dependants)
        set_property(GLOBAL APPEND PROPERTY New_${dependency}_OverallDependants ${dependant} ${dependencyDependants})
        return()
    endif()
    
    if(NOT "${${dependency}_Name}" STREQUAL "")
        # depenedency already processed in previous turn, fill all stored data
        _fillNewDependecyFromStoredOne(${dependency})
    else()
        get_property(scmPath GLOBAL PROPERTY New_${dependency}_ScmPath)
        get_property(scmType GLOBAL PROPERTY New_${dependency}_ScmType)
        _fillNewDependecyFromScm(${dependency} ${scmType} ${scmPath})
    endif()
    
    # remember its dependant and overall dependants
    set_property(GLOBAL PROPERTY New_${dependency}_Dependants ${dependant})
    get_property(dependencyDependants GLOBAL PROPERTY New_${dependant}_Dependants)    
    set_property(GLOBAL PROPERTY New_${dependency}_OverallDependants ${dependant} ${dependencyDependants})
            
    # store dependency name in list for further check
    set_property(GLOBAL APPEND PROPERTY New_OverallDependenciesNames ${dependencyName})
    # for each name store more different svn packages if any
    set_property(GLOBAL APPEND PROPERTY New_${dependencyName}_Packages ${dependency})
    
    # export dependencies of dependency via recursion
    get_property(dependencyDependencies GLOBAL PROPERTY New_${dependency}_DependenciesDescription)    
    _getDependenciesInfo("${dependency}" "${dependencyDependencies}")
endfunction(_getDependencyInfo)

function(_fillNewDependecyFromStoredOne dependency)
    set(depName ${${dependency}_Name})
    
    if(${DEP_INFO_FILE} IS_NEWER_THAN ${DEP_SOURCES_PATH}/${depName}/Properties.cmake)
        set_property(GLOBAL PROPERTY New_${dependency}_Name ${${depName}_Name})
        set_property(GLOBAL PROPERTY New_${dependency}_Type ${${depName}_Type})
        set_property(GLOBAL PROPERTY New_${dependency}_Version ${${depName}_Version})
        set_property(GLOBAL PROPERTY New_${dependency}_ScmPath ${${depName}_ScmPath})
        set_property(GLOBAL PROPERTY New_${dependency}_ScmType ${${depName}_ScmType})
        foreach(dep ${${depName}_Dependencies})       
            set_property(GLOBAL PROPERTY New_${dependency}_Dependencies ${${dep}_Id})
        endforeach()
        set_property(GLOBAL PROPERTY New_${dependency}_DependenciesDescription ${${depName}_DependenciesDescription})
    else()
        set(DEPENDENCIES "")
        set(NAME "")
        set(TYPE "")
        set(VERSION_MAJOR "")
        set(VERSION_MINOR "")
        set(VERSION_PATCH "")
        include(${DEP_SOURCES_PATH}/${depName}/Properties.cmake)
    
        ParseDependencies("${DEPENDENCIES}" dependencyDependenciesIds "exp")
            
        # store exported info
        set_property(GLOBAL PROPERTY New_${dependency}_Name "${NAME}")
        set_property(GLOBAL PROPERTY New_${dependency}_Type "${TYPE}")
        set_property(GLOBAL PROPERTY New_${dependency}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
        set_property(GLOBAL PROPERTY New_${dependency}_ScmPath "${exp_${dependency}_ScmPath}")
        set_property(GLOBAL PROPERTY New_${dependency}_ScmType "${exp_${dependency}_ScmType}")
        set_property(GLOBAL PROPERTY New_${dependency}_DependenciesDescription ${DEPENDENCIES})
        set_property(GLOBAL PROPERTY New_${dependency}_Dependencies ${dependencyDependenciesIds})
    endif()
endfunction(_fillNewDependecyFromStoredOne)

function(_fillNewDependecyFromScm dependency scmType scmPath)
    # log
    message(STATUS "Exporting Properties for dependency ${dependency}")
    # export dependecy property file
    set(localFile "${DEP_SRC_INFO_PATH}/properties.cmake")
    set(scmFile "${scmPath}/Properties.cmake")
    file(REMOVE ${localFile})
    _exportFromScm(${scmType} ${scmFile} ${localFile})
    # include properties file of dependecy
    set(DEPENDENCIES "")
    set(NAME "")
    set(TYPE "")
    set(VERSION_MAJOR "")
    set(VERSION_MINOR "")
    set(VERSION_PATCH "")
    set(dependencyDependenciesIds "")
    include(${localFile})

    ParseDependencies("${DEPENDENCIES}" dependencyDependenciesIds "")
        
    # store exported info
    set_property(GLOBAL PROPERTY New_${dependency}_Name "${NAME}")
    set_property(GLOBAL PROPERTY New_${dependency}_Type "${TYPE}")
    set_property(GLOBAL PROPERTY New_${dependency}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
    set_property(GLOBAL PROPERTY New_${dependency}_ScmPath "${scmPath}")
    set_property(GLOBAL PROPERTY New_${dependency}_ScmType "${scmType}")
    set_property(GLOBAL PROPERTY New_${dependency}_DependenciesDescription ${DEPENDENCIES})
    set_property(GLOBAL PROPERTY New_${dependency}_Dependencies ${dependencyDependenciesIds})
    file(REMOVE ${localFile})
endfunction(_fillNewDependecyFromScm)

function(_exportFromScm scmType scmFile localFile)
    if("svn" STREQUAL "${scmType}")
        _exportFromSvn(${scmFile} ${localFile})
    else()
        _exit("Scm \"${scmType}\" is not supported")
    endif()
endfunction()

function(_checkoutFromScm scmType scmFile localFile)
    if("svn" STREQUAL "${scmType}")
        _checkoutFromSvn(${scmFile} ${localFile})
    else()
        _exit("Scm \"${scmType}\" is not supported")
    endif()
endfunction()


function(_exportFromSvn svnFile localFile)
    # export
    execute_process(COMMAND svn export ${svnFile} ${localFile}
        RESULT_VARIABLE svnResult
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(${svnResult} GREATER 0)
        _exit("SVN Export Fails:\n${out}")
    endif()
endfunction(_exportFromSvn)

function(_checkoutFromSvn svnFile localFile)
    # export
    execute_process(COMMAND svn checkout ${svnFile} ${localFile}
        RESULT_VARIABLE svnResult
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(${svnResult} GREATER 0)
        _exit("SVN checkout Fails:\n${out}")
    endif()
endfunction()

#
#
#    _areOwnDependenciesChanged
#        Return yes when own dependencies are changed 
#
#
function(_areOwnDependenciesChanged dependencies areChanged areExternalFlagsChanged)
    ParseDependencies("${dependencies}" actualOwnDependencies aod)
    
    set(oldOwnDependencies "")
    foreach(oldDep ${${NAME}_Dependencies})
        list(APPEND oldOwnDependencies ${${oldDep}_Id}) 
    endforeach()
    set(newOwnDependencies "${actualOwnDependencies}")
            
    list(SORT oldOwnDependencies)
    list(SORT newOwnDependencies)
    
    if ("${oldOwnDependencies}" STREQUAL "${newOwnDependencies}")
        set(${areChanged} "no" PARENT_SCOPE)
        
        # dependencies are not changed, check if External flag is changed
        set(${areExternalFlagsChanged} "no" PARENT_SCOPE)
        foreach(ownDep ${oldOwnDependencies})
            if (NOT "${${ownDep}_IsExternal}" STREQUAL "${aod_${ownDep}_IsExternal}")
                # external flag is changed, updtae in cache
                set(${areExternalFlagsChanged} "yes" PARENT_SCOPE)
                break()
            endif()
        endforeach()     
    else()
        set(${areChanged} "yes" PARENT_SCOPE)
        set(${areExternalFlagsChanged} "yes" PARENT_SCOPE)
    endif()
endfunction()

#
#
#    _printDependencies
#        print all dependencies relations as UML component diagram 
#
#
function(_printDependencies projectName)
    message(STATUS "Generating Dependecies picture.")
    
    set(plantumlContent "@startuml\n")
    
    list(APPEND plantumlContent "skinparam component {\n")
    list(APPEND plantumlContent "BackgroundColor<<Container>> LightGreen\n")
    list(APPEND plantumlContent "BackgroundColor<<External Container>> LightGreen\n")
    list(APPEND plantumlContent "BorderColor<<External Container>> Black\n")
    list(APPEND plantumlContent "BackgroundColor<<Executable>> LightBlue\n")
    list(APPEND plantumlContent "BackgroundColor<<External Executable>> LightBlue\n")
    list(APPEND plantumlContent "BorderColor<<External Executable>> Black\n")
    list(APPEND plantumlContent "BorderColor<<External>> Black\n")
    list(APPEND plantumlContent "}\n")
    
    set(stereotypedPackages "")
    foreach(dependency ${New_OverallDependencies})
        if ("Container" STREQUAL "${New_${dependency}_Type}")
            list(APPEND stereotypedPackages ${dependency})
        elseif ("Executable" STREQUAL "${New_${dependency}_Type}")
            list(APPEND stereotypedPackages ${dependency})
        elseif (${New_${dependency}_IsExternal})
            list(APPEND stereotypedPackages ${dependency})
        endif()        
    endforeach()
    
    # create packages with version mismatch
    foreach(name ${New_OverallDependenciesNames})
        list(LENGTH New_${name}_Packages packagesCount)
        if(${packagesCount} GREATER 1)
            list(APPEND plantumlContent "package \"${name}\" {\n")
            list(APPEND plantumlContent "note \"<img:${CMAKE_ROOT}/Modules/SBE/tools/stop.png> <b><color:Red><size:16>Version mismatch</size></color></b>\" as N${name}\n")
            foreach(package ${New_${name}_Packages})
                # calculate stereotypes
                set(stereotype "")
                
                if (${New_${package}_IsExternal})
                    set(stereotype "External")
                endif()
                
                if ("Container" STREQUAL "${New_${package}_Type}")
                    if("" STREQUAL "${stereotype}")
                        set(stereotype "Container")
                    else()
                        set(stereotype "${stereotype} Container")
                    endif()
                elseif ("Executable" STREQUAL "${New_${package}_Type}")
                    if("" STREQUAL "${stereotype}")
                        set(stereotype "Executable")
                    else()
                        set(stereotype "${stereotype} Executable")
                    endif()
                endif()
                
                if("Development" STREQUAL "${SBE_MODE}")
                    set(versionText "")
                else()
                    set(versionText "\\n${New_${package}_Version}")
                endif()
                if("" STREQUAL "${stereotype}")
                    list(APPEND plantumlContent "[${New_${package}_Name}${versionText}] .. N${name}\n")
                else()
                    list(APPEND plantumlContent "[${New_${package}_Name}${versionText}] <<${stereotype}>> .. N${name}\n")
                    list(REMOVE_ITEM stereotypedPackages ${package})                    
                endif()
            endforeach()

            list(APPEND plantumlContent "}\n")
        endif()
    endforeach()
    
    # create packages with stereotypes that have no version mismatch
    foreach(dependency ${stereotypedPackages})
        # calculate stereotypes
        set(stereotype "")
        if (${New_${dependency}_IsExternal})
            set(stereotype "External")
        endif()
        
        if ("Container" STREQUAL "${New_${dependency}_Type}")
            if("" STREQUAL "${stereotype}")
                set(stereotype "Container")
            else()
                set(stereotype "${stereotype} Container")
            endif()
        elseif ("Executable" STREQUAL "${New_${dependency}_Type}")
            if("" STREQUAL "${stereotype}")
                set(stereotype "Executable")
            else()
                set(stereotype "${stereotype} Executable")
            endif()
        endif()

        if("Development" STREQUAL "${SBE_MODE}")
            set(versionText "")
        else()
            set(versionText "\\n${New_${dependency}_Version}")
        endif()
        list(APPEND plantumlContent "[${New_${dependency}_Name}${versionText}] <<${stereotype}>>\n")
    endforeach()
    
    foreach(dependency ${New_${projectName}_Dependencies})
        if("Development" STREQUAL "${SBE_MODE}")
            set(versionText "")
        else()
            set(versionText "\\n${New_${dependency}_Version}")
        endif()
        
        list(APPEND plantumlContent "[${projectName}]-->[${New_${dependency}_Name}${versionText}]\n")
    endforeach()
    
    foreach(dependency ${New_OverallDependencies})
        foreach(dependencyOfDependecy ${New_${dependency}_Dependencies})
            if("Development" STREQUAL "${SBE_MODE}")
                set(versionText "")
                set(versionTextd "")
            else()
                set(versionText "\\n${New_${dependency}_Version}")
                set(versionTextd "\\n${New_${dependencyOfDependecy}_Version}")
            endif()
            if ("Container" STREQUAL "${New_${dependency}_Type}")
                list(APPEND plantumlContent "[${New_${dependency}_Name}${versionText}]-->[${New_${dependencyOfDependecy}_Name}${versionTextd}] : contains\n")
            else()
                list(APPEND plantumlContent "[${New_${dependency}_Name}${versionText}]-->[${New_${dependencyOfDependecy}_Name}${versionTextd}]\n")
            endif()                
        endforeach()
    endforeach()
    
    list(APPEND plantumlContent "@enduml\n")
    
    file(WRITE ${DEP_SRC_INFO_PATH}/DependecyGraph.txt ${plantumlContent})
    
    execute_process(
        COMMAND java -jar ${CMAKE_ROOT}/Modules/SBE/tools/plantuml.jar ${DEP_SRC_INFO_PATH}/DependecyGraph.txt
        RESULT_VARIABLE result)
    
    file(REMOVE ${DEP_SRC_INFO_PATH}/DependecyGraph.txt)
endfunction (_printDependencies)

#
#
#    _checkDependenciesVersionsAndStopOnError
#        checks if all dependencies are used in same version by its dependants 
#
#    
function(_checkDependenciesVersionsAndStopOnError)
    set(report "")
    
    # check if all dependencies are used in same version
    foreach(name ${New_OverallDependenciesNames})
        list(LENGTH New_${name}_Packages packagesCount)
        if(${packagesCount} GREATER 1)
            set(report "${report}\nDependency ${name} is inconsistent.")
            foreach(package ${New_${name}_Packages})
                set(report "${report}\n    In version ${package} is used by")
                foreach(dependant ${New_${package}_Dependants})
                    set(report "${report}\n        ${dependant}")
                endforeach()
            endforeach()
        endif()
    endforeach()
    
    if(NOT "${report}" STREQUAL "")
        _exit("Dependencies error:\n${report}")
    endif()
endfunction(_checkDependenciesVersionsAndStopOnError)

#
#
#    _checkDependenciesLoopsAndStopOnError
#        checks if all dependencies are installable, report error when cyclic dependencies occures 
#
#
function(_checkDependenciesLoopsAndStopOnError)
    set(error "no")
    
    foreach(dependency ${New_OverallDependencies})
        if(NOT "" STREQUAL "${New_${dependency}_OverallDependencies}" AND NOT "" STREQUAL "${New_${dependency}_OverallDependants}")
            set(dependencies ${New_${dependency}_OverallDependencies})
            set(dependants ${New_${dependency}_OverallDependants})
            list(LENGTH dependants dependantsLength)
            list(REMOVE_ITEM dependants ${dependencies})
            list(LENGTH dependants newDependantsLength)
            if(NOT ${dependantsLength} EQUAL ${newDependantsLength})
               set(error "yes")
               break()
            endif()
        endif() 
    endforeach()
    
    if(error)
        _exit("Check generated picture for dependencies loops.")
    endif()
endfunction(_checkDependenciesLoopsAndStopOnError)

#
#
#    _orderDependenies
#        order dependencies to installation order 
#
#
function(_orderDependenies)
    
    # order overall dependencies
    set(dependenciesToOrder ${New_OverallDependencies})
    foreach(countToRemove RANGE 0 ${New_MaximumDependenciesLength})
        foreach(dep ${dependenciesToOrder})
            list(LENGTH  New_${dep}_Dependencies itsDependenciesCount)
            if(${countToRemove} EQUAL ${itsDependenciesCount})
                set_property(GLOBAL APPEND PROPERTY New_OrderedDependencies ${dep})
                list(REMOVE_ITEM dependenciesToOrder ${dep})
            endif()        
        endforeach()
    endforeach()
    
    # set ordered dependencies
    get_property(nod GLOBAL PROPERTY New_OrderedDependencies)
    set(New_OverallDependencies ${nod} PARENT_SCOPE)
    set(New_${MAIN_DEPENDANT}_OverallDependencies ${nod} PARENT_SCOPE)
    
    # set order dependencies in dependencies
    foreach(dep ${nod})
        if (NOT "" STREQUAL "${New_${dep}_OverallDependencies}") 
            set(tmp ${nod})
            list(REMOVE_ITEM tmp ${New_${dep}_OverallDependencies})
            set(orderedDependencies ${nod})
            list(REMOVE_ITEM orderedDependencies ${tmp})
            set(New_${dep}_OverallDependencies ${orderedDependencies} PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

#
#
#    _createInfoAboutExternalFlag
#        claculates external dependencies
#            * dependency is external if is flaged as external in own dependencies
#
#
function (_createInfoAboutExternalFlag)
    set(externalDependencies "")
    
    get_property(New_OverallDependencies GLOBAL PROPERTY New_${MAIN_DEPENDANT}_OverallDependencies)
    if(DEFINED New_OverallDependencies)
        list(REMOVE_DUPLICATES New_OverallDependencies)
    endif()
    
    foreach(dep ${New_OverallDependencies})
        get_property(isExternal GLOBAL PROPERTY New_${dep}_IsExternal)
        if(isExternal)
            list(APPEND externalDependencies ${dep})
            get_property(depDependencies GLOBAL PROPERTY New_${dep}_OverallDependencies)
            foreach(depDependency ${depDependencies})
                set_property(GLOBAL PROPERTY New_${depDependency}_IsExternal "yes")
                list(APPEND externalDependencies ${depDependency})
            endforeach()
        endif()
    endforeach()
    
    list(REMOVE_DUPLICATES externalDependencies)
        
    set_property(GLOBAL PROPERTY New_ExternalDependencies ${externalDependencies})
endfunction ()


#
#
#    _removeUnusedDependencies
#        removes dependency 
#
#
function(_removeUnusedDependencies)
    if(NOT DEFINED OverallDependencies)
        return()
    endif()
    
    set(dependenciesToRemove ${OverallDependencies})
    
    foreach(newDep ${New_OverallDependencies})
        list(REMOVE_ITEM dependenciesToRemove ${New_${newDep}_Name})
    endforeach()
    
    foreach(dependency ${dependenciesToRemove})
        message(STATUS "Removing unused dependency sources ${dependency}")
        
        file(REMOVE_RECURSE ${DEP_SOURCES_PATH}/${dependency}})
    endforeach()
endfunction(_removeUnusedDependencies)

#
#
#    _exportRequiredDependencies
#        export dependencies sources 
#
#
function(_exportRequiredDependencies)
    foreach(dependecy ${New_OverallDependencies})
        if(NOT EXISTS ${DEP_SOURCES_PATH}/${New_${dependecy}_Name})
            # export dependecy from svn 
            message(STATUS "Exporting Sources for dependency ${dependecy}")
            _checkoutFromScm(${New_${dependecy}_ScmType} ${New_${dependecy}_ScmPath} ${DEP_SOURCES_PATH}/${New_${dependecy}_Name})
        endif()
    endforeach()
endfunction(_exportRequiredDependencies)

function(_exit reason)
    _cleanup()
    message(STATUS "${reason}")
    message(FATAL_ERROR "exit")
endfunction(_exit)

function(_cleanup)
endfunction(_cleanup)

ExportProperties("${DEPENDENCIES}")
  
