if(isAddInstallTargetIncluded)
    return()
endif()

include(CMakeParseArguments)
include(SBE/AddBinaryTargets)


# suppress warnings
if("" STREQUAL "${DEP_INST_DEPLOYMENT_PATH}")
endif()
if("" STREQUAL "${DEP_SRC_DEPLOYMENT_PATH}")
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
    
    CMAKE_PARSE_ARGUMENTS(inst "" "Package" "IncludePaths;Headers;Files;Targets;IncludePathReplacement;FilePathReplacement" ${ARGN})
    
     if(
        (NOT DEFINED inst_Package) OR
        ((NOT DEFINED inst_Targets) AND (NOT DEFINED inst_Files) AND (NOT DEFINED inst_Headers))
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
    
    # get mock target
    set(mockTargets "")
    set(mockedTargets "")
    foreach(target ${inst_Targets})
        get_property(isMockTarget TARGET ${target} PROPERTY IsMock)
        
        if(isMockTarget)
            list(APPEND mockTargets ${target})
            get_property(mockedTarget TARGET ${target} PROPERTY MockedName)
            list(APPEND mockedTargets ${mockedTarget})
        endif()
    endforeach()
    
    _installMockTargets(Package ${inst_Package} Targets ${mockTargets} IncludePathReplacement ${inst_IncludePathReplacement})
    
    # get ordinary targets
    set(ordinaryTargets ${inst_Targets})
    if(NOT "" STREQUAL "${testTargets}")
        list(REMOVE_ITEM ordinaryTargets ${testTargets})
    endif()
    if(NOT "" STREQUAL "${mockTargets}")
        list(REMOVE_ITEM ordinaryTargets ${mockTargets})
    endif()
    
    if(NOT "Unit Test Framework" STREQUAL "${TYPE}")
        # get not mocked libraries and create mock target for them
        set(librariesToMock ${ordinaryTargets})
        foreach(target ${ordinaryTargets})
            get_property(type TARGET ${target} PROPERTY TYPE)
            
            if("SHARED_LIBRARY" STREQUAL "${type}" OR "STATIC_LIBRARY" STREQUAL "${type}")
                list(FIND mockedTargets ${target} found)
                
                if(${found} GREATER -1)
                    list(REMOVE_ITEM librariesToMock ${target})
                endif()
            else()
                list(REMOVE_ITEM librariesToMock ${target})
            endif()
        endforeach()
        # add mock for not mocked libraries
        foreach(target ${librariesToMock})
            get_property(usedObjectLibraries TARGET ${target} PROPERTY UsedObjectLibraries)
            sbeAddMockLibrary(Name Mock${target} Objects ${usedObjectLibraries})
            _installMockTargets(Package ${inst_Package} Targets Mock${target})
            list(APPEND inst_Targets Mock${target})
        endforeach()
     endif()
    
    _installOrdinaryTargets(Package ${inst_Package} Targets ${ordinaryTargets} IncludePathReplacement ${inst_IncludePathReplacement})
    
    _installHeaders(Headers ${inst_Headers} IncludePathReplacement ${inst_IncludePathReplacement})
    
    _installFiles(Files ${inst_Files} FilePathReplacement ${inst_FilePathReplacement})
    
    _installConfigs(Package ${inst_Package} Targets ${inst_Targets} IncludePaths ${inst_IncludePaths} IncludePathReplacement ${inst_IncludePathReplacement})
endfunction()

function(_installTestTargets)
    CMAKE_PARSE_ARGUMENTS(tst "" "Package" "Targets" ${ARGN})
    
    if(DEFINED tst_Targets)
        install(
            TARGETS ${tst_Targets} 
            EXPORT ${tst_Name}Targets
            RUNTIME DESTINATION bin COMPONENT Distribution CONFIGURATIONS Debug | DebugWithCoverage)
    endif()
endfunction()

function(_installMockTargets)
    CMAKE_PARSE_ARGUMENTS(mock "" "Package" "Targets;IncludePathReplacement" ${ARGN})
    
    if(NOT DEFINED mock_Targets)
        return()
    endif()
    
    install(
        TARGETS ${mock_Targets}
        EXPORT ${mock_Package}Targets
        RUNTIME DESTINATION bin COMPONENT Mocks
        LIBRARY DESTINATION lib/mock COMPONENT Mocks
        ARCHIVE DESTINATION lib/mock COMPONENT Mocks)
        
    foreach(target ${mock_Targets})
        _installHeaders(
            Target ${target} 
            IncludePathReplacement ${mock_IncludePathReplacement})
    endforeach()    
endfunction()

function(_installOrdinaryTargets)
    CMAKE_PARSE_ARGUMENTS(ord "" "Package" "Targets;IncludePathReplacement" ${ARGN})
    
    if(NOT DEFINED ord_Targets)
        return()
    endif()
    
    install(
        TARGETS ${ord_Targets}
        EXPORT ${ord_Package}Targets
        RUNTIME DESTINATION bin COMPONENT Distribution
        LIBRARY DESTINATION lib COMPONENT Distribution
        ARCHIVE DESTINATION lib)
        
    foreach(target ${ord_Targets})
        _installHeaders(
            Target ${target} 
            IncludePathReplacement ${ord_IncludePathReplacement})
    endforeach()    
endfunction()

function (_installFiles)
    CMAKE_PARSE_ARGUMENTS(files "" "" "Files;FilePathReplacement" ${ARGN})
    
    if(NOT DEFINED files_Files)
        return()
    endif()
    
    foreach(file ${files_Files})
        set(isReplaced "no")
        set(installPath "")
        foreach(replacement ${files_FilePathReplacement})
            if(NOT isReplaced)
                string(REGEX REPLACE "[ \t]*->[ \t]*" ";" replacements "${replacement}")
                list(GET replacements 0 matchExpression)
                list(GET replacements 1 fileDirectory)
                if("${file}" MATCHES "^${matchExpression}$")
                    set(installPath "${fileDirectory}")
                    set(isReplaced "yes")
                endif()
            endif()
        endforeach()
        
        install(FILES ${file} DESTINATION ${installPath} COMPONENT Distribution)
    endforeach() 
endfunction()

function(_installHeaders)
    CMAKE_PARSE_ARGUMENTS(headers "" "Target" "Headers;IncludePathReplacement" ${ARGN})

    set(publicHeaders "")
    set(containsDeclspec "no")
    
    if (NOT "" STREQUAL "${headers_Headers}")
        set(publicHeaders ${headers_Headers})
    endif()
        
    if (NOT "" STREQUAL "${headers_Target}")
        get_property(targetPublicHeaders TARGET ${headers_Target} PROPERTY PublicHeaders)
        list(APPEND publicHeaders ${targetPublicHeaders})
    
        get_property(containsDeclspec TARGET ${headers_Target} PROPERTY ContainsDeclspec)
    endif()
    
    set(generatedPublicHeaders "")
    foreach(header ${publicHeaders})
        set(isReplaced "no")
        set(installPath "include")
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
    CMAKE_PARSE_ARGUMENTS(cfg "" "Package" "Targets;IncludePaths;IncludePathReplacement" ${ARGN})
    
    set(needsDeclspec "no")
    foreach(target ${cfg_Targets})
        get_property(type TARGET ${target} PROPERTY TYPE)
        
        if("SHARED_LIBRARY" STREQUAL "${type}" OR "STATIC_LIBRARY" STREQUAL "${type}")
            get_property(isMock TARGET ${target} PROPERTY IsMock)

            if(isMock)
                list(APPEND INSTALL_MOCK_LIBRARIES ${target})
            else()
                list(APPEND INSTALL_LIBRARIES ${target})
            endif()
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
    
    # use normal library as mock
    if(NOT DEFINED INSTALL_MOCK_LIBRARIES AND DEFINED INSTALL_LIBRARIES)
        set(INSTALL_MOCK_LIBRARIES ${INSTALL_LIBRARIES})
    endif()
    
    set(includePaths "\${_IMPORT_PREFIX}/include")
    if(DEFINED cfg_IncludePaths)
        foreach(inc ${cfg_IncludePaths})
            list(APPEND includePaths "\${_IMPORT_PREFIX}/include/${inc}")
        endforeach()
    elseif(DEFINED cfg_IncludePathReplacement)
        foreach(replacement ${cfg_IncludePathReplacement})
            string(REGEX REPLACE "[ \t]*->[ \t]*" ";" replacements "${replacement}")
            list(GET replacements 1 headerDirectory)
            if (NOT "" STREQUAL "${headerDirectory}")
                list(APPEND includePaths "\${_IMPORT_PREFIX}/include/${headerDirectory}")
            endif()
        endforeach()
    endif()
    
    if(DEFINED INSTALL_LIBRARIES)
	    set(LIBRARIES_PART 
	        "set(${cfg_Package}_LIBRARIES ${INSTALL_LIBRARIES})")
    endif()
    if(DEFINED INSTALL_MOCK_LIBRARIES)
	    set(MOCK_LIBRARIES_PART 
	        "set(${cfg_Package}_MOCK_LIBRARIES ${INSTALL_MOCK_LIBRARIES})")
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
    
    string(REPLACE ";" " " includePaths "${includePaths}")
    set(INCLUDES_PART "set(${cfg_Package}_INCLUDE_DIRS ${includePaths})")    
    
    if (DEFINED INSTALL_LIBRARIES OR DEFINED INSTALL_MOCK_LIBRARIES OR DEFINED INSTALL_TEST_EXECUTABLES OR DEFINED INSTALL_EXECUTABLES)
        install(EXPORT ${cfg_Package}Targets DESTINATION config COMPONENT Configs)

        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfig.cmake.in "${PROJECT_BINARY_DIR}/${cfg_Package}Config.cmake" @ONLY)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/${cfg_Package}ConfigVersion.cmake" @ONLY)
    else()
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageWithoutTargetConfig.cmake.in "${PROJECT_BINARY_DIR}/${cfg_Package}Config.cmake" @ONLY)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/${cfg_Package}ConfigVersion.cmake" @ONLY)    
    endif()     
    # Install the Config.cmake and ConfigVersion.cmake
    install(FILES
      "${PROJECT_BINARY_DIR}/${cfg_Package}Config.cmake"
      "${PROJECT_BINARY_DIR}/${cfg_Package}ConfigVersion.cmake"
      DESTINATION config COMPONENT Configs) 

endfunction()


