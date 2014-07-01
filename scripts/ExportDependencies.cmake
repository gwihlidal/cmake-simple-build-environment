cmake_minimum_required(VERSION 2.8)

if(NOT DEP_SOURCE_DIR)
    message(FATAL_ERROR "Path to Properties.txt has to be defined as DEP_SOURCE_DIR=path.")
endif()

if(NOT DEP_SRC_DEPLOYMENT_PATH)
    set(DEP_SRC_DEPLOYMENT_PATH "${DEP_SOURCE_DIR}/dependencies")
endif()
set(DEP_PROPERTIES_FILE "${DEP_SOURCE_DIR}/Properties.cmake")
# set export directories
set(DEP_SOURCES_PATH "${DEP_SRC_DEPLOYMENT_PATH}/sources")
set(DEP_SRC_INFO_PATH "${DEP_SRC_DEPLOYMENT_PATH}/info")
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

include(${DEP_PROPERTIES_FILE})

include(${DEP_INFO_FILE} OPTIONAL)

# export all properties files    
function(ExportProperties dependencies)
    set(${NAME}_Name "${NAME}" CACHE INTERNAL "" FORCE)
    set(${NAME}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}" CACHE INTERNAL "" FORCE)

    if(EXISTS ${DEP_INFO_FILE} AND ${DEP_INFO_FILE} IS_NEWER_THAN ${DEP_PROPERTIES_FILE})
        return()
    endif()
    
    _storeOwnDependencies("${dependencies}" areChanged areExternalFlagsChanged)
    
    if(NOT areChanged)
        if(NOT areExternalFlagsChanged)
            # nothing to do
            _cleanup()
            return()
        endif()
        
        # setup new dependencies data
        _getDependenciesInfo(${NAME} "${dependencies}")
        
        # external flags are changed recreate picture
        _createInfoAboutExternalFlag("${dependencies}")
        
        _printDependencies(${NAME})
        
        # only picture is chaged, nothing else has to be done
        _cleanup()
        return()
    endif()
    
    _getDependenciesInfo(${NAME} "${dependencies}")

    foreach(dep ${New_OverallDependencies} ${NAME})
        message("\n${dep}\nDependants\nDirect - [${New_${dep}_Dependants}]\nOverall - [${New_${dep}_OverallDependants}]\nDependencies\nDirect - [${New_${dep}_DependenciesX}]\nOverall - [${New_${dep}_OverallDependenciesX}]\n")
    endforeach()
        
    _createInfoAboutExternalFlag("${dependencies}")
    
    _printDependencies(${NAME})
        
    _checkDependenciesVersionsAndStopOnError()

    _calculateDependeniesInstallationOrderAndStopOnError()
    
    _updateDependeciesInstallationOrderInInfoFile()
    
    _removeUnusedDependencies()
    
    _exportRequiredDependencies()
    
    _cleanup()
endfunction(ExportProperties)

#
#
#    _getDependenciesInfo
#        export all dependencies for package with name dependant
#
#
function(_getDependenciesInfo dependant dependencies)
    ParseDependencies("${dependencies}" dependenciesIndentifiers)

    # remember dependant dependecies
    set(New_${dependant}_DependenciesX ${dependenciesIndentifiers} CACHE INTERNAL "" FORCE)
    set(New_${dependant}_OverallDependenciesX "" CACHE INTERNAL "" FORCE)
    
    foreach(dependecyIdentifier ${dependenciesIndentifiers})
        # export dependecy property
        _getDependencyInfo(${dependant} ${dependecyIdentifier})
        
        _addToChachedList(New_${dependant}_OverallDependenciesX ${dependecyIdentifier} ${New_${dependecyIdentifier}_Dependencies})
    endforeach()
    
endfunction(_getDependenciesInfo)


# export one dependency for given dependant
function(_getDependencyInfo dependant dependency)

    if(NOT "${New_${dependency}_Name}" STREQUAL "")
        # depenedency already processed in this turn, add only dependant
        _addToChachedList(New_${dependency}_Dependants ${dependant})
        _addToChachedList(New_${dependency}_OverallDependants ${dependant} ${New_${dependant}_Dependants})
        return()
    endif()
    
    if(NOT "${${dependency}_Name}" STREQUAL "")
        # depenedency already processed in previous turn, fill all stored data
        _fillNewDependecyFromStoredOne(${dependency})
    else()
        _fillNewDependecyFromScm(${dependency})
        _storeDependencyInInfoFile(${dependency})
    endif()

    # remember its dependant and overall dependants
    set(New_${dependency}_Dependants ${dependant} CACHE INTERNAL "" FORCE)    
    set(New_${dependency}_OverallDependants ${dependant} ${New_${dependant}_Dependants} CACHE INTERNAL "" FORCE)
            
    # store dependency name in list for further check
    _addToChachedList(New_OverallDependenciesNames ${New_${dependency}_Name})
    # for each name store more different svn packages if any
    _addToChachedList(New_${New_${dependency}_Name}_Packages ${dependency})
    
    # store dependency in dependencies list
    _addToChachedList(New_OverallDependencies ${dependency})

    # export dependencies of dependency via recursion    
    _getDependenciesInfo("${dependency}" "${New_${dependency}_DependenciesDescription}")
endfunction(_getDependencyInfo)

function(_fillNewDependecyFromStoredOne dependency)
    set(New_${dependency}_Name ${${dependency}_Name} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_Type ${${dependency}_Type} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_Version ${${dependency}_Version} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_ScmPath ${${dependency}_ScmPath} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_ScmType ${${dependency}_ScmType} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_Dependencies ${${dependency}_Dependencies} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_Dependants ${${dependency}_Dependants} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_DependenciesDescription ${${dependency}_DependenciesDescription} CACHE INTERNAL "" FORCE)
    if(DEFINED ${dependency}_IsExported)
        set(New_${dependency}_IsExported ${${dependency}_IsExported} CACHE INTERNAL "" FORCE)
    else()
        set(New_${dependency}_IsExported "no" CACHE INTERNAL "" FORCE)
    endif()
endfunction(_fillNewDependecyFromStoredOne)

function(_fillNewDependecyFromScm dependency)
    # log
    message(STATUS "Exporting Properties for dependency ${dependency}")
    # export dependecy property file
    set(localFile "${DEP_SRC_INFO_PATH}/properties.cmake")
    set(scmFile "${${dependency}_ScmPath}/Properties.cmake")
    file(REMOVE ${localFile})
    _exportFromScm(${${dependency}_ScmType} ${scmFile} ${localFile})
    # include properties file of dependecy
    set(DEPENDENCIES "")
    set(NAME "")
    set(TYPE "")
    set(VERSION_MAJOR "")
    set(VERSION_MINOR "")
    set(VERSION_PATCH "")
    include(${localFile})

    ParseDependencies("${DEPENDENCIES}" dependencyDependenciesIds)
        
    # store exported info
    set(New_${dependency}_Name "${NAME}" CACHE INTERNAL "" FORCE)
    set(New_${dependency}_Type "${TYPE}" CACHE INTERNAL "" FORCE)
    set(New_${dependency}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}" CACHE INTERNAL "" FORCE)
    set(New_${dependency}_ScmPath "${${dependency}_ScmPath}" CACHE INTERNAL "" FORCE)
    set(New_${dependency}_ScmType "${${dependency}_ScmType}" CACHE INTERNAL "" FORCE)
    set(New_${dependency}_DependenciesDescription ${DEPENDENCIES} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_Dependencies ${dependencyDependenciesIds} CACHE INTERNAL "" FORCE)
    set(New_${dependency}_IsExported "no" CACHE INTERNAL "" FORCE)
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

function(_storeDependencyInInfoFile dependency)
    set(info "")
    
    if(EXISTS ${DEP_INFO_FILE})
        file(READ ${DEP_INFO_FILE} info)
        string(REPLACE "\n" "\n;" info "${info}")
    endif()        
    
    list(APPEND info "# Begin of info for dependecy ${dependency}\n")
    list(APPEND info "list(APPEND OverallDependencies \"${dependency}\")\n")
    list(APPEND info "list(REMOVE_DUPLICATES OverallDependencies)\n")
    list(APPEND info "set(${dependency}_Name \"${New_${dependency}_Name}\")\n")
    list(APPEND info "set(${dependency}_Type \"${New_${dependency}_Type}\")\n")
    list(APPEND info "set(${dependency}_Version \"${New_${dependency}_Version}\")\n")
    list(APPEND info "set(${dependency}_ScmPath \"${New_${dependency}_ScmPath}\")\n")
    list(APPEND info "set(${dependency}_ScmType \"${New_${dependency}_ScmType}\")\n")
    list(APPEND info "set(${dependency}_DependenciesDescription \"\")\n")
    foreach(dependencyDescriptionItem ${New_${dependency}_DependenciesDescription})
        list(APPEND info "list(APPEND ${dependency}_DependenciesDescription \"${dependencyDescriptionItem}\")\n")
    endforeach()
    list(APPEND info "set(${dependency}_Dependencies \"\")\n")
    foreach(dependencyId ${New_${dependency}_Dependencies})
        list(APPEND info "list(APPEND ${dependency}_Dependencies \"${dependencyId}\")\n")
    endforeach()
    list(APPEND info "# End of info for dependecy ${dependency}\n")
    
    file(WRITE ${DEP_INFO_FILE} ${info})
endfunction(_storeDependencyInInfoFile)


function(_addToChachedList list)
    set(tmp "")
    list(APPEND tmp ${${list}} ${ARGN})
    list(REMOVE_DUPLICATES tmp)
    set(${list} ${tmp} CACHE INTERNAL "" FORCE)
endfunction(_addToChachedList)

#
#
#    _storeOwnDependencies
#        Return yes when own dependencies are changed 
#
#
function(_storeOwnDependencies dependencies areChanged areExternalFlagsChanged)
    ParseDependencies("${dependencies}" actualOwnDependencies)
    
    set(oldDep "")
    if(DEFINED OwnCachedDependencies)
        set(oldDep ${OwnCachedDependencies})
    endif()
    set(newDep "")
    if(DEFINED actualOwnDependencies)
        set(newDep ${actualOwnDependencies})
    endif()
            
    list(SORT oldDep)
    list(SORT newDep)
    
    if ("${oldDep}" STREQUAL "${newDep}")
        set(${areChanged} "no" PARENT_SCOPE)
        
        # dependencies are not changed, check if External flag is changed
        set(${areExternalFlagsChanged} "no" PARENT_SCOPE)
        foreach(ownDep ${OwnCachedDependencies})
            if (NOT "${Own_${ownDep}_IsExternal}" STREQUAL "${${ownDep}_IsExternal}")
                # external flag is changed, updtae in cache
                set(${areExternalFlagsChanged} "yes" PARENT_SCOPE)
                set(Own_${ownDep}_IsExternal ${${ownDep}_IsExternal} CACHE INTERNAL "" FORCE)
            endif()
        endforeach()     
    else()
        _cleanAllOwnDependencyData()
        # add all own dependencies to cache
        set(OwnCachedDependencies ${actualOwnDependencies} CACHE INTERNAL "" FORCE)
        foreach(ownDep ${OwnCachedDependencies})
            set(Own_${ownDep}_IsExternal ${${ownDep}_IsExternal} CACHE INTERNAL "" FORCE)
        endforeach()
                
        set(${areChanged} "yes" PARENT_SCOPE)
        set(${areExternalFlagsChanged} "yes" PARENT_SCOPE)
    endif()
endfunction()

#
#
#    _cleanAllOwnDependencyData
#        clean own dependency data 
#
#
function(_cleanAllOwnDependencyData)
    # remove all own dependencies data from cache
    foreach(ownDep ${OwnCachedDependencies})
        unset(Own_${ownDep}_IsExternal CACHE)
    endforeach()
    unset(OwnCachedDependencies CACHE)
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
    
    foreach(dependency ${OwnCachedDependencies})
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
#    _calculateDependeniesInstallationOrderAndStopOnError
#        checks if all dependencies are installable, report error when cyclic dependencies occures 
#
#
function(_calculateDependeniesInstallationOrderAndStopOnError)
    # Get not installed Dependencies with no dependecies, they are ready to install
    # Get all not installed dependencies
    set(dependenciesToInstall "")
    set(notInstalledDependecies "")
    foreach(dependency ${New_OverallDependencies})
        list(FIND INSTALLATION_ORDER ${dependency} isFound)
        if(${isFound} EQUAL -1)
            list(LENGTH  New_${dependency}_Dependencies itsDependenciesCount)
            if(0 EQUAL ${itsDependenciesCount})
                list(APPEND dependenciesToInstall ${dependency})
            endif()
            
            list(APPEND notInstalledDependecies ${dependency})
        endif()
    endforeach()
    
    # Check for loop dependencies. If they are no dependency to install and not all dependencies are installed, 
    # they are loop dependencies. Report error.
    if(("" STREQUAL "${dependenciesToInstall}") AND (NOT "" STREQUAL "${notInstalledDependecies}"))
        _removeInstallationOrderSection()
        
        set(errorText "It is not possible to install dependencies:\n")
        foreach(notInstalledDependency ${notInstalledDependecies})
            list(APPEND errorText "${notInstalledDependency}\n")
        endforeach()
        
        list(APPEND errorText "Check generated picture for dependencies loops.")
        _exit("${errorText}")
    endif() 
     
    # All dependencies satisfied
    if(("" STREQUAL "${dependenciesToInstall}") AND ("" STREQUAL "${notInstalledDependecies}"))
        set(NEW_DEP_INSTALLATION_ORDER ${INSTALLATION_ORDER} CACHE INTERNAL "" FORCE)
        return()
    endif()
    
    # install dependencies
    foreach(dep ${dependenciesToInstall})
        # add to dependency installation order list
        list(APPEND INSTALLATION_ORDER ${dep})
        # remove dependencies from all its dependants
        foreach(deps ${New_OverallDependencies})
            list(REMOVE_ITEM New_${deps}_Dependencies ${dep})
        endforeach()
    endforeach()
    
    # check next turn, some dependencies are installed, check dependants of this dependencies, if they are also installable
    _calculateDependeniesInstallationOrderAndStopOnError()
endfunction(_calculateDependeniesInstallationOrderAndStopOnError)

#
#
#    _updateDependeciesInstallationOrderInInfoFile
#        write dependencies installation order in info file 
#
#
function (_updateDependeciesInstallationOrderInInfoFile)
    file(READ ${DEP_INFO_FILE} info)
    string(REPLACE "\n" "\n;" info "${info}")
    list(FIND info "# Begin of installation order section\n" beginIndex)
    list(FIND info "# End of installation order section\n" endIndex)
    
    if(NOT ${beginIndex} EQUAL -1 AND NOT ${endIndex} EQUAL -1)
        # remove old values
        foreach(index RANGE ${beginIndex} ${endIndex})
            list(REMOVE_AT info ${beginIndex})
        endforeach()
    endif()
    
    # add new values
    list(APPEND info "# Begin of installation order section\n")
    list(APPEND info "set(DEP_INSTALLATION_ORDER \"\")\n")
    foreach(dependency ${NEW_DEP_INSTALLATION_ORDER})
        list(APPEND info "list(APPEND DEP_INSTALLATION_ORDER \"${dependency}\")\n")
    endforeach(dependency ${NEW_DEP_INSTALLATION_ORDER})
    list(APPEND info "# End of installation order section\n")
    
    file(WRITE ${DEP_INFO_FILE} ${info})
endfunction (_updateDependeciesInstallationOrderInInfoFile)


#
#
#    _createInfoAboutExternalFlag
#        claculates external dependencies
#            * dependency is external if is flaged as external in own dependencies
#
#
function (_createInfoAboutExternalFlag dependenciesDescription)
    set(externalDependencies "")
    
    _getAllExternalDependenciesRecursivellyFor("${dependenciesDescription}" externalDependencies)
    
    # write change in info file   
    file(READ ${DEP_INFO_FILE} info)
    string(REPLACE "\n" "\n;" info "${info}")
    list(FIND info "# Begin of external dependencies section\n" beginIndex)
    list(FIND info "# End of external dependencies section\n" endIndex)
    
    if(NOT ${beginIndex} EQUAL -1 AND NOT ${endIndex} EQUAL -1)
        # remove old values
        foreach(index RANGE ${beginIndex} ${endIndex})
            list(REMOVE_AT info ${beginIndex})
        endforeach()
    endif()
    
    # add new values
    list(APPEND info "# Begin of external dependencies section\n")
    list(APPEND info "set(EXTERNAL_DEPENDENCIES \"\")\n")
    foreach(dependency ${externalDependencies})
        list(APPEND info "list(APPEND EXTERNAL_DEPENDENCIES \"${dependency}\")\n")
    endforeach()
    foreach(dependency ${externalDependencies})
        list(APPEND info "set(${dependency}_IsExternal \"yes\")\n")
        set(New_${dependency}_IsExternal "yes" CACHE INTERNAL "" FORCE)
    endforeach()
    list(APPEND info "# End of external dependencies section\n")
    
    file(WRITE ${DEP_INFO_FILE} ${info})
    
    set(New_ExternalDependencies ${externalDependencies} CACHE INTERNAL "" FORCE)
endfunction (_createInfoAboutExternalFlag)

function(_getAllExternalDependenciesRecursivellyFor depsDescription externalDeps)
    ParseDependencies("${depsDescription}" dependencies)
    
    set(depOverallDependencies "")
    
    foreach(dependency ${dependencies})
        set(externalDependencies "")
            
        if(${${dependency}_IsExternal})
            list(APPEND depOverallDependencies ${dependency})
            _getAllDependenciesRecursivellyFor("${New_${dependency}_DependenciesDescription}" externalDependencies)
        else()
            _getAllExternalDependenciesRecursivellyFor("${New_${dependency}_DependenciesDescription}" externalDependencies)
        endif()
        
        if(NOT "" STREQUAL "${externalDependencies}")
            list(APPEND depOverallDependencies ${externalDependencies})
        endif()
    endforeach()
    
    list(REMOVE_DUPLICATES depOverallDependencies)
    set(${externalDeps} ${depOverallDependencies} PARENT_SCOPE)
endfunction()

function(_getAllDependenciesRecursivellyFor depsDescription deps)
    ParseDependencies("${depsDescription}" dependencies)
    
    set(depOverallDependencies "")
    
    foreach(dependency ${dependencies})
        _getAllDependenciesRecursivellyFor("${New_${dependency}_DependenciesDescription}" depDeps)
         list(APPEND depOverallDependencies ${dependency})
         list(APPEND depOverallDependencies ${depDeps})
    endforeach()
    
    list(REMOVE_DUPLICATES depOverallDependencies)
    set(${deps} ${depOverallDependencies} PARENT_SCOPE)
endfunction()

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
    
    if(DEFINED New_OverallDependencies)
        list(REMOVE_ITEM dependenciesToRemove ${New_OverallDependencies})
    endif()
    
    foreach(dependency ${dependenciesToRemove})
        message(STATUS "Removing unused dependency sources ${dependency}")
        
        file(REMOVE_RECURSE ${DEP_SOURCES_PATH}/${${dependency}_Name})
        
        _RemoveDependencySectionFromInfoFile(${dependency})
    endforeach()
endfunction(_removeUnusedDependencies)

function (_RemoveDependencySectionFromInfoFile dependency)
    file(READ ${DEP_INFO_FILE} info)
    string(REPLACE "\n" "\n;" info "${info}")
    list(FIND info "# Begin of info for dependecy ${dependency}\n" beginIndex)
    list(FIND info "# End of info for dependecy ${dependency}\n" endIndex)
    
    foreach(index RANGE ${beginIndex} ${endIndex})
        list(REMOVE_AT info ${beginIndex})
    endforeach()
    
    file(WRITE ${DEP_INFO_FILE} ${info})
endfunction()

#
#
#    _exportRequiredDependencies
#        export dependencies sources 
#
#
function(_exportRequiredDependencies)
    foreach(dependecy ${New_OverallDependencies})
        if(NOT ${New_${dependecy}_IsExported})
            # export dependecy from svn 
            message(STATUS "Exporting Sources for dependency ${dependecy}")
            _checkoutFromScm(${New_${dependecy}_ScmType} ${New_${dependecy}_ScmPath} ${DEP_SOURCES_PATH}/${New_${dependecy}_Name})
            _setExported(${dependecy})
        endif()
    endforeach()
endfunction(_exportRequiredDependencies)

function(_setExported dependency)
    set(New_${dependency}_IsExported "yes" CACHE INTERNAL "" FORCE)

    file(READ ${DEP_INFO_FILE} info)
    string(REPLACE "\n" "\n;" info "${info}")
    list(FIND info "# End of info for dependecy ${dependency}\n" index)
    list(INSERT info ${index} "set(${dependency}_IsExported \"${New_${dependecy}_IsExported}\")\n")
            
    file(WRITE ${DEP_INFO_FILE} ${info})
endfunction(_setExported)


function(_removeFromChachedList list value)
    set(tmp ${${list}})
    if(NOT "${tmp}" STREQUAL "")
        list(REMOVE_ITEM tmp ${value})
        set(${list} ${tmp} CACHE INTERNAL "" FORCE)
    endif()        
endfunction(_removeFromChachedList)

function(_exit reason)
    _cleanAllOwnDependencyData()
    _cleanup()
    message(STATUS "${reason}")
    message(FATAL_ERROR "exit")
endfunction(_exit)

function(_cleanup)
    _clearTempCache()
endfunction(_cleanup)

function(_clearTempCache)
    unset(${NAME}_Name CACHE)
    unset(${NAME}_Version CACHE)
    
    foreach(name ${New_OverallDependenciesNames})
        unset(New_${name}_Packages CACHE)
    endforeach()
    unset(New_OverallDependenciesNames CACHE)
    
    foreach(dependecy ${New_OverallDependencies})
        unset(New_${dependecy}_Name CACHE)
        unset(New_${dependecy}_Type CACHE)
        unset(New_${dependecy}_Version CACHE)
        unset(New_${dependecy}_ScmPath CACHE)
        unset(New_${dependecy}_ScmType CACHE)
        unset(New_${dependecy}_Dependants CACHE)
        unset(New_${dependecy}_Dependencies CACHE)
        unset(New_${dependecy}_DependenciesDescription CACHE)
        unset(New_${dependecy}_IsExported CACHE)
    endforeach()
    unset(New_OverallDependencies CACHE)
    
    foreach(dependecy ${New_ExternalDependencies})
        unset(New_${dependecy}_IsExternal CACHE)
    endforeach()
    unset(New_ExternalDependencies CACHE)
   
    unset(NEW_DEP_INSTALLATION_ORDER CACHE)
endfunction(_clearTempCache)

function (_removeInstallationOrderSection)
    file(READ ${DEP_INFO_FILE} info)
    string(REPLACE "\n" "\n;" info "${info}")
    list(FIND info "# Begin of installation order section\n" beginIndex)
    list(FIND info "# End of installation order section\n" endIndex)
    
    if(${beginIndex} EQUAL -1 OR ${endIndex} EQUAL -1)
        return()
    endif()
    
    foreach(index RANGE ${beginIndex} ${endIndex})
        list(REMOVE_AT info ${beginIndex})
    endforeach()
    
    file(WRITE ${DEP_INFO_FILE} ${info})
endfunction()

ExportProperties("${DEPENDENCIES}")

foreach(dependecy ${OverallDependencies})
    unset(${dependecy}_Name)
    unset(${dependecy}_Type)
    unset(${dependecy}_Version)
    unset(${dependecy}_ScmPath)
    unset(${dependecy}_Dependencies)
    unset(${dependecy}_DependenciesDescription)
    unset(${dependecy}_IsExported)
endforeach()
unset(OverallDependencies)
unset(DEP_INSTALLATION_ORDER)

foreach(dependecy ${EXTERNAL_DEPENDENCIES})
    unset(${dependecy}_IsExternal)
endforeach()
unset(EXTERNAL_DEPENDENCIES)
  
