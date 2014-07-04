cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED SBE_MAIN_DEPENDANT_SOURCE_DIR)
    message(FATAL_ERROR "SBE_MAIN_DEPENDANT_SOURCE_DIR has to be defined.")
endif()

if(NOT DEFINED DEP_SOURCES_PATH)
    message(FATAL_ERROR "DEP_SOURCES_PATH has to be defined to know where find dependencies.")
endif()

if(NOT DEFINED SBE_MAIN_DEPENDANT)
    message(FATAL_ERROR "SBE_MAIN_DEPENDANT has to be defined to know name of main dependant.")
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

find_program(SED_TOOL sed)
if(NOT SED_TOOL)
    message(FATAL_ERROR "error: could not find sed.")
endif()

include(${DEP_INFO_FILE} OPTIONAL)

# export all properties files    
function(ConfigureDependecies)
    foreach(dependency ${${PROJECT_NAME}_OverallDependencies})
        _configureDependency(${dependency})
    endforeach()
endfunction(ConfigureDependecies)

function(_configureDependency dependency)
    set(DependencyBuildDirectory "${DEP_SOURCES_PATH}/${dependency}/build/${TOOLCHAIN_NAME}/${CMAKE_BUILD_TYPE}")
    
    if(EXISTS "${DependencyBuildDirectory}/Makefile")
        return()
    endif()
    
    message(STATUS "Configuring dependency ${dependency}")
    # create build directory    

    file(MAKE_DIRECTORY ${DependencyBuildDirectory})
    
    # create arguments for configuring
    list(APPEND configurationArgs "--no-warn-unused-cli")
    list(APPEND configurationArgs "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    list(APPEND configurationArgs "-DSBE_MAIN_DEPENDANT_SOURCE_DIR=${SBE_MAIN_DEPENDANT_SOURCE_DIR}")
    list(APPEND configurationArgs "-DSBE_MAIN_DEPENDANT=${SBE_MAIN_DEPENDANT}")
    list(APPEND configurationArgs "-DSBE_COVERITY_CONFIGURED=${SBE_COVERITY_CONFIGURED}")
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
            cmake ${configurationArgs}
            ${DEP_SOURCES_PATH}/${${dependency}_Name}
        COMMAND ${SED_TOOL} -u -e "/Not searching for unused variables given on the command line./d"            
        COMMAND ${SED_TOOL} -u -e "s/.*/    &/"
        RESULT_VARIABLE configureResult)
    # handle configuration result
    if((${configureResult} GREATER 0) OR (NOT EXISTS ${DependencyBuildDirectory}/Makefile))
        _exit("Error during configuration of dependency ${dependency}")
    endif()
endfunction(_configureDependency)

ConfigureDependecies()
