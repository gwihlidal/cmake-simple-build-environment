cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetBinaryGuard)
    return()
endif()

set(TargetBinaryGuard yes)

include(SBE/helpers/AddDependenciesToTarget)
include(SBE/helpers/ArgumentParser)
include(SBE/helpers/VersionParser)

set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
set (CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
set (CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)

include_directories(${CMAKE_SOURCE_DIR}/src)

if(DEFINED RULE_LAUNCH_COMPILE)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${RULE_LAUNCH_COMPILE}")
endif()
if(DEFINED RULE_LAUNCH_LINK)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK "${RULE_LAUNCH_LINK}")
endif()    

function(sbeAddLibrary)
    sbeParseArguments(prop "ContainsDeclspec;Static" "Name" "PreferHeadersFrom;LinkOwnLibraries;Objects;Sources;PublicHeaders;ExcludeDependencies" "FromDependency" "${ARGN}")
    
    if(
        (NOT DEFINED prop_Name) OR
        ((NOT DEFINED prop_Objects) AND (NOT DEFINED prop_Sources))
      )
        return()
    endif()
    
    set(precompilatedObjects "")
    
    if(DEFINED prop_Objects)
        foreach(obj ${prop_Objects})
            list(APPEND precompilatedObjects "\$<TARGET_OBJECTS:${obj}>")
        endforeach()
    endif()
           
    get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
    
    if(isSharedLibSupported AND NOT prop_Static)
        add_library(${prop_Name} SHARED ${precompilatedObjects} ${prop_Sources})
        
        sbeSplitSemanticVersion(${SemanticVersion} major minor bugfix)
        set_target_properties(${prop_Name}
    	    PROPERTIES
    		    # create *nix style library versions + symbolic links
    		    VERSION ${major}.${minor}.${bugfix}
    		    SOVERSION ${major}.${minor}
    		    INSTALL_RPATH "$ORIGIN/:")
    else()
        add_library(${prop_Name} STATIC ${precompilatedObjects} ${prop_Sources})            
    endif()
    
    sbeAddHelpForTarget(Build ${prop_Name} "Build library ${prop_Name}")
    
    
    if(DEFINED prop_LinkOwnLibraries)
        foreach(ownLib ${prop_LinkOwnLibraries}) 
            get_target_property(isGeneratedLibrary ${ownLib} SBE_GENERATED_LIBRARY)
            if(isGeneratedLibrary)
                set_property(TARGET ${prop_Name} APPEND PROPERTY SBE_LINK_GENERATED_LIBRARY ${ownLib})
                get_target_property(location ${ownLib} SBE_GENERATED_LIBRARY_LOCATION)
                target_link_libraries(${prop_Name} ${location})
                get_target_property(include ${ownLib} SBE_GENERATED_LIBRARY_HEADERS_DIR)
                target_include_directories(${prop_Name} PRIVATE ${include})
                add_dependencies(${prop_Name} ${ownLib})
            else()
                target_link_libraries(${prop_Name} ${ownLib})
            endif()
        endforeach()
    endif()
    
    string(REPLACE "," ";" prop_FromDependency "${prop_FromDependency}")
    
    sbeAddDependencies(
        Target ${prop_Name}
        ExcludeDependencies ${prop_ExcludeDependencies}
        PreferHeadersFrom ${prop_PreferHeadersFrom}
        ${prop_FromDependency}) 

    sbeDoesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)

    if(prop_ContainsDeclspec OR dependenciesContainsDeclspecs)
        _handleDeclSpec(${prop_Name})
    endif()
            
    if(DEFINED prop_PublicHeaders)
        set_property(TARGET ${prop_Name} PROPERTY PublicHeaders ${prop_PublicHeaders})
    endif()
endfunction()

function(sbeAddMockLibrary)
    sbeParseArguments(prop "ContainsDeclspec;Static" "MockedName;Name" "PreferHeadersFrom;Objects;Sources;PublicHeaders;ExcludeDependencies" "FromDependency" "${ARGN}")
    
    if(
        (NOT DEFINED prop_Name) OR
        ((NOT DEFINED prop_Objects) AND (NOT DEFINED prop_Sources))
      )
        return()
    endif()
    
    if(NOT DEFINED prop_MockedName AND "${prop_Name}" MATCHES "^Mock.*$")
        string(REGEX REPLACE "^Mock(.*)$" "\\1" prop_MockedName "${prop_Name}")
    endif()

    set(precompilatedObjects "")
        
    if(DEFINED prop_Objects)
        foreach(obj ${prop_Objects})
            list(APPEND precompilatedObjects "\$<TARGET_OBJECTS:${obj}>")
        endforeach()
    endif()
            
    add_library(${prop_Name} STATIC ${prop_Sources} ${precompilatedObjects})
    sbeAddHelpForTarget(Build ${prop_Name} "Build Mock library ${prop_Name} for unit test in other packages")            
    
    set_property(TARGET ${prop_Name} PROPERTY SBE_MOCK yes)
    set_property(TARGET ${prop_Name} PROPERTY SBE_MOCKED_NAME ${prop_MockedName})
    
    string(REPLACE "," ";" prop_FromDependency "${prop_FromDependency}")
    
    sbeAddDependencies(
        Target ${prop_Name}
        ExcludeDependencies ${prop_ExcludeDependencies}
        PreferHeadersFrom ${prop_PreferHeadersFrom}
        ${prop_FromDependency}) 

    sbeDoesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)

    if(prop_ContainsDeclspec OR dependenciesContainsDeclspecs)
        _handleDeclSpec(${prop_Name})
    endif()
            
    if(DEFINED prop_PublicHeaders)
        set_property(TARGET ${prop_Name} PROPERTY PublicHeaders ${prop_PublicHeaders})
    endif()
endfunction()


function(sbeAddExecutable)
    sbeParseArguments(prop "" "Name;Objects;ConvertToBin" "PreferHeadersFrom;Sources;ExcludeDependencies;LinkOwnLibraries" "FromDependency" "${ARGN}")
    
    if(
        (NOT DEFINED prop_Name) OR
        ((NOT DEFINED prop_Objects) AND (NOT DEFINED prop_Sources))
      )
        return()
    endif()
    
    if(DEFINED prop_Objects)
        set(precompilatedObjects "\$<TARGET_OBJECTS:${prop_Objects}>")
    endif()
            
    add_executable(${prop_Name} ${prop_Sources} ${precompilatedObjects})
    sbeAddHelpForTarget(Build ${prop_Name} "Build executable ${prop_Name}") 
                    
    get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
    
    if(isSharedLibSupported)
        set_target_properties(${prop_Name}
    	    PROPERTIES
    		    INSTALL_RPATH "$ORIGIN/../lib/:")
    endif()
    
    if(DEFINED prop_LinkOwnLibraries)
        foreach(ownLib ${prop_LinkOwnLibraries}) 
            get_target_property(isGeneratedLibrary ${ownLib} SBE_GENERATED_LIBRARY)
            if(isGeneratedLibrary)
                get_target_property(location ${ownLib} SBE_GENERATED_LIBRARY_LOCATION)
                target_link_libraries(${prop_Name} ${location})
                get_target_property(include ${ownLib} SBE_GENERATED_LIBRARY_HEADERS_DIR)
                target_include_directories(${prop_Name} PRIVATE ${include})
                add_dependencies(${prop_Name} ${ownLib})
            else()
                target_link_libraries(${prop_Name} ${ownLib})
            endif()
        endforeach()
    endif()
    
    string(REPLACE "," ";" prop_FromDependency "${prop_FromDependency}")
    
    sbeAddDependencies(
        Target ${prop_Name} 
        ExcludeDependencies ${prop_ExcludeDependencies}
        PreferHeadersFrom ${prop_PreferHeadersFrom}
        ${prop_FromDependency}) 

    sbeDoesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)

    if(dependenciesContainsDeclspecs)
        _handleDeclSpec(${prop_Name})
    endif()
    
    if (NOT "" STREQUAL "${prop_ConvertToBin}")
        add_custom_command(TARGET ${prop_Name}
            POST_BUILD
            WORKING_DIRECTORY bin
            COMMAND ${CMAKE_HEX} -quiet ${prop_Name}.out -o ${prop_Name}.hex -map ${prop_Name}.mxp ${prop_ConvertToBin}
            COMMAND ${CMAKE_ROOT}/Modules/SBE/toolchains/ti/hex2bin ${prop_Name}.hex
            COMMENT "Converting to bin file"
        )
        set_target_properties(${prop_Name} PROPERTIES BIN_FILE bin/${prop_Name}.bin)
    endif()
    
endfunction()

function(sbeAddTestExecutable)
    sbeParseArguments(prop "" "Name;Objects;Main" "PreferHeadersFrom;Sources;ExcludeDependencies;LinkOwnLibraries" "FromDependency" "${ARGN}")
    
    if(
        (NOT DEFINED prop_Name) OR
        ((NOT DEFINED prop_Objects) AND (NOT DEFINED prop_Sources))
      )
        return()
    endif()
    
    if(DEFINED prop_Objects)
        set(precompilatedObjects "\$<TARGET_OBJECTS:${prop_Objects}>")
    endif()
    
    set(mainFileName "")
    if(DEFINED prop_Main)
        set(mainFileName ${prop_Main})
    else()
        set(mainFileName "${PROJECT_BINARY_DIR}/GeneratedSources/RunAllTests.cpp")
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/CppUTestRunAllTests.cpp.in "${mainFileName}" @ONLY)        
    endif()
             
    add_executable(${prop_Name} ${mainFileName} ${prop_Sources} ${precompilatedObjects})
    sbeAddHelpForTarget(Build ${prop_Name} "Build test executable ${prop_Name}")
                    
    get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
    
    if(isSharedLibSupported)
        set_target_properties(${prop_Name}
    	    PROPERTIES
    		    INSTALL_RPATH "$ORIGIN/../lib/mock/:$ORIGIN/../lib/:")
    endif()

    if(DEFINED prop_LinkOwnLibraries)
        target_link_libraries(${prop_Name} ${prop_LinkOwnLibraries})
    endif()
    
    set_property(TARGET ${prop_Name} PROPERTY SBE_TEST "yes")
    
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "TI" OR "${CMAKE_C_COMPILER_ID}" STREQUAL "TI")
        set_target_properties(${prop_Name} PROPERTIES LINK_FLAGS "--stack_size=0x4000 --heap_size=0x4000")
    endif()
        
    string(REPLACE "," ";" prop_FromDependency "${prop_FromDependency}")
    
    sbeAddDependencies(
        Target ${prop_Name} 
        ExcludeDependencies ${prop_ExcludeDependencies}
        PreferHeadersFrom ${prop_PreferHeadersFrom}
        ${prop_FromDependency}) 

    sbeDoesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)

    if(dependenciesContainsDeclspecs)
        _handleDeclSpec(${prop_Name})
    endif()
endfunction()

function(sbeAddObjects)
    sbeParseArguments(prop "ContainsDeclspec" "Name" "PreferHeadersFrom;Sources" "" "${ARGN}")

    add_library(${prop_Name} OBJECT ${prop_Sources})
    
    add_dependencies(${prop_Name} dependencies)
    
    sbeDoesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)
    
     sbeAddDependenciesIncludes(
        Target ${prop_Name}
        PreferHeadersFrom ${prop_PreferHeadersFrom}) 
        
    if(prop_ContainsDeclspec OR dependenciesContainsDeclspecs)
        _handleDeclSpec(${prop_Name})
    endif()    
endfunction()

function(_handleDeclSpec targetName)
    get_target_property(compilationFlags ${targetName} COMPILE_FLAGS)
    
    if("compilationFlags-NOTFOUND" STREQUAL "${compilationFlags}")
        set(compilationFlags "")
    endif()
    
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC" OR "${CMAKE_C_COMPILER_ID}" STREQUAL "MSVC")
        set(defs "${compilationFlags} -D__EXPORT=__declspec(dllexport) -D__IMPORT=__declspec(dllimport)")
    elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" OR "${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
        set(defs "${compilationFlags} -D__EXPORT= -D__IMPORT=")
    else()
        set(defs "${compilationFlags} -D__EXPORT= -D__IMPORT=")
    endif()

    set_target_properties(${targetName} PROPERTIES COMPILE_FLAGS ${defs})
    set_property(TARGET ${targetName} PROPERTY SBE_CONTAINS_DECLSPEC yes)
endfunction()