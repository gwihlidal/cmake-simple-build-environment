cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED DEP_SOURCES_PATH)
    message(FATAL_ERROR "DEP_SOURCES_PATH has to be defined to know where are sources to install.")
endif()

if(NOT DEFINED DEP_INFO_FILE)
    message(FATAL_ERROR "DEP_INFO_FILE has to be defined to know dependecies to install.")
endif()

if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    message(FATAL_ERROR "CMAKE_TOOLCHAIN_FILE has to be defined.")
endif()

if(CMAKE_TOOLCHAIN_FILE)
    get_filename_component(TOOLCHAIN_NAME ${CMAKE_TOOLCHAIN_FILE} NAME)
    string(REPLACE ".cmake" "" TOOLCHAIN_NAME "${TOOLCHAIN_NAME}")
endif()

# if deployment path is not defined then this script is dependency deployer
# otherwise deployer already deploy dependencies, do nothing
if(NOT DEP_INST_DEPLOYMENT_PATH)
    set(DEP_INST_DEPLOYMENT_PATH "${PROJECT_BINARY_DIR}/dependencies")
    # set export directories
    set(DEP_INST_INFO_PATH "${DEP_INST_DEPLOYMENT_PATH}/info")
    set(DEP_INST_INFO_FILE "${DEP_INST_INFO_PATH}/info.cmake")
    set(DEP_INSTALL_PATH "${DEP_INST_DEPLOYMENT_PATH}/installation")
else()
    # set export directories
    set(DEP_INST_INFO_PATH "${DEP_INST_DEPLOYMENT_PATH}/info")
    set(DEP_INST_INFO_FILE "${DEP_INST_INFO_PATH}/info.cmake")
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
function(ConfigureDependecies)
    _areDependenciesChanged(areChanged)
    
    if(NOT areChanged)
        return()
    endif()
    
    _configureRequiredDependencies()
endfunction(ConfigureDependecies)

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


function(_configureRequiredDependencies)
    set(dependenciesToConfigure "")
    if(DEFINED DEP_INSTALLATION_ORDER)
        set(dependenciesToConfigure ${DEP_INSTALLATION_ORDER})
    endif()       
    
    foreach(dependency ${dependenciesToConfigure})
        _configureDependency(${dependency})
    endforeach()

endfunction(_configureRequiredDependencies)

function(_configureDependency dependency)
    message(STATUS "Configuring dependency ${dependency}")
    # create build directory    
    set(DependencyBuildDirectory "${DEP_SOURCES_PATH}/${${dependency}_Name}/build/${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}")
    file(MAKE_DIRECTORY  ${DependencyBuildDirectory})
    
    # create arguments for configuring
    list(APPEND configurationArgs "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    list(APPEND configurationArgs "-DCMAKE_INSTALL_PREFIX=${DEP_INSTALL_PATH}")
    list(APPEND configurationArgs "-DDEP_INST_DEPLOYMENT_PATH=${DEP_INST_DEPLOYMENT_PATH}")
    list(APPEND configurationArgs "-DDEP_SRC_DEPLOYMENT_PATH=${DEP_SRC_DEPLOYMENT_PATH}")
    list(APPEND configurationArgs "-DSBE_MODE=${SBE_MODE}")
    if(CMAKE_TOOLCHAIN_FILE)
       list(APPEND configurationArgs "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
    endif()
    if(RULE_LAUNCH_COMPILE)
        list(APPEND configurationArgs "-DRULE_LAUNCH_COMPILE=${RULE_LAUNCH_COMPILE}")
    endif()
    if(RULE_LAUNCH_LINK)
        list(APPEND configurationArgs "-DRULE_LAUNCH_LINK=${RULE_LAUNCH_LINK}")
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
endfunction(_configureDependency)

ConfigureDependecies()

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
