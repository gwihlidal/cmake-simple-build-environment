cmake_minimum_required(VERSION 2.8)

if(NOT DEP_SOURCE_DIR)
    message(FATAL_ERROR "Path to Properties.txt has to be defined as DEP_SOURCE_DIR=path.")
endif()

if(NOT DEP_SRC_DEPLOYMENT_PATH)
    set(DEP_SRC_DEPLOYMENT_PATH "${DEP_SOURCE_DIR}/dependencies")
    set(MAIN_DEPENDANT ${NAME})
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
    if(EXISTS ${DEP_INFO_FILE} AND ${DEP_INFO_FILE} IS_NEWER_THAN ${DEP_PROPERTIES_FILE})
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
        
        _publishPropertiesAsVariable()
        
        _createInfoAboutExternalFlag()
            
        # generate picture
        _printDependencies(${MAIN_DEPENDANT})
        
        # only picture is chaged, nothing else has to be done
        _cleanup()
        return()
    endif()
    
    _getDependenciesInfo(${MAIN_DEPENDANT} "${${MAIN_DEPENDANT}_DependenciesDescription}")

    _publishPropertiesAsVariable()
    
    _createInfoAboutExternalFlag()
    
    _printDependencies(${MAIN_DEPENDANT})
        
    _checkDependenciesVersionsAndStopOnError()

    _checkDependenciesLoopsAndStopOnError()
    
    _removeUnusedDependencies()
    
    _exportRequiredDependencies()

    _storeNewInfoFile()
        
    _cleanup()
endfunction(ExportProperties)

macro(_publishPropertiesAsVariable)
    # properties to variable
    get_property(New_OverallDependencies GLOBAL PROPERTY New_OverallDependencies)
    if(DEFINED New_OverallDependencies)
        list(REMOVE_DUPLICATES New_OverallDependencies)
        list(REVERSE New_OverallDependencies)
    endif()
    foreach(dep ${New_OverallDependencies} ${MAIN_DEPENDANT})
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
        endif()
        
        get_property(New_${dep}_OverallDependencies GLOBAL PROPERTY New_${dep}_OverallDependencies)
        if(DEFINED New_${dep}_OverallDependencies)
            list(REMOVE_DUPLICATES New_${dep}_OverallDependencies)
            list(REVERSE New_${dep}_OverallDependencies)
        endif()

        get_property(New_${dep}_Name GLOBAL PROPERTY New_${dep}_Name)
        get_property(New_${dep}_Type GLOBAL PROPERTY New_${dep}_Type)
        get_property(New_${dep}_Version GLOBAL PROPERTY New_${dep}_Version)
        get_property(New_${dep}_ScmPath GLOBAL PROPERTY New_${dep}_ScmPath)
        get_property(New_${dep}_ScmType GLOBAL PROPERTY New_${dep}_ScmType)
        get_property(New_${dep}_DependenciesDescription GLOBAL PROPERTY New_${dep}_DependenciesDescription)
        get_property(New_${dep}_IsExternal GLOBAL PROPERTY New_${dep}_IsExternal)
    endforeach()
    
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
    ParseDependencies("${dependencies}" dependenciesIndentifiers "")

    # remember dependant dependecies
    set_property(GLOBAL PROPERTY New_${dependant}_Dependencies ${dependenciesIndentifiers})
    set_property(GLOBAL PROPERTY New_${dependant}_OverallDependencies "")
    
    foreach(dependecyIdentifier ${dependenciesIndentifiers})
        # export dependecy property
        _getDependencyInfo(${dependant} ${dependecyIdentifier})
        
        set_property(GLOBAL PROPERTY New_${dependecyIdentifier}_IsExternal ${${dependecyIdentifier}_IsExternal})
        
        get_property(dependencyDependencies GLOBAL PROPERTY New_${dependecyIdentifier}_Dependencies)
        set_property(GLOBAL APPEND PROPERTY New_${dependant}_OverallDependencies ${dependecyIdentifier} ${dependencyDependencies})
    endforeach()
    
    #
    #
    #  Sort OverallDependencies according to installation order
    #
    #
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
        _fillNewDependecyFromScm(${dependency})
    endif()

    # remember its dependant and overall dependants
    set_property(GLOBAL PROPERTY New_${dependency}_Dependants ${dependant})
    get_property(dependencyDependants GLOBAL PROPERTY New_${dependant}_Dependants)    
    set_property(GLOBAL PROPERTY New_${dependency}_OverallDependants ${dependant} ${dependencyDependants})
            
    # store dependency name in list for further check
    set_property(GLOBAL APPEND PROPERTY New_OverallDependenciesNames ${dependencyName})
    # for each name store more different svn packages if any
    set_property(GLOBAL APPEND PROPERTY New_${dependencyName}_Packages ${dependency})
    
    # store dependency in dependencies list
    set_property(GLOBAL APPEND PROPERTY New_OverallDependencies ${dependency})

    # export dependencies of dependency via recursion
    get_property(dependencyDependencies GLOBAL PROPERTY New_${dependency}_DependenciesDescription)    
    _getDependenciesInfo("${dependency}" "${dependencyDependencies}")
endfunction(_getDependencyInfo)

function(_fillNewDependecyFromStoredOne dependency)
    set(depName ${${dependency}_Name})
    
    if(${DEP_INFO_FILE} IS_NEWER_THAN ${DEP_SRC_DEPLOYMENT_PATH}/${depName}/Properties.cmake)
        set_property(GLOBAL PROPERTY New_${dependency}_Name ${${depName}_Name})
        set_property(GLOBAL PROPERTY New_${dependency}_Type ${${depName}_Type})
        set_property(GLOBAL PROPERTY New_${dependency}_Version ${${depName}_Version})
        set_property(GLOBAL PROPERTY New_${dependency}_ScmPath ${${depName}_ScmPath})
        set_property(GLOBAL PROPERTY New_${dependency}_ScmType ${${depName}_ScmType})
        set_property(GLOBAL PROPERTY New_${dependency}_Dependencies ${${depName}_Dependencies})
        set_property(GLOBAL PROPERTY New_${dependency}_OverallDependencies ${${depName}_OverallDependencies})
        set_property(GLOBAL PROPERTY New_${dependency}_Dependants ${${depName}_Dependants})
        set_property(GLOBAL PROPERTY New_${dependency}_OverallDependants ${${depName}_OverallDependants})
        set_property(GLOBAL PROPERTY New_${dependency}_DependenciesDescription ${${depName}_DependenciesDescription})
        set_property(GLOBAL PROPERTY New_${dependency}_IsExternal ${${depName}_IsExternal})
    else()
        set(DEPENDENCIES "")
        set(NAME "")
        set(TYPE "")
        set(VERSION_MAJOR "")
        set(VERSION_MINOR "")
        set(VERSION_PATCH "")
        include(${DEP_SRC_DEPLOYMENT_PATH}/${depName}/Properties.cmake)
    
        ParseDependencies("${DEPENDENCIES}" dependencyDependenciesIds "")
            
        # store exported info
        set_property(GLOBAL PROPERTY New_${dependency}_Name "${NAME}")
        set_property(GLOBAL PROPERTY New_${dependency}_Type "${TYPE}")
        set_property(GLOBAL PROPERTY New_${dependency}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
        set_property(GLOBAL PROPERTY New_${dependency}_ScmPath "${${dependency}_ScmPath}")
        set_property(GLOBAL PROPERTY New_${dependency}_ScmType "${${dependency}_ScmType}")
        set_property(GLOBAL PROPERTY New_${dependency}_DependenciesDescription ${DEPENDENCIES})
        set_property(GLOBAL PROPERTY New_${dependency}_Dependencies ${dependencyDependenciesIds})
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

    ParseDependencies("${DEPENDENCIES}" dependencyDependenciesIds "")
        
    # store exported info
    set_property(GLOBAL PROPERTY New_${dependency}_Name "${NAME}")
    set_property(GLOBAL PROPERTY New_${dependency}_Type "${TYPE}")
    set_property(GLOBAL PROPERTY New_${dependency}_Version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
    set_property(GLOBAL PROPERTY New_${dependency}_ScmPath "${${dependency}_ScmPath}")
    set_property(GLOBAL PROPERTY New_${dependency}_ScmType "${${dependency}_ScmType}")
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
function (_createInfoAboutExternalFlag)
    set(externalDependencies "")
    
    foreach(dep ${New_OverallDependencies})
        if(${New_${dep}_IsExternal})
            list(APPEND externalDependencies ${dep} ${New_${dep}_OverallDependencies})
            list(REMOVE_DUPLICATES externalDependencies)
        endif()
    endforeach()
    
    foreach(dep ${externalDependencies})
        set_property(GLOBAL PROPERTY New_${dep}_IsExternal "yes")
    endforeach()
    
    set_property(GLOBAL PROPERTY New_ExternalDependencies ${externalDependencies})
endfunction (_createInfoAboutExternalFlag)


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
        list(REMOVE_ITEM dependenciesToRemove ${New_OverallDependenciesNames})
    endif()
    
    foreach(dependency ${dependenciesToRemove})
        message(STATUS "Removing unused dependency sources ${dependency}")
        
        file(REMOVE_RECURSE ${DEP_SOURCES_PATH}/${${dependency}_Name})
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

function(_removeFromChachedList list value)
    set(tmp ${${list}})
    if(NOT "${tmp}" STREQUAL "")
        list(REMOVE_ITEM tmp ${value})
        set(${list} ${tmp} CACHE INTERNAL "" FORCE)
    endif()        
endfunction(_removeFromChachedList)

function(_exit reason)
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
  
