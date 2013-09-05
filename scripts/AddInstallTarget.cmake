if(isAddInstallTargetIncluded)
    return()
endif()

set(isAddInstallTargetIncluded yes)
set(isAddInstallCalled no)

set(InstalledTargets "")

function(addInstallTarget)
    # temporary solution. It will add only last target to project config.
    if(isAddInstallCalled)
        message(FATAL_ERROR "Function addInstallTarget can be called only one time.\nIn current implemntation it will add only latest target to install to package config file.")
    endif()
    # check install and package targets order
    if(isAddPackageCalled)
        message(FATAL_ERROR "Function addPackageTarget has to be called after function addInstallTarget.")
    endif()
    
    set(isAddInstallCalled yes PARENT_SCOPE)
    
    CMAKE_PARSE_ARGUMENTS(inst "" "Package" "Targets;IncludePathReplacement" ${ARGN})
    
     if(
        (NOT DEFINED inst_Package) OR
        (NOT DEFINED inst_Targets)
      )
        return()
    endif()
    
    set(InstalledTargets ${inst_Targets} PARENT_SCOPE)
            
    # get test target
    set(testTargets "")
    foreach(target ${inst_Targets})
        get_property(isTestTarget TARGET ${target} PROPERTY TEST)
        
        if(isTestTarget)
            list(APPEND testTargets ${target})
        endif()
    endforeach()
    
    _installTestTargets(Package ${inst_Package} Targets ${testTargets})
    
    # get ordinary targets
    set(ordinaryTargets ${inst_Targets})
    if(NOT "" STREQUAL "${testTargets}")
        list(REMOVE_ITEM ordinaryTargets ${testTargets})
    endif()
    
    _installOrdinaryTargets(Package ${inst_Package} Targets ${ordinaryTargets} IncludePathReplacement ${inst_IncludePathReplacement})
    
    # install config files
    _installConfigs(Package ${inst_Package} Targets ${ordinaryTargets})
endfunction()

function(_installTestTargets)
    CMAKE_PARSE_ARGUMENTS(tst "" "Package" "Targets" ${ARGN})
    
    if(DEFINED tst_Targets)
        install(
            TARGETS ${tst_Targets} 
            EXPORT ${tst_Name}Targets
            RUNTIME DESTINATION bin COMPONENT Binaries CONFIGURATIONS Debug | DebugWithCoverage)
    endif()
endfunction()

function(_installOrdinaryTargets)
    CMAKE_PARSE_ARGUMENTS(ord "" "Package" "Targets;IncludePathReplacement" ${ARGN})
    
    if(NOT DEFINED ord_Targets)
        return()
    endif()
    
    install(
        TARGETS ${ord_Targets}
        EXPORT ${ord_Package}Targets
        RUNTIME DESTINATION bin COMPONENT Binaries
        LIBRARY DESTINATION lib NAMELINK_SKIP COMPONENT Binaries
        ARCHIVE DESTINATION lib)
        
    foreach(target ${ord_Targets})
        _installHeaders(
            Package ${ord_Package} 
            Target ${target} 
            IncludePathReplacement ${ord_IncludePathReplacement})
    endforeach()    
endfunction()

function(_installHeaders)
    CMAKE_PARSE_ARGUMENTS(headers "" "Package;Target" "IncludePathReplacement" ${ARGN})
    
    get_property(publicHeaders TARGET ${headers_Target} PROPERTY PublicHeaders)
    
    get_property(containsDeclspec TARGET ${headers_Target} PROPERTY ContainsDeclspec)
    
    set(generatedPublicHeaders "")
    foreach(header ${publicHeaders})
        set(isReplaced "no")
        set(installPath "include/${headers_Package}")
        foreach(replacement ${headers_IncludePathReplacement})
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
        add_custom_target(declspecHeaders_${headers_Target} SOURCES ${generatedPublicHeaders})
        add_dependencies(${headers_Target} declspecHeaders_${headers_Target})
    endif()
endfunction()

function(_installConfigs)
    CMAKE_PARSE_ARGUMENTS(cfg "" "Package" "Targets" ${ARGN})
    
    install(EXPORT ${cfg_Package}Targets DESTINATION config COMPONENT Configs)
               
    set(needsDeclspec "no")
    foreach(target ${cfg_Targets})
        get_property(type TARGET ${target} PROPERTY TYPE)
        
        if("SHARED_LIBRARY" STREQUAL "${type}" OR "STATIC_LIBRARY" STREQUAL "${type}")
            list(APPEND INSTALL_LIBRARIES ${target})
        elseif("EXECUTABLE" STREQUAL "${type}")
            get_property(isTest TARGET ${target} PROPERTY TEST)
            if(isTest)
                list(APPEND INSTALL_TEST_EXECUTABLES ${target})
            else()
                list(APPEND INSTALL_EXECUTABLES ${target})
            endif()
        endif()
        
        get_property(containsDeclspec TARGET ${target} PROPERTY ContainsDeclspec)
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
	        "set(${cfg_Package}_LIBRARIES ${INSTALL_LIBRARIES})\nset(${cfg_Package}_INCLUDE_DIRS \"\${_IMPORT_PREFIX}/include/${cfg_Package}\")")
    endif()	
    if(DEFINED INSTALL_TEST_EXECUTABLES)
        set(TEST_EXECUTABLES_PART
	        "set(${cfg_Package}_TEST_EXECUTABLES ${INSTALL_TEST_EXECUTABLES})\nset(${cfg_Package}_TEST_EXECUTABLES_PATH \"\${_IMPORT_PREFIX}/bin\")")
    endif()
    if(DEFINED INSTALL_EXECUTABLES)
        set(EXECUTABLES_PART
	        "set(${cfg_Package}_EXECUTABLES ${INSTALL_EXECUTABLES})\nset(${cfg_Package}_EXECUTABLES_PATH \"\${_IMPORT_PREFIX}/bin\")")
    endif()
    if(needsDeclspec)
        set(DECLSPEC_PART "set(${cfg_Package}_CONTAINS_DECLSPEC \"yes\")")
    endif()
    
    
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfig.cmake.in "${PROJECT_BINARY_DIR}/${cfg_Package}Config.cmake" @ONLY)
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/${cfg_Package}ConfigVersion.cmake" @ONLY)
     
    # Install the Config.cmake and ConfigVersion.cmake
    install(FILES
      "${PROJECT_BINARY_DIR}/${cfg_Package}Config.cmake"
      "${PROJECT_BINARY_DIR}/${cfg_Package}ConfigVersion.cmake"
      DESTINATION config COMPONENT Configs) 

endfunction()



