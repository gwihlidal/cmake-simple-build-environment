cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED DEP_SOURCES_PATH)
    message(FATAL_ERROR "DEP_SOURCES_PATH has to be defined to know where are sources to install.")
endif()

if(NOT DEFINED DEP_INFO_FILE)
    message(FATAL_ERROR "DEP_INFO_FILE has to be defined to know dependecies to install.")
endif()

if("${CMAKE_GENERATOR}" STREQUAL "Unix Makefiles")
    set(DEP_MAKE_COMMAND make -s --no-print-directory)
elseif("${CMAKE_GENERATOR}" MATCHES "Visual Studio .*" OR "${CMAKE_GENERATOR}" MATCHES "NMake Makefiles.*")
    set(DEP_MAKE_COMMAND nmake /C /S)
    set(DEP_CMAKE_GENERATOR -G "NMake Makefiles")
else()
    message(FATAL_ERROR "Don't know which command to use to make and install dependencies for \"${CMAKE_SYSTEM_NAME}\" and \"${CMAKE_GENERATOR}\".")
endif()

set(DEP_ARCHITECTURE ${CMAKE_SYSTEM_PROCESSOR})

# only to suppress waring "Not used CMAKE_TOOLCHAIN_FILE"
if(CMAKE_TOOLCHAIN_FILE)
endif()

# if deployment path is not defined then this script is dependency deployer
# otherwise deployer already deploy dependencies, do nothing
if(NOT DEP_INST_DEPLOYMENT_PATH)
    set(DEP_INST_DEPLOYMENT_PATH "${PROJECT_BINARY_DIR}/dependencies")
    # set export directories
    set(DEP_INST_INFO_PATH "${DEP_INST_DEPLOYMENT_PATH}/info")
    set(DEP_INST_INFO_FILE "${DEP_INST_INFO_PATH}/info.cmake")
    set(DEP_BUILD_PATH "${DEP_INST_DEPLOYMENT_PATH}/build")
    set(DEP_INSTALL_PATH "${DEP_INST_DEPLOYMENT_PATH}/installation")
else()
    # set export directories
    set(DEP_INST_INFO_PATH "${DEP_INST_DEPLOYMENT_PATH}/info")
    set(DEP_INST_INFO_FILE "${DEP_INST_INFO_PATH}/info.cmake")
    set(DEP_BUILD_PATH "${DEP_INST_DEPLOYMENT_PATH}/build")
    set(DEP_INSTALL_PATH "${DEP_INST_DEPLOYMENT_PATH}/installation")
    
    return()    
endif()

find_program(SED_TOOL sed)
if(NOT SED_TOOL)
    message(FATAL_ERROR "error: could not find sed.")
endif()

# create export directories    
if(NOT EXISTS "${DEP_INST_INFO_PATH}")
    file(MAKE_DIRECTORY "${DEP_INST_INFO_PATH}")
endif()

if(NOT EXISTS "${DEP_INSTALL_PATH}")
    file(MAKE_DIRECTORY "${DEP_INSTALL_PATH}")
endif()

include(${DEP_INFO_FILE} OPTIONAL)
include(${DEP_INST_INFO_FILE} OPTIONAL)

# export all properties files    
function(InstallDependecies)
    _areDependenciesChanged(areChanged)
    
    if(NOT areChanged)
        return()
    endif()
    
    _uninstallUnusedDependencies()
    
    _installRequiredDependencies()
    
    _storeInstalledDependencies()
endfunction(InstallDependecies)

function(_areDependenciesChanged areChanged)
    set(oldDep "")
    if(DEFINED INSTALLED_DEPENDENCIES)
        set(oldDep ${INSTALLED_DEPENDENCIES})
    endif()
    
    set(newDep "")
    if(DEFINED DEP_INSTALLATION_ORDER)
        set(newDep ${DEP_INSTALLATION_ORDER})
    endif()        
            
    list(SORT oldDep)
    list(SORT newDep)
    
    if ("${oldDep}" STREQUAL "${newDep}")
        set(${areChanged} "no" PARENT_SCOPE)
    else()
        set(${areChanged} "yes" PARENT_SCOPE)
    endif()
endfunction (_areDependenciesChanged)

function(_uninstallUnusedDependencies)
    
    set(dependenciesToRemove "")
    if(DEFINED INSTALLED_DEPENDENCIES)
        set(dependenciesToRemove ${INSTALLED_DEPENDENCIES})
    endif()
    
    set(requiredDependencies "")
    if(DEFINED DEP_INSTALLATION_ORDER)
        set(requiredDependencies ${DEP_INSTALLATION_ORDER})
    endif()       
    
    list(REMOVE_ITEM dependenciesToRemove ${requiredDependencies})
    
    foreach(dependency ${dependenciesToRemove})
        message(STATUS "uninstalling unused dependency ${dependency}")
        
        set(DependencyBuildDirectory "${${dependency}_BuildPath}/build")
        execute_process(
            COMMAND cmake -E chdir ${DependencyBuildDirectory} cmake -P cmake_uninstall.cmake
            COMMAND ${SED_TOOL} -u -e "s/.*/    &/"
            ERROR_VARIABLE err)
        # handle error    
        if(NOT "${err}" STREQUAL "")
            message(FATAL_ERROR "Error during uninstallation of dependency ${dependency}\n${err}")
        endif()
        
        file(REMOVE_RECURSE ${${dependency}_BuildPath})
    endforeach()

endfunction(_uninstallUnusedDependencies)

function(_installRequiredDependencies)
    set(installedDependencies "")
    if(DEFINED INSTALLED_DEPENDENCIES)
        set(installedDependencies ${INSTALLED_DEPENDENCIES})
    endif()
    
    set(dependenciesToInstall "")
    if(DEFINED DEP_INSTALLATION_ORDER)
        set(dependenciesToInstall ${DEP_INSTALLATION_ORDER})
    endif()       
    
    if (NOT "" STREQUAL "${installedDependencies}")
        list(REMOVE_ITEM dependenciesToInstall ${installedDependencies})
    endif()        

    foreach(dependency ${dependenciesToInstall})
        _installDependency(${dependency})
    endforeach()

endfunction(_installRequiredDependencies)

function(_installDependency dependency)
    message(STATUS "Installing dependency ${dependency}")
    # create build directory    
    set(DependencyBuildDirectory "${DEP_BUILD_PATH}/${${dependency}_Name}/build")
    file(MAKE_DIRECTORY  ${DependencyBuildDirectory})
    
    # create arguments for configuring
    list(APPEND configurationArgs "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    list(APPEND configurationArgs "-DCMAKE_INSTALL_PREFIX=${DEP_INSTALL_PATH}")
    list(APPEND configurationArgs "-DDEP_INST_DEPLOYMENT_PATH=${DEP_INST_DEPLOYMENT_PATH}")
    list(APPEND configurationArgs "-DDEP_SRC_DEPLOYMENT_PATH=${DEP_SRC_DEPLOYMENT_PATH}")
    if(CMAKE_TOOLCHAIN_FILE)
       list(APPEND configurationArgs "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
    endif()

    # configure dependency
    execute_process(
        COMMAND cmake -E chdir ${DependencyBuildDirectory} 
            cmake ${DEP_CMAKE_GENERATOR}
            ${DEP_SOURCES_PATH}/${${dependency}_Name} 
            ${configurationArgs}
        COMMAND ${SED_TOOL} -u -e "s/.*/    &/"            
        RESULT_VARIABLE configureResult)
    # handle configuration result
    if((${configureResult} GREATER 0) OR (NOT EXISTS ${DependencyBuildDirectory}/Makefile))
        _exit("Error during configuration of dependency ${dependency}")
    endif()

    set(startCoverityBuild "")
    
    if(NOT "Project" STREQUAL "${${dependency}_Type}")
        set(startCoverityBuild ${coverityBuildStarter})
    endif()
    
    # install dependency
    execute_process(
        COMMAND cmake -E chdir ${DependencyBuildDirectory} ${startCoverityBuild} ${DEP_MAKE_COMMAND} install
        COMMAND ${SED_TOOL} -u -e "s/.*/    &/"
        RESULT_VARIABLE installResult)
    # handle install result    
    if((${installResult} GREATER 0) OR (NOT EXISTS ${DependencyBuildDirectory}/install_manifest.txt))
        _exit("Error during installation of dependency ${dependency}")
    endif()
endfunction(_installDependency)

function(_storeInstalledDependencies)
    set(info "")

    foreach(installedDependency ${DEP_INSTALLATION_ORDER})
        list(APPEND info "list(APPEND INSTALLED_DEPENDENCIES ${installedDependency})\n")
        list(APPEND info "set(${installedDependency}_BuildPath ${DEP_BUILD_PATH}/${${installedDependency}_Name})\n")
    endforeach()
    
    list(APPEND info "list(REMOVE_DUPLICATES INSTALLED_DEPENDENCIES)\n")

    file(WRITE ${DEP_INST_INFO_FILE} ${info})
endfunction(_storeInstalledDependencies)

InstallDependecies()

foreach(dependecy ${OverallDependencies})
    unset(${dependecy}_Name)
    unset(${dependecy}_Type)
    unset(${dependecy}_Version)
    unset(${dependecy}_SvnPath)
    unset(${dependecy}_Dependencies)
    unset(${dependecy}_IsExported)
endforeach()
unset(OverallDependencies)

foreach(dependecy ${DEP_INSTALLATION_ORDER})
    unset(${dependecy}_BuildPath)
endforeach()
unset(DEP_INSTALLATION_ORDER)

unset(INSTALLED_DEPENDENCIES)
    












