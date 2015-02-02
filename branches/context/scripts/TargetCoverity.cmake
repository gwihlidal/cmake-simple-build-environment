cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetCoverityGuard)
    return()
endif()

set(TargetCoverityGuard yes)

find_program(COV_CONFIGURE_TOOL cov-configure)
find_program(COV_BUILD_TOOL cov-build)
find_program(COV_ANALYZE_TOOL cov-analyze)
find_program(COV_FORMAT_ERRORS_TOOL cov-format-errors)
find_program(COV_MANAGE_EMIT_TOOL cov-manage-emit)

include(SBE/helpers/ContextParser)

set(COV_DIR_ROOT    ${CMAKE_CURRENT_BINARY_DIR}/coverity)
set(COV_DIR_CONFIG  ${COV_DIR_ROOT}/config)
set(COV_DIR_DATA    ${COV_DIR_ROOT}/data)
set(COV_FILE_CONFIG ${COV_DIR_CONFIG}/coverity_config)

function(sbeConfigureCoverity)
    return()
    
    # check if coverity is available on system
    if(NOT COV_CONFIGURE_TOOL)
        message(STATUS "Could not find cov-configure. Skipping coverity.")
        return()
    endif()
    if(NOT COV_BUILD_TOOL)
        message(STATUS "Could not find cov-build. Skipping coverity.")
        return()
    endif()
    if(NOT COV_ANALYZE_TOOL)
        message(STATUS "Could not find cov-analyze. Skipping coverity.")
        return()
    endif()
    if(NOT COV_FORMAT_ERRORS_TOOL)
        message(STATUS "Could not find cov-format-errors. Skipping coverity.")
        return()
    endif()
    if(NOT COV_MANAGE_EMIT_TOOL)
        message(STATUS "Could not find cov-manage-emit. Skipping coverity.")
        return()
    endif()     
    
    # create coverity configuration
    set(COV_C_COMPILER_FLAGS "")
    set(COV_CXX_COMPILER_FLAGS "")
    
    if("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
        set(COV_C_COMPTYPE "gcc")
    endif()
    
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
        set(COV_CXX_COMPTYPE "g++")
    endif()
    
    if("${CMAKE_C_COMPILER_ID}" STREQUAL "TI" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "TI")
        set(compiler "${CMAKE_CXX_COMPILER}")
        if("" STREQUAL "${compiler}")
            set(compiler "${CMAKE_C_COMPILER}")
        endif()
        get_filename_component(compilerName "${compiler}" NAME)
    endif()
    
    if(NOT "" STREQUAL "${compilerName}" AND NOT Coverity_IsConfigured)
        message(STATUS "Configuring Coverity for ${compilerName} compiler...")

        # configure coverity
        file(MAKE_DIRECTORY ${COV_DIR_CONFIG})
        file(MAKE_DIRECTORY ${COV_DIR_DATA})
    
        execute_process(     
            COMMAND cov-configure --verbose 0 --template --compiler ${compilerName} --config ${COV_FILE_CONFIG}
            COMMAND ${SED_TOOL} -u -e "s/.*/--   &/")
        if(NOT EXISTS "${COV_DIR_CONFIG}/coverity_config")
            message(FATAL_ERROR "Configuring Coverity for ${compilerName} compiler fails.")
        endif()
        
        set(Coverity_IsConfigured "yes" CACHE INTERNAL "" FORCE)
    endif()
    
    if(Coverity_IsConfigured)
        set(coverityBuildStarter "${COV_BUILD_TOOL} --verbose 0 --config ${COV_FILE_CONFIG} --dir ${COV_DIR_DATA}")
        configure_file(${CMAKE_ROOT}/Modules/SBE/tools/coverityLauncher.in "${PROJECT_BINARY_DIR}/coverityLauncher" @ONLY)
        if(DEFINED RULE_LAUNCH_COMPILE)
            set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${PROJECT_BINARY_DIR}/coverityLauncher ${RULE_LAUNCH_COMPILE}")
        else()
            set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${PROJECT_BINARY_DIR}/coverityLauncher")
        endif()    
    endif()    
endfunction()

function(sbeAddCoverityTarget)
    return()
    
    set(COV_ANALYZE_OPTIONS 
        --info
        --enable-callgraph-metrics
        --paths 15000
        --disable-default
        --disable UNIMPL_FUNCTIONS
        -en ARRAY_VS_SINGLETON
        -en BAD_ALLOC_ARITHMETIC
        -en BAD_ALLOC_STRLEN
        -en BAD_COMPARE
        -en ARRAY_VS_SINGLETON
        -en BAD_ALLOC_ARITHMETIC
        -en BAD_ALLOC_STRLEN
        -en BAD_COMPARE
        -en BAD_FREE
        -en CHAR_IO
        -en CHECKED_RETURN
        -en DEADCODE
        -en EVALUATION_ORDER
        -en FORWARD_NULL
        -en INFINITE_LOOP
        -en MISSING_BREAK
        -en MISSING_RETURN
        -en NEGATIVE_RETURNS
        -en NO_EFFECT
        -en NULL_RETURNS
        -en OVERRUN_STATIC
        -en OVERRUN_DYNAMIC
        -en RESOURCE_LEAK
        -en RETURN_LOCAL
        -en REVERSE_INULL
        -en REVERSE_NEGATIVE
        -en SIGN_EXTENSION
        -en SIZECHECK
        -en STACK_USE
        --checker-option STACK_USE:max_total_use_bytes:65536
        --checker-option STACK_USE:max_single_base_use_bytes:32768
        -en UNINIT
        -en UNREACHABLE
        -en UNUSED_VALUE
        -en USE_AFTER_FREE
        -en VARARGS
        -en BAD_OVERRIDE
        -en CTOR_DTOR_LEAK
        -en DELETE_ARRAY
        -en DELETE_VOID
        -en INVALIDATE_ITERATOR
        -en PASS_BY_VALUE
        -en STREAM_FORMAT_STATE
        -en UNCAUGHT_EXCEPT
        -en UNINIT_CTOR
        -en WRAPPER_ESCAPE
        -en CHROOT
        -en OPEN_ARGS
        -en SECURE_TEMP
        -en TOCTOU
        -en ATOMICITY
        -en LOCK
        -en MISSING_LOCK
        -en ORDER_REVERSAL
        -en SLEEP)
    
    if(NOT Coverity_IsConfigured)
        sbeConfigureCoverity()
    endif()
    
    if(NOT Coverity_IsConfigured)
        return()
    endif()
    
    add_custom_target(coverity)
            
    foreach(dep ${OverallDependencies})
        sbeGetPackageBuildPath(${dep} buildPath)
        
        file(STRINGS ${buildPath}/CMakeCache.txt isCoverityConfigured REGEX "Coverity_IsConfigured")
        string(REGEX REPLACE ".*:.*=" "" isCoverityConfigured "${isCoverityConfigured}")
        
        if(NOT isCoverityConfigured)
            message(STATUS "   Enabling coverity in ${dep}")
            
            sbeGetPackageLocalPath(${dep} packagePath)
            execute_process(
                COMMAND cmake -E chdir ${buildPath} 
                    cmake -DCoverity_IsRequestedByDependant=yes
                    ${packagePath}
                COMMAND ${SED_TOOL} -u -e "s/.*/      &/"
                RESULT_VARIABLE configureResult)            
        endif()
        
        sbeGetPackageCoverityPath(${dep} coverityPath)
        
        add_custom_command(TARGET coverity     
            COMMAND ${COV_MANAGE_EMIT_TOOL} --dir ${COV_DIR_DATA} add ${coverityPath}/data
            COMMENT "Adding ${dep} for analyze")
    endforeach()
    
    add_custom_command(TARGET coverity     
        COMMAND ${COV_ANALYZE_TOOL} 
            --config ${COV_FILE_CONFIG} 
            --dir ${COV_DIR_DATA} 
            ${COV_ANALYZE_OPTIONS}
        VERBATIM
        COMMENT "Analyzing coverity..")
    
    add_custom_command(TARGET coverity     
        COMMAND ${COV_FORMAT_ERRORS_TOOL} --dir ${COV_DIR_DATA}
        COMMENT "Formating coverity errors")        
endfunction()

#cmake_minimum_required(VERSION 2.8)
#
#if(SBE_COVERITY_CONFIGURED)
#    return()
#endif()
#
#set(SBE_COVERITY_CONFIGURED "yes")
#
#find_program(COV_CONFIGURE_TOOL cov-configure)
#if(NOT COV_CONFIGURE_TOOL)
#    message(STATUS "Could not find cov-configure. Skipping coverity.")
#    return()
#endif()
#find_program(COV_BUILD_TOOL cov-build)
#if(NOT COV_BUILD_TOOL)
#    message(STATUS "Could not find cov-build. Skipping coverity.")
#    return()
#endif()
#find_program(COV_ANALYZE_TOOL cov-analyze)
#if(NOT COV_ANALYZE_TOOL)
#    message(STATUS "Could not find cov-analyze. Skipping coverity.")
#    return()
#endif()
#find_program(COV_FORMAT_ERRORS_TOOL cov-format-errors)
#if(NOT COV_FORMAT_ERRORS_TOOL)
#    message(STATUS "Could not find cov-format-errors. Skipping coverity.")
#    return()
#endif()
#
#find_program(SED_TOOL sed)
#if(NOT SED_TOOL)
#    message(FATAL_ERROR "error: could not find sed.")
#endif()
#
#set(COV_ANALYZE_OPTIONS 
#--info
#--enable-callgraph-metrics
#--paths 15000
#--disable-default
#--disable UNIMPL_FUNCTIONS
#-en ARRAY_VS_SINGLETON
#-en BAD_ALLOC_ARITHMETIC
#-en BAD_ALLOC_STRLEN
#-en BAD_COMPARE
#-en ARRAY_VS_SINGLETON
#-en BAD_ALLOC_ARITHMETIC
#-en BAD_ALLOC_STRLEN
#-en BAD_COMPARE
#-en BAD_FREE
#-en CHAR_IO
#-en CHECKED_RETURN
#-en DEADCODE
#-en EVALUATION_ORDER
#-en FORWARD_NULL
#-en INFINITE_LOOP
#-en MISSING_BREAK
#-en MISSING_RETURN
#-en NEGATIVE_RETURNS
#-en NO_EFFECT
#-en NULL_RETURNS
#-en OVERRUN_STATIC
#-en OVERRUN_DYNAMIC
#-en RESOURCE_LEAK
#-en RETURN_LOCAL
#-en REVERSE_INULL
#-en REVERSE_NEGATIVE
#-en SIGN_EXTENSION
#-en SIZECHECK
#-en STACK_USE
#--checker-option STACK_USE:max_total_use_bytes:65536
#--checker-option STACK_USE:max_single_base_use_bytes:32768
#-en UNINIT
#-en UNREACHABLE
#-en UNUSED_VALUE
#-en USE_AFTER_FREE
#-en VARARGS
#-en BAD_OVERRIDE
#-en CTOR_DTOR_LEAK
#-en DELETE_ARRAY
#-en DELETE_VOID
#-en INVALIDATE_ITERATOR
#-en PASS_BY_VALUE
#-en STREAM_FORMAT_STATE
#-en UNCAUGHT_EXCEPT
#-en UNINIT_CTOR
#-en WRAPPER_ESCAPE
#-en CHROOT
#-en OPEN_ARGS
#-en SECURE_TEMP
#-en TOCTOU
#-en ATOMICITY
#-en LOCK
#-en MISSING_LOCK
#-en ORDER_REVERSAL
#-en SLEEP)
#
#set(COV_DIR_ROOT    ${CMAKE_CURRENT_BINARY_DIR}/coverity)
#set(COV_DIR_CONFIG  ${COV_DIR_ROOT}/config)
#set(COV_DIR_DATA    ${COV_DIR_ROOT}/data)
#set(COV_FILE_CONFIG ${COV_DIR_CONFIG}/coverity_config)
#
# create coverity configuration
#set(COV_C_COMPILER_FLAGS "")
#set(COV_CXX_COMPILER_FLAGS "")
#
#if("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
#    set(COV_C_COMPTYPE "gcc")
#endif()
#
#if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
#    set(COV_CXX_COMPTYPE "g++")
#endif()
#
#if("${CMAKE_C_COMPILER_ID}" STREQUAL "TI")
#    
#    get_property(dirs DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)
#    list(REMOVE_DUPLICATES dirs)
#    
#    list(APPEND COV_C_COMPILER_FLAGS --)
#    foreach(dir ${dirs})
#          list(APPEND COV_C_COMPILER_FLAGS -I ${dir})
#    endforeach()
#
#    
#    set(COV_C_COMPTYPE "ti")
#endif()
#
#if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "TI")
#    
#    get_property(dirs DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)
#    list(REMOVE_DUPLICATES dirs)
#    
#    list(APPEND COV_CXX_COMPILER_FLAGS --)
#    foreach(dir ${dirs})
#          list(APPEND COV_CXX_COMPILER_FLAGS -I ${dir})
#    endforeach()
#
#    set(COV_CXX_COMPTYPE "ti_cxx")
#endif()
#    
#if("" STREQUAL "${COV_C_COMPTYPE}" AND "" STREQUAL "${COV_CXX_COMPTYPE}")
#    add_custom_target(coverity COMMENT "Coverity analyze is not possible to perform for given compiler.")
#    set(coverityBuildStarter "")
#    return()
#endif()
#     
# coverity build command
#set(coverityBuildStarter "${COV_BUILD_TOOL} --verbose 0 --config ${COV_FILE_CONFIG} --dir ${COV_DIR_DATA}")
#configure_file(${CMAKE_ROOT}/Modules/SBE/tools/coverityLauncher.in "${PROJECT_BINARY_DIR}/coverityLauncher" @ONLY)
#if(DEFINED RULE_LAUNCH_COMPILE)
#    set(RULE_LAUNCH_COMPILE "${PROJECT_BINARY_DIR}/coverityLauncher ${RULE_LAUNCH_COMPILE}")
#else()
#    set(RULE_LAUNCH_COMPILE "${PROJECT_BINARY_DIR}/coverityLauncher")
#endif()    
#
# create dirs
#file(MAKE_DIRECTORY ${COV_DIR_CONFIG})
#file(MAKE_DIRECTORY ${COV_DIR_DATA})
#
#if(NOT "" STREQUAL "${COV_C_COMPTYPE}" AND NOT "yes" STREQUAL "${Coverity_IsConfiguredForC}")
#    message(STATUS "Configuring Coverity for C compiler...")
#    execute_process(     
#        COMMAND cov-configure --verbose 0 --compiler ${CMAKE_C_COMPILER} --comptype ${COV_C_COMPTYPE} --config ${COV_FILE_CONFIG} ${COV_C_COMPILER_FLAGS}
#        COMMAND ${SED_TOOL} -u -e "s/.*/   &/")
#    if(NOT EXISTS "${COV_DIR_CONFIG}/${COV_C_COMPTYPE}-config-0")
#        message(FATAL_ERROR "Configuring Coverity for C compiler fails.")
#    endif()
#    
#    set(Coverity_IsConfiguredForC "yes" CACHE INTERNAL "" FORCE)      
#endif()    
#
#if(NOT "" STREQUAL "${COV_CXX_COMPTYPE}" AND NOT "yes" STREQUAL "${Coverity_IsConfiguredForCxx}")
#    message(STATUS "Configuring Coverity for CXX compiler...")
#    execute_process(     
#        COMMAND ${COV_CONFIGURE_TOOL} --verbose 0 --compiler ${CMAKE_CXX_COMPILER} --comptype ${COV_CXX_COMPTYPE} --config ${COV_FILE_CONFIG} ${COV_CXX_COMPILER_FLAGS} 
#        COMMAND ${SED_TOOL} -u -e "s/.*/   &/")
#    if(NOT EXISTS "${COV_DIR_CONFIG}/${COV_CXX_COMPTYPE}-config-0")
#        message(FATAL_ERROR "Configuring Coverity for CXX compiler fails.")
#    endif()
#    
#    set(Coverity_IsConfiguredForCxx "yes" CACHE INTERNAL "" FORCE)
#endif()
#
#add_custom_target(coverity)
#
#add_custom_command(TARGET coverity     
#    COMMAND make
#    COMMENT "Building coverity")
#
# add_custom_command(TARGET coverity     
#    COMMAND ${COV_ANALYZE_TOOL} 
#        --config ${COV_FILE_CONFIG} 
#        --dir ${COV_DIR_DATA} 
#        ${COV_ANALYZE_OPTIONS}
#    VERBATIM
#    COMMENT "Analyzing coverity..")
#
#add_custom_command(TARGET coverity     
#    COMMAND ${COV_FORMAT_ERRORS_TOOL} --dir ${COV_DIR_DATA}
#    COMMENT "Formating coverity errors")
#
#
