cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetInstallGuard)
    return()
endif()

set(TargetInstallGuard yes)

include(CMakeParseArguments)
include(SBE/TargetImported)

set(isAddInstallCalled no)

set(InstalledTargets "")

function(sbeInstallFrequentisVBT)
    # arguments
    # Url - path and name of VBT in Svn
    # File - path and name of VBT in local file system
    # ExcludeLibraries - libraries that have to be excluded from import
    #
    # Only one of Url of File has to be specified.
    #
    # Function imports libraries from VBT and install them.
    
    # Get and check arguments
    CMAKE_PARSE_ARGUMENTS(inst "" "Url;File" "ExcludeLibraries" ${ARGN})
    
    if(DEFINED inst_Url AND DEFINED inst_File)
        message(FATAL_ERROR "In command sbeInstallFrequentisVBT only one of Url or File has to be speciefied.")
    endif()
    
    if(NOT DEFINED inst_Url AND NOT DEFINED inst_File)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageWithoutTargetConfig.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake" @ONLY)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)    
    
        # Install the Config.cmake and ConfigVersion.cmake
        install(FILES
          "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake"
          "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake"
          DESTINATION config COMPONENT Configs)
        
        # touch build timestamps  
        sbeGetPackageAllBuildTimestamp(${PROJECT_NAME} allbuildtimestamp)
        sbeGetPackageBuildTimestamp(${PROJECT_NAME} buildtimestamp)      
        execute_process( 
            COMMAND ${CMAKE_COMMAND} -E touch ${allbuildtimestamp} 
            COMMAND ${CMAKE_COMMAND} -E touch ${buildtimestamp})          
        return()
    endif()

    # get method of getting vbt   
    set(isSvn no)
    if(DEFINED inst_Url)
        set(isSvn yes)
        set(vbtFile ${inst_Url})
    else()
        set(isSvn no)
        set(vbtFile ${CMAKE_SOURCE_DIR}/${inst_File})
    endif()

    get_filename_component(tarFileName "${vbtFile}" NAME)
                
    if(isSvn)
        if(NOT EXISTS ${PROJECT_BINARY_DIR}/${tarFileName})
            # find all necessary tools
            find_package(Subversion QUIET)
            if(NOT Subversion_SVN_EXECUTABLE)
                message(FATAL_ERROR "error: could not find svn.")
            endif()
            
            # export frequentis VBT 
            message(STATUS "Exporting ${tarFileName}...")
            execute_process(COMMAND svn export ${vbtFile} ${PROJECT_BINARY_DIR}/${tarFileName}
                RESULT_VARIABLE svnResult
                OUTPUT_VARIABLE out
                ERROR_VARIABLE out)
            if(${svnResult} GREATER 0)
                message(FATAL_ERROR "SVN Export Fails:\n${out}")
            endif()
        endif()
        
        # now vbt is file
        set(isSvn no)
        set(vbtFile ${PROJECT_BINARY_DIR}/${tarFileName})
    endif()
    
    # untar VBT for further analyse
    message(STATUS "Preinstalling ${tarFileName}...")
    file(MAKE_DIRECTORY  ${PROJECT_BINARY_DIR}/preinstallation)
    execute_process(COMMAND tar -xzf ${vbtFile} -C ${PROJECT_BINARY_DIR}/preinstallation
        RESULT_VARIABLE result
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(${result} GREATER 0)
        message(FATAL_ERROR "Untar Fails:\n${out}")
    endif()
    
    # get libs targets
    sbeImportsFrequentisVBT(
        Dir ${PROJECT_BINARY_DIR}/preinstallation
        ExcludeLibraries ${inst_ExcludeLibraries}
        ImportedTargets importedTargets
    )

    # install imported targets
    sbeAddInstallImportedTarget(
        Targets ${importedTargets} 
        HeadersDirectory ${PROJECT_BINARY_DIR}/preinstallation/include/
        HeadersPathReplacement ".* -> "
        )
endfunction()

function(sbeAddInstallTarget)
    # temporary solution. It will add only last target to project config.
    if(isAddInstallCalled)
        message(FATAL_ERROR "Function sbeAddInstallTarget can be called only one time.\nIn current implemntation it will add only latest target to install to package config file.")
    endif()
    # check install and package targets order
    if(isAddPackageCalled)
        message(FATAL_ERROR "Function sbeAddPackageTarget has to be called after function sbeAddInstallTarget.")
    endif()
    
    set(isAddInstallCalled yes PARENT_SCOPE)
    
    CMAKE_PARSE_ARGUMENTS(inst "" "" "HeadersPaths;Headers;Files;Targets;MockHeadersPathReplacement;HeadersPathReplacement;FilePathReplacement" ${ARGN})
    
    # use mock first
    set(HeadersPathReplacement "")
    if(DEFINED inst_MockHeadersPathReplacement)
        list(APPEND HeadersPathReplacement ${inst_MockHeadersPathReplacement})
    endif()
    list(APPEND HeadersPathReplacement ${inst_HeadersPathReplacement})
    
    set(InstalledTargets ${inst_Targets} PARENT_SCOPE)
            
    # get test target
    set(testTargets "")
    foreach(target ${inst_Targets})
        get_property(isTestTarget TARGET ${target} PROPERTY SBE_TEST)
        
        if(isTestTarget)
            list(APPEND testTargets ${target})
        endif()
    endforeach()
    
    # install test targets
    _installTestTargets(Targets ${testTargets})
    
    # get mock target
    set(mockTargets "")
    foreach(target ${inst_Targets})
        get_property(isMockTarget TARGET ${target} PROPERTY SBE_MOCK)
        
        if(isMockTarget)
            list(APPEND mockTargets ${target})
        endif()
    endforeach()
    
    # install mock targets
    _installMockTargets(Targets ${mockTargets} HeadersPathReplacement ${HeadersPathReplacement})
    
    # get ordinary targets
    set(ordinaryTargets ${inst_Targets})
    if(NOT "" STREQUAL "${testTargets}")
        list(REMOVE_ITEM ordinaryTargets ${testTargets})
    endif()
    if(NOT "" STREQUAL "${mockTargets}")
        list(REMOVE_ITEM ordinaryTargets ${mockTargets})
    endif()
    
    _installOrdinaryTargets(Targets ${ordinaryTargets} HeadersPathReplacement ${HeadersPathReplacement})
    
    _installHeaders(Headers ${inst_Headers} HeadersPathReplacement ${HeadersPathReplacement})
    
    _installFiles(Files ${inst_Files} FilePathReplacement ${inst_FilePathReplacement})
    
    _installConfigs(Targets ${inst_Targets} HeadersPaths ${inst_HeadersPaths} HeadersPathReplacement ${inst_HeadersPathReplacement} MockHeadersPathReplacement ${inst_MockHeadersPathReplacement})
    
    export(TARGETS ${inst_Targets} FILE Export/config/${PROJECT_NAME}Targets.cmake)
    
    sbeGetPackageBuildTimestamp(${PROJECT_NAME} buildtimestamp)
    
    foreach(trg ${inst_Targets})
        add_custom_command(TARGET ${trg} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E touch ${buildtimestamp})
    endforeach()

    # add all build timestamp for dependats
    sbeGetPackageAllBuildTimestamp(${PROJECT_NAME} allbuildtimestamp)
    sbeGetPackageBuildTimestamp(${PROJECT_NAME} buildtimestamp)
    
    if(TARGET export-headers)
        set(allTargetsThatAreInstalled ${inst_Targets} export-headers)
    else()
        set(allTargetsThatAreInstalled ${inst_Targets})
    endif() 
    add_custom_target(buildtimestamp ALL 
        COMMAND ${CMAKE_COMMAND} -E touch ${allbuildtimestamp} 
        COMMAND ${CMAKE_COMMAND} -E touch ${buildtimestamp}
        DEPENDS ${allTargetsThatAreInstalled}
        COMMENT "")

    # consolidate headers, already exported but removed from CMakeLists.txt
	message(STATUS "Consolidating Exported headers")
	file(GLOB_RECURSE alreadyExportedHeaders RELATIVE ${PROJECT_BINARY_DIR} ${PROJECT_BINARY_DIR}/Export/include/*)
	set(headersToExport "")
	get_property(headersToExport GLOBAL PROPERTY Install_headersToExport)
    get_property(headersDirectoriesToExport GLOBAL PROPERTY Install_headersDirectoriesToExport)
    if(DEFINED headersDirectoriesToExport)
        foreach(headerDir ${headersDirectoriesToExport})
            file(GLOB_RECURSE dirHeaders RELATIVE ${PROJECT_BINARY_DIR} ${headerDir}/*)
            list(APPEND headersToExport ${dirHeaders})
        endforeach()
    endif()
	if(NOT "" STREQUAL "${alreadyExportedHeaders}")
		if(NOT "" STREQUAL "${headersToExport}")
			list(REMOVE_ITEM alreadyExportedHeaders ${headersToExport})
		endif()
		foreach(h ${alreadyExportedHeaders})
		    message(STATUS "   Removing ${h}")
			file(REMOVE ${PROJECT_BINARY_DIR}/${h})
			# touch target build timestamp to trigger rebuild of dependecies and all rebuild by dependant
			execute_process(COMMAND ${CMAKE_COMMAND} -E touch ${buildtimestamp})
		endforeach()
	endif()
endfunction()

function(_installTestTargets)
    CMAKE_PARSE_ARGUMENTS(tst "" "" "Targets" ${ARGN})
    
    if(DEFINED tst_Targets)
        install(
            TARGETS ${tst_Targets} 
            EXPORT ${PROJECT_NAME}Targets
            RUNTIME DESTINATION bin COMPONENT Distribution CONFIGURATIONS Debug | DebugWithCoverage)
    endif()
endfunction()

function(_installMockTargets)
    CMAKE_PARSE_ARGUMENTS(mock "" "" "Targets;HeadersPathReplacement" ${ARGN})
    
    if(NOT DEFINED mock_Targets)
        return()
    endif()
    
    install(
        TARGETS ${mock_Targets}
        EXPORT ${PROJECT_NAME}Targets
        RUNTIME DESTINATION bin COMPONENT Mocks
        LIBRARY DESTINATION lib/mock COMPONENT Mocks NAMELINK_SKIP
        ARCHIVE DESTINATION lib/mock COMPONENT Mocks)
        
    foreach(target ${mock_Targets})
        _installHeaders(
            Target ${target} 
            HeadersPathReplacement ${mock_HeadersPathReplacement})
    endforeach()    
endfunction()

function(sbeAddInstallImportedTarget)
    CMAKE_PARSE_ARGUMENTS(imp "" "HeadersDirectory" "Targets;HeadersPathReplacement;Headers" ${ARGN})
    
    if(DEFINED imp_Headers OR DEFINED imp_HeadersDirectory)
        _installHeaders(HeadersDirectory ${imp_HeadersDirectory} Headers ${imp_Headers} HeadersPathReplacement ${imp_HeadersPathReplacement})
    endif()
    
    set(ALL_IMPORTED_TARGETS ${imp_Targets})
    set(ALL_IMPORTED_TARGETS_DEFINITION "")
    set(ALL_IMPORTED_TARGETS_DESCRIPTION "")
    string(TOUPPER "${CMAKE_BUILD_TYPE}" buildType)
    foreach(target ${imp_Targets})
        get_property(type TARGET ${target} PROPERTY TYPE)
        get_property(location TARGET ${target} PROPERTY IMPORTED_LOCATION)
        get_property(allFilesToInstall TARGET ${target} PROPERTY SBE_ALL_LIBRARY_FILES)
        set(componentIdentifier "")
                     
        if("STATIC_LIBRARY" STREQUAL "${type}")
            set(componentIdentifier "")
            
            list(APPEND ALL_IMPORTED_TARGETS_DEFINITION "add_library(${target} STATIC IMPORTED)")
            
            get_property(languages TARGET ${target} PROPERTY IMPORTED_LINK_INTERFACE_LANGUAGES)
            
            if ("" STREQUAL "${languages}")
                 set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}set_property(TARGET ${target} APPEND PROPERTY IMPORTED_CONFIGURATIONS ${buildType})\n")
                 set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}set_target_properties(${target} PROPERTIES\n")
                 set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}    IMPORTED_LOCATION_${buildType} \"${location}\")\n")
            else()
                set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}set_property(TARGET ${target} APPEND PROPERTY IMPORTED_CONFIGURATIONS ${buildType})\n")
                set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}set_target_properties(${target} PROPERTIES\n")
                set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}    IMPORTED_LOCATION_${buildType} \"${location}\"\n")
                set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}    IMPORTED_LINK_INTERFACE_LANGUAGES_${buildType} \"${languages}\")\n")
            endif()
        elseif("SHARED_LIBRARY" STREQUAL "${type}")
            set(componentIdentifier COMPONENT Distribution)
            
            list(APPEND ALL_IMPORTED_TARGETS_DEFINITION "add_library(${target} SHARED IMPORTED)")
            
            get_property(soName TARGET ${target} PROPERTY IMPORTED_SONAME)
            
            set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}set_property(TARGET ${target} APPEND PROPERTY IMPORTED_CONFIGURATIONS ${buildType})\n")
            set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}set_target_properties(${target} PROPERTIES\n")
            set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}    IMPORTED_LOCATION_${buildType} \"${location}\"\n")
            set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}    IMPORTED_SONAME_${buildType} \"${soName}\")\n")
        elseif("EXECUTABLE" STREQUAL "${type}")
            message(FATAL_ERROR "Not implemented")
        endif()
        
        set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}list(APPEND _IMPORT_CHECK_TARGETS ${target})\n")
        set(ALL_IMPORTED_TARGETS_DESCRIPTION "${ALL_IMPORTED_TARGETS_DESCRIPTION}list(APPEND _IMPORT_CHECK_FILES_FOR_${target} \"${location}\")\n")
        
        install(FILES ${allFilesToInstall} DESTINATION lib ${componentIdentifier})
        
        get_property(targetPublicHeaders TARGET ${target} PROPERTY PublicHeaders)
        if(NOT "" STREQUAL "${targetPublicHeaders}")
            # cold not be based on target because target is not maked
            _installHeaders(Headers ${targetPublicHeaders} HeadersPathReplacement ${imp_HeadersPathReplacement})
        endif()
    endforeach()
    
    string(REPLACE ";" "\n" ALL_IMPORTED_TARGETS_DEFINITION "${ALL_IMPORTED_TARGETS_DEFINITION}")
    
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ImportedTargetImportFile.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Targets-imported.cmake" @ONLY)
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ImportedTargets.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Targets.cmake" @ONLY)
     
    install(FILES
         "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Targets.cmake"
         "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Targets-imported.cmake"
         DESTINATION config COMPONENT Configs)

    set(LIBRARIES_PART "set(${PROJECT_NAME}_LIBRARIES ${imp_Targets})")
    set(MOCK_LIBRARIES_PART "set(${PROJECT_NAME}_MOCK_LIBRARIES ${imp_Targets})")

    if(DEFINED imp_HeadersPathReplacement)
        foreach(replacement ${imp_HeadersPathReplacement})
            string(REGEX REPLACE "[ \t]*->[ \t]*" ";" replacements "${replacement}")
            list(GET replacements 1 headerDirectory)
            list(APPEND headerPaths "\${_IMPORT_PREFIX}/include/${headerDirectory}")
        endforeach()
    endif()
    
    string(REPLACE ";" " " headerPaths "${headerPaths}")
    set(INCLUDES_PART "set(${PROJECT_NAME}_INCLUDE_DIRS ${headerPaths})")
    set(MOCK_INCLUDES_PART "set(${PROJECT_NAME}_MOCK_INCLUDE_DIRS ${headerPaths})")
    
    if (DEFINED imp_Targets)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfig.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake" @ONLY)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)
    else()
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageWithoutTargetConfig.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake" @ONLY)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)    
    endif()  
    
    # Install the Config.cmake and ConfigVersion.cmake
    install(FILES
      "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake"
      "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake"
      DESTINATION config COMPONENT Configs)

    # add all build timestamp for dependats
    sbeGetPackageAllBuildTimestamp(${PROJECT_NAME} allbuildtimestamp)
    sbeGetPackageBuildTimestamp(${PROJECT_NAME} buildtimestamp)
    
    if(TARGET export-headers)
        set(allTargetsThatAreInstalled ${inst_Targets} export-headers)
    else()
        set(allTargetsThatAreInstalled ${inst_Targets})
    endif() 
    add_custom_target(buildtimestamp ALL 
        COMMAND ${CMAKE_COMMAND} -E touch ${allbuildtimestamp} 
        COMMAND ${CMAKE_COMMAND} -E touch ${buildtimestamp}
        DEPENDS ${allTargetsThatAreInstalled}
        COMMENT "")
endfunction()

function(_installOrdinaryTargets)
    CMAKE_PARSE_ARGUMENTS(ord "" "" "Targets;HeadersPathReplacement" ${ARGN})
    
    if(NOT DEFINED ord_Targets)
        return()
    endif()

    # when bin file is created for executable install also this bin file
    # used for DSP
    set(binFiles "")
    set(targetsWithBinFiles "")
    foreach(target ${ord_Targets})
        get_property(binFile TARGET ${target} PROPERTY BIN_FILE)
        
        if(DEFINED binFile)
            list(APPEND binFiles ${CMAKE_CURRENT_BINARY_DIR}/${binFile})
            list(APPEND targetsWithBinFiles ${target})
            list(REMOVE_ITEM ord_Targets ${target})
        endif()
    endforeach()
    
    if(NOT "" STREQUAL "${targetsWithBinFiles}")
        install(
            TARGETS ${targetsWithBinFiles}
            EXPORT ${PROJECT_NAME}Targets
            RUNTIME DESTINATION bin COMPONENT DoNotInstall_BinFileIsInstalledInstead)
    endif()
    
    if(NOT "" STREQUAL "${ord_Targets}")
        install(
            TARGETS ${ord_Targets}
            EXPORT ${PROJECT_NAME}Targets
            RUNTIME DESTINATION bin COMPONENT Distribution
            LIBRARY DESTINATION lib COMPONENT Distribution NAMELINK_SKIP
            ARCHIVE DESTINATION lib)
    endif()            
        
    if(NOT "" STREQUAL "${binFiles}")
        install(FILES ${binFiles} DESTINATION bin COMPONENT Distribution)
    endif()
    
    foreach(target ${ord_Targets})
        _installHeaders(
            Target ${target} 
            HeadersPathReplacement ${ord_HeadersPathReplacement})
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
    _exportHeaders(${ARGN} DestinationDirectory Export/include)
    
    install(DIRECTORY ${PROJECT_BINARY_DIR}/Export/include DESTINATION include COMPONENT Headers)
endfunction()

function(_exportHeaders)
    CMAKE_PARSE_ARGUMENTS(headers "" "Target;HeadersDirectory;DestinationDirectory" "Headers;HeadersPathReplacement" ${ARGN})

    # check if something to do
    if(NOT DEFINED headers_Target AND 
       NOT DEFINED headers_HeadersDirectory AND
       NOT DEFINED headers_Headers)
       return()
    endif()
    
    # process headers
    set(publicHeaders "")
    set(containsDeclspec "no")
    
    # setup target that needs to export headers
    set(headersTarget "")
    if(DEFINED headers_Target)
        set(headersTarget ${headers_Target})
    else()
        set(headersTarget export-headers)
        add_custom_target(${headersTarget} ALL)
    endif()

    sbeGetPackageBuildTimestamp(${PROJECT_NAME} buildtimestamp)
                
    # copy directory as it is
    if(DEFINED headers_HeadersDirectory)
        foreach(headerDir ${headers_HeadersDirectory})
            list(APPEND exportCommandArg "-DSOURCE=${headerDir}")
            list(APPEND exportCommandArg "-DDESTINATION=${headers_DestinationDirectory}")
            list(APPEND exportCommandArg "-DMESSAGE=Exporting ${headerDir}")
            list(APPEND exportCommandArg "-DTIMESTAMP_FILE=${buildtimestamp}")
            list(APPEND exportCommandArg "-P")
            list(APPEND exportCommandArg "${CMAKE_ROOT}/Modules/SBE/helpers/CopyIfNewer.cmake")
     
            add_custom_command(TARGET ${headersTarget} POST_BUILD
                COMMAND ${CMAKE_COMMAND} ${exportCommandArg})
                
            set_property(GLOBAL APPEND PROPERTY Install_headersDirectoriesToExport ${headerDir})
        endforeach()
    endif()
    
    if (NOT "" STREQUAL "${headers_Headers}")
        set(publicHeaders ${headers_Headers})
    endif()
        
    if (NOT "" STREQUAL "${headers_Target}")
        get_property(targetPublicHeaders TARGET ${headers_Target} PROPERTY PublicHeaders)
        list(APPEND publicHeaders ${targetPublicHeaders})
        
        get_property(linkGeneratedLibraries TARGET ${headers_Target} PROPERTY SBE_LINK_GENERATED_LIBRARY)
        if(DEFINED linkGeneratedLibraries)
            foreach(lib ${linkGeneratedLibraries})
                get_property(exportHeaderDir TARGET ${lib} PROPERTY SBE_GENERATED_LIBRARY_EXPORT_HEADERS_DIR)
                if(DEFINED exportHeaderDir)
                    set_property(GLOBAL APPEND PROPERTY Install_headersDirectoriesToExport ${exportHeaderDir})
                endif()
            endforeach()
        endif()
    
        get_property(containsDeclspec TARGET ${headers_Target} PROPERTY SBE_CONTAINS_DECLSPEC)
    endif()

    foreach(header ${publicHeaders})
        set(exportPath "${headers_DestinationDirectory}")
        
        set(isReplaced "no")
        foreach(replacement ${headers_HeadersPathReplacement})
            if(NOT isReplaced)
                string(REGEX REPLACE "[ \t]*->[ \t]*" ";" replacements "${replacement}")
                list(GET replacements 0 matchExpression)
                list(GET replacements 1 headerDirectory)
                if("${header}" MATCHES "^${matchExpression}$")
                    set(exportPath "${exportPath}/${headerDirectory}")
                        set(isReplaced "yes")
                endif()
            endif()
        endforeach()
        
        # remove trailing /
        string(REGEX REPLACE "[/]+$" "" exportPath "${exportPath}")

        GET_FILENAME_COMPONENT(headerFile "${header}" NAME)
        if(IS_ABSOLUTE ${header})
            set(sourceHeaderFile "${header}")
        else()
            set(sourceHeaderFile "${PROJECT_SOURCE_DIR}/${header}")
        endif()
            
        set(exportedHeaderFile "${exportPath}/${headerFile}")
        set_property(GLOBAL APPEND PROPERTY Install_headersToExport ${exportedHeaderFile})
        
        # setup command to export header. If it contains DECLSPEC then it should be modified
        # otherwise it should be only copy
        set(exportCommandArg "")
        if(containsDeclspec)
            list(APPEND exportCommandArg "-DSOURCE=${sourceHeaderFile}")
            list(APPEND exportCommandArg "-DDESTINATION=${exportedHeaderFile}")
            list(APPEND exportCommandArg "-DMESSAGE=Exporting ${header}")
            list(APPEND exportCommandArg "-DTIMESTAMP_FILE=${buildtimestamp}")            
            list(APPEND exportCommandArg "-P")
            list(APPEND exportCommandArg "${CMAKE_ROOT}/Modules/SBE/helpers/ChangeExportToImport.cmake")
        else()
            list(APPEND exportCommandArg "-DSOURCE=${sourceHeaderFile}")
            list(APPEND exportCommandArg "-DDESTINATION=${exportedHeaderFile}")
            list(APPEND exportCommandArg "-DMESSAGE=Exporting ${header}")
            list(APPEND exportCommandArg "-DTIMESTAMP_FILE=${buildtimestamp}")
            list(APPEND exportCommandArg "-P")
            list(APPEND exportCommandArg "${CMAKE_ROOT}/Modules/SBE/helpers/CopyIfNewer.cmake")
        endif()
       
        add_custom_command(TARGET ${headersTarget} POST_BUILD
            COMMAND ${CMAKE_COMMAND} ${exportCommandArg})            
    endforeach()
endfunction()

function(_installConfigs)
    CMAKE_PARSE_ARGUMENTS(cfg "" "" "Targets;HeadersPaths;HeadersPathReplacement;MockHeadersPathReplacement" ${ARGN})
    
    set(needsDeclspec "no")
    foreach(target ${cfg_Targets})
        get_property(type TARGET ${target} PROPERTY TYPE)
        
        if("SHARED_LIBRARY" STREQUAL "${type}" OR "STATIC_LIBRARY" STREQUAL "${type}")
            get_property(isMock TARGET ${target} PROPERTY SBE_MOCK)

            if(isMock)
                list(APPEND INSTALL_MOCK_LIBRARIES ${target})
            else()
                list(APPEND INSTALL_LIBRARIES ${target})
            endif()
        elseif("EXECUTABLE" STREQUAL "${type}")
            get_property(isTest TARGET ${target} PROPERTY SBE_TEST)
            if(isTest)
                list(APPEND INSTALL_TEST_EXECUTABLES ${target})
            else()
                list(APPEND INSTALL_EXECUTABLES ${target})
            endif()
        endif()
        
        get_property(containsDeclspec TARGET ${target} PROPERTY SBE_CONTAINS_DECLSPEC)
        if(containsDeclspec)
            set(needsDeclspec "yes")    
        endif()
    endforeach()
    
    if(NOT "" STREQUAL "${INSTALL_LIBRARIES}")
        # use normal library as mock when it is not mocked
        set(productionTargetsAsMocks ${INSTALL_LIBRARIES})
        foreach(mockLibrary ${INSTALL_MOCK_LIBRARIES})
            get_property(productionLibrary TARGET ${mockLibrary} PROPERTY SBE_MOCKED_NAME)
            list(REMOVE_ITEM productionTargetsAsMocks ${productionLibrary})                    
        endforeach()
        list(APPEND INSTALL_MOCK_LIBRARIES ${productionTargetsAsMocks})
    endif()

    set(headerPaths "")
    if(DEFINED cfg_HeadersPaths)
        foreach(inc ${cfg_HeadersPaths})
            if("." STREQUAL "${inc}")
                list(APPEND headerPaths "\${_IMPORT_PREFIX}/include")
            else()
                list(APPEND headerPaths "\${_IMPORT_PREFIX}/include/${inc}")
            endif()
        endforeach()
    elseif(DEFINED cfg_HeadersPathReplacement)
        set(headerPaths "\${_IMPORT_PREFIX}/include")
        
        foreach(replacement ${cfg_HeadersPathReplacement})
            string(REGEX REPLACE "[ \t]*->[ \t]*" ";" replacements "${replacement}")
            list(GET replacements 1 headerDirectory)
            if (NOT "" STREQUAL "${headerDirectory}")
                list(APPEND headerPaths "\${_IMPORT_PREFIX}/include/${headerDirectory}")
            endif()
        endforeach()
    endif()
    
    set(mockHeadersPaths "")
    if(DEFINED cfg_MockHeadersPathReplacement)
        set(mockHeadersPaths "\${_IMPORT_PREFIX}/include")
        
        foreach(replacement ${cfg_MockHeadersPathReplacement})
            string(REGEX REPLACE "[ \t]*->[ \t]*" ";" replacements "${replacement}")
            list(GET replacements 1 headerDirectory)
            if (NOT "" STREQUAL "${headerDirectory}")
                list(APPEND mockHeadersPaths "\${_IMPORT_PREFIX}/include/${headerDirectory}")
            endif()
        endforeach()
    endif()
    
    if(DEFINED INSTALL_LIBRARIES)
	    set(LIBRARIES_PART 
	        "set(${PROJECT_NAME}_LIBRARIES ${INSTALL_LIBRARIES})")
    endif()
    if(DEFINED INSTALL_MOCK_LIBRARIES)
	    set(MOCK_LIBRARIES_PART 
	        "set(${PROJECT_NAME}_MOCK_LIBRARIES ${INSTALL_MOCK_LIBRARIES})")
    endif()		
    if(DEFINED INSTALL_TEST_EXECUTABLES)
        set(TEST_EXECUTABLES_PART
	        "set(${PROJECT_NAME}_TEST_EXECUTABLES ${INSTALL_TEST_EXECUTABLES})\nset(${PROJECT_NAME}_TEST_EXECUTABLES_PATH \"\${_IMPORT_PREFIX}/bin\")")
    endif()
    if(DEFINED INSTALL_EXECUTABLES)
        set(EXECUTABLES_PART
	        "set(${PROJECT_NAME}_EXECUTABLES ${INSTALL_EXECUTABLES})\nset(${PROJECT_NAME}_EXECUTABLES_PATH \"\${_IMPORT_PREFIX}/bin\")")
    endif()
    
    if(needsDeclspec)
        set(DECLSPEC_PART "set(${PROJECT_NAME}_CONTAINS_DECLSPEC \"yes\")")
    endif()
    
    string(REPLACE ";" " " headerPaths "${headerPaths}")
    set(INCLUDES_PART "set(${PROJECT_NAME}_INCLUDE_DIRS ${headerPaths})")    
    
    string(REPLACE ";" " " mockHeadersPaths "${mockHeadersPaths}")
    set(MOCK_INCLUDES_PART "set(${PROJECT_NAME}_MOCK_INCLUDE_DIRS ${mockHeadersPaths})")
    
    if (DEFINED INSTALL_LIBRARIES OR DEFINED INSTALL_MOCK_LIBRARIES OR DEFINED INSTALL_TEST_EXECUTABLES OR DEFINED INSTALL_EXECUTABLES)
        install(EXPORT ${PROJECT_NAME}Targets DESTINATION config COMPONENT Configs)

        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfig.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake" @ONLY)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)
    else()
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageWithoutTargetConfig.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake" @ONLY)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)    
    endif()  
    
    # Install the Config.cmake and ConfigVersion.cmake
    install(FILES
      "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake"
      "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake"
      DESTINATION config COMPONENT Configs) 

endfunction()



