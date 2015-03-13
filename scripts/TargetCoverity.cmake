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


function(sbeAddCoverityTarget)
    sbeConfigureCoverity(isConfigured)
    
    if(NOT isConfigured)
        message(STATUS "Coverity is not configured.")
        return()
    endif()

    set(coverityBuildStarter "${COV_BUILD_TOOL};--verbose;0;--config;${COV_FILE_CONFIG};--dir;${COV_DIR_DATA}")
    
    set(COV_ANALYZE_OPTIONS 
        --enable-callgraph-metrics
        --paths 15000
        --disable-default
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
        -en OVERRUN
        -en RESOURCE_LEAK
        -en RETURN_LOCAL
        -en REVERSE_INULL
        -en REVERSE_NEGATIVE
        -en SIGN_EXTENSION
        -en SIZEOF_MISMATCH
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
    
    add_custom_target(coverity)

    # create new coverity data directory
    add_custom_command(TARGET coverity
        COMMAND ${CMAKE_COMMAND} -E remove_directory ${COV_DIR_DATA}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${COV_DIR_DATA} 
        COMMENT "Cleaning coverity data")
    # build own project under coverity
    add_custom_command(TARGET coverity
        COMMAND ${CMAKE_COMMAND} --build . --target dependencies_clean --use-stderr
        COMMAND ${CMAKE_COMMAND} --build . --target clean --use-stderr
        COMMAND ${coverityBuildStarter} ${CMAKE_COMMAND} --build . --target dependencies_force --use-stderr
        COMMAND ${coverityBuildStarter} ${CMAKE_COMMAND} --build . --use-stderr
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        COMMENT "Building Coverity for ${PROJECT_NAME}")    
    
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

function(sbeConfigureCoverity isConfigured)
    # once coverity is configured, it is not necessary to reconfigure
    if(${Coverity_IsConfigured})
        set(${isConfigured} "yes" PARENT_SCOPE)
        return()
    endif()
    
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
    
    # prefere C compiler as recomended by Coverity in cov-configue help
    set(compiler "${CMAKE_CXX_COMPILER}")
    if(NOT "" STREQUAL "${CMAKE_C_COMPILER}")
        set(compiler "${CMAKE_C_COMPILER}")
    endif()
    
    if(NOT "" STREQUAL "${compiler}")
        file(REMOVE_RECURSE ${COV_DIR_CONFIG})
        file(MAKE_DIRECTORY ${COV_DIR_CONFIG})

        get_filename_component(compilerPath "${compiler}" PATH)
        get_filename_component(compilerName "${compiler}" NAME)
        
        # in case of gnu compiler has not default name, specify its type
        set(compType "")
        if("${compilerName}" MATCHES ".*g\\+\\+")
             set(compType --comptype g++)
        endif()
        if("${compilerName}" MATCHES ".*gcc")
            set(compType --comptype gcc)
        endif()
                        
        message(STATUS "Configuring Coverity for ${compilerName} compiler...")

        execute_process(     
            COMMAND ${COV_CONFIGURE_TOOL} --verbose 0  --template ${compType} --compiler ${compilerName} --config ${COV_FILE_CONFIG}
            RESULT_VARIABLE result
            OUTPUT_VARIABLE out
            OUTPUT_STRIP_TRAILING_WHITESPACE
            )
        message(STATUS "   ${out}")
        
        if(${result} GREATER 0)
            message(FATAL_ERROR "Configuring Coverity for ${compilerName} compiler fails.")
        endif()
        
        set(${isConfigured} "yes" PARENT_SCOPE)
        set(Coverity_IsConfigured "yes" CACHE "" INTERNAL FORCE)
    endif()
endfunction()

