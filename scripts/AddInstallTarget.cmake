if(isAddInstallTargetIncluded)
    return()
endif()

set(isAddInstallTargetIncluded yes)
set(isAddInstallCalled no)

function(addInstallTarget)
    # temporary solution. It will add only last target to project config.
    if(isAddInstallCalled)
        message(FATAL_ERROR "Function addInstallTarget can be called only one time.\nIn current implemntation it will add only latest target to install to package config file.")
    endif()
    set(isAddInstallCalled yes PARENT_SCOPE)
    
    CMAKE_PARSE_ARGUMENTS(inst "" "PACKAGE_NAME" "TARGETS_NAMES;INCLUDE_PATH_REPLACE" ${ARGN})
    
     if(
        (NOT DEFINED inst_PACKAGE_NAME) OR
        (NOT DEFINED inst_TARGETS_NAMES)
      )
        return()
    endif()
    
    # get test target
    set(testTargets "")
    foreach(target ${inst_TARGETS_NAMES})
        get_property(isTestTarget TARGET ${target} PROPERTY SBE_IS_TEST_TARGET)
        
        if(isTestTarget)
            list(APPEND testTargets ${target})
        endif()
    endforeach()
    
    _installTestTargets(PACKAGE_NAME ${inst_PACKAGE_NAME} TARGETS_NAMES ${testTargets})
    
    # get ordinary targets
    set(ordinaryTargets ${inst_TARGETS_NAMES})
    if(NOT "" STREQUAL "${testTargets}")
        list(REMOVE_ITEM ordinaryTargets ${testTargets})
    endif()
    
    _installOrdinaryTargets(PACKAGE_NAME ${inst_PACKAGE_NAME} TARGETS_NAMES ${ordinaryTargets} INCLUDE_PATH_REPLACE ${inst_INCLUDE_PATH_REPLACE})
    
    # install config files
    _installConfigs(PACKAGE_NAME ${inst_PACKAGE_NAME} TARGETS_NAMES ${ordinaryTargets})
endfunction()

function(_installTestTargets)
    CMAKE_PARSE_ARGUMENTS(tst "" "PACKAGE_NAME" "TARGETS_NAMES" ${ARGN})
    
    if(DEFINED tst_TARGETS_NAMES)
        install(
            TARGETS ${tst_TARGETS_NAMES} 
            EXPORT ${tst_Name}Targets
            RUNTIME DESTINATION bin COMPONENT Binaries CONFIGURATIONS Debug | DebugWithCoverage)    
    endif()
endfunction()

function(_installOrdinaryTargets)
    CMAKE_PARSE_ARGUMENTS(ord "" "PACKAGE_NAME" "TARGETS_NAMES;INCLUDE_PATH_REPLACE" ${ARGN})
    
    if(NOT DEFINED ord_TARGETS_NAMES)
        return()
    endif()
    
    install(
        TARGETS ${ord_TARGETS_NAMES}
        EXPORT ${ord_PACKAGE_NAME}Targets
        RUNTIME DESTINATION bin COMPONENT Binaries
        LIBRARY DESTINATION lib NAMELINK_SKIP COMPONENT Binaries
        ARCHIVE DESTINATION lib)

    foreach(target ${ord_TARGETS_NAMES})
        _installHeaders(
            PACKAGE_NAME ${ord_PACKAGE_NAME} 
            TARGET ${target} 
            INCLUDE_PATH_REPLACE ${ord_INCLUDE_PATH_REPLACE})
    endforeach()    
endfunction()

function(_installHeaders)
    CMAKE_PARSE_ARGUMENTS(headers "" "PACKAGE_NAME;TARGET" "INCLUDE_PATH_REPLACE" ${ARGN})
    
    get_property(publicHeaders TARGET ${headers_TARGET} PROPERTY SBE_PUBLIC_HEADERS)
    
    get_property(containsDeclspec TARGET ${headers_TARGET} PROPERTY SBE_CONTAINS_DECLSPEC)
    
    set(generatedPublicHeaders "")
    foreach(header ${publicHeaders})
        set(isReplaced "no")
        set(installPath "include/${headers_PACKAGE_NAME}")
        foreach(replacement ${headers_INCLUDE_PATH_REPLACE})
            if(NOT isReplaced)
                string(REGEX REPLACE "[ \t]*->[ \t]*" ";" replacements "${replacement}")
                list(GET replacements 0 matchExpression)
                list(GET replacements 1 headerDirectory)
                if("${header}" MATCHES "^${matchExpression}$")
                    set(installPath "${installPath}/${headerDirectory}")
                    set(isReplaced "yes")
                endif()
            endif()
        endforeach() 
        
        if(containsDeclspec)
            GET_FILENAME_COMPONENT(headerFile "${header}" NAME)
            
            set(generatedHeaderFile "${PROJECT_BINARY_DIR}/GeneratedSources/${installPath}/${headerFile}")
            
            add_custom_command(OUTPUT ${generatedHeaderFile}
                COMMAND ${CMAKE_COMMAND} -DSOURCE=${PROJECT_SOURCE_DIR}/${header} -DDESTINATION=${generatedHeaderFile} -P ${CMAKE_ROOT}/Modules/SBE/helpers/ChangeExportToImport.cmake 
                DEPENDS ${PROJECT_SOURCE_DIR}/${header})

            install(FILES ${generatedHeaderFile} DESTINATION ${installPath} COMPONENT Headers OPTIONAL)
                
            list(APPEND generatedPublicHeaders ${generatedHeaderFile})
        else()
            install(FILES ${header} DESTINATION ${installPath} COMPONENT Headers)
        endif()  
    endforeach()
    
    if(containsDeclspec AND NOT "" STREQUAL "${generatedPublicHeaders}")
        add_custom_target(declspecHeaders_${headers_TARGET} SOURCES ${generatedPublicHeaders})
        add_dependencies(${headers_TARGET} declspecHeaders_${headers_TARGET})
    endif()
endfunction()

function(_installConfigs)
    CMAKE_PARSE_ARGUMENTS(cfg "" "PACKAGE_NAME" "TARGETS_NAMES" ${ARGN})
    
    install(EXPORT ${cfg_PACKAGE_NAME}Targets DESTINATION config COMPONENT Configs)
               
    set(needsDeclspec "no")
    foreach(target ${cfg_TARGETS_NAMES})
        get_property(type TARGET ${target} PROPERTY SBE_TYPE)
        
        if("Library" STREQUAL "${type}")
            list(APPEND INSTALL_LIBRARIES ${target})
        elseif("Executable" STREQUAL "${type}")
            list(APPEND INSTALL_EXECUTABLES ${target})
        elseif("Test Executable" STREQUAL "${type}")
            list(APPEND INSTALL_TEST_EXECUTABLES ${target})
            message("test [${target}]")
        endif()
        
        get_property(containsDeclspec TARGET ${target} PROPERTY SBE_CONTAINS_DECLSPEC)
        if(containsDeclspec)
            set(needsDeclspec "yes")    
        endif()
    endforeach()
    
    set(LIBRARIES_PART "")
    set(DECLSPEC_PART "")
    set(EXECUTABLES_PART "")
    set(TEST_EXECUTABLES_PART "")
    if(DEFINED INSTALL_LIBRARIES)
	    set(LIBRARIES_PART 
	        "set(${cfg_PACKAGE_NAME}_LIBRARIES ${INSTALL_LIBRARIES})\nset(${cfg_PACKAGE_NAME}_INCLUDE_DIRS \"\${_IMPORT_PREFIX}/include/${cfg_PACKAGE_NAME}\")")
    endif()	
    if(DEFINED INSTALL_TEST_EXECUTABLES)
        set(TEST_EXECUTABLES_PART
	        "set(${cfg_PACKAGE_NAME}_TEST_EXECUTABLES ${INSTALL_TEST_EXECUTABLES})\nset(${cfg_PACKAGE_NAME}_TEST_EXECUTABLES_PATH \"\${_IMPORT_PREFIX}/bin\")")
    endif()
    if(DEFINED INSTALL_EXECUTABLES)
        set(EXECUTABLES_PART
	        "set(${cfg_PACKAGE_NAME}_EXECUTABLES ${INSTALL_EXECUTABLES})\nset(${cfg_PACKAGE_NAME}_EXECUTABLES_PATH \"\${_IMPORT_PREFIX}/bin\")")
    endif()
    if(needsDeclspec)
        set(DECLSPEC_PART "set(${cfg_PACKAGE_NAME}_CONTAINS_DECLSPEC \"yes\")")
    endif()
    
    
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfig.cmake.in "${PROJECT_BINARY_DIR}/${cfg_PACKAGE_NAME}Config.cmake" @ONLY)
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/${cfg_PACKAGE_NAME}ConfigVersion.cmake" @ONLY)
     
    # Install the Config.cmake and ConfigVersion.cmake
    install(FILES
      "${PROJECT_BINARY_DIR}/${cfg_PACKAGE_NAME}Config.cmake"
      "${PROJECT_BINARY_DIR}/${cfg_PACKAGE_NAME}ConfigVersion.cmake"
      DESTINATION config COMPONENT Configs) 

endfunction()



