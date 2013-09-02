if(isAddBinaryTargetsIncluded)
    return()
endif()

set(isAddBinaryTargetsIncluded yes)

include(SBE/helpers/AddDependenciesToTarget)
include(SBE/helpers/ArgumentParser)

set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
set (CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
set (CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)

include_directories(${CMAKE_SOURCE_DIR}/src)

function(sbeAddLibrary)
    sbeParseArguments(prop "ContainsDeclspec;Static" "Name;Objects" "Sources;PublicHeaders" "FromDependency" "${ARGN}")
    
    if(
        (NOT DEFINED prop_Name) OR
        ((NOT DEFINED prop_Objects) AND (NOT DEFINED prop_Sources))
      )
        return()
    endif()
    
    if(DEFINED prop_Objects)
        set(precompilatedObjects "\$<TARGET_OBJECTS:${prop_Objects}>")
    endif()
            
    get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
    
    if(isSharedLibSupported AND NOT prop_Static)
        add_library(${prop_Name} SHARED ${prop_Sources} ${precompilatedObjects})
        
        set_target_properties(${prop_Name}
    	    PROPERTIES
    		    # create *nix style library versions + symbolic links
    		    VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
    		    SOVERSION ${VERSION_MAJOR}.${VERSION_MINOR}
    		    INSTALL_RPATH ".")
    else()
        add_library(${prop_Name} STATIC ${prop_Sources} ${precompilatedObjects})            
    endif()
    
    string(REPLACE "," ";" prop_FromDependency "${prop_FromDependency}")
    
    sbeAddDependencies(
        Target ${prop_Name} 
        DependencyTypesToAdd "Library;Project"
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
    sbeParseArguments(prop "" "Name;Objects" "Sources" "FromDependency" "${ARGN}")
    
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
                    
    get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
    
    if(isSharedLibSupported)
        set_target_properties(${prop_NAME}
    	    PROPERTIES
    		    INSTALL_RPATH "../lib")
    endif()
    
    string(REPLACE "," ";" prop_FromDependency "${prop_FromDependency}")
    
    sbeAddDependencies(
        Target ${prop_Name} 
        DependencyTypesToAdd "Library;Project"
        ${prop_FromDependency}) 

    sbeDoesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)

    if(dependenciesContainsDeclspecs)
        _handleDeclSpec(${prop_Name})
    endif()
endfunction()

function(sbeAddTestExecutable)
    sbeParseArguments(prop "" "Name;Objects" "Sources" "FromDependency" "${ARGN}")
    
    if(
        (NOT DEFINED prop_Name) OR
        ((NOT DEFINED prop_Objects) AND (NOT DEFINED prop_Sources))
      )
        return()
    endif()
    
    if(DEFINED prop_Objects)
        set(precompilatedObjects "\$<TARGET_OBJECTS:${prop_Objects}>")
    endif()
            
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/CppUTestRunAllTests.cpp.in "${PROJECT_BINARY_DIR}/GeneratedSources/RunAllTests.cpp" @ONLY)

    add_executable(${prop_Name} ${PROJECT_BINARY_DIR}/GeneratedSources/RunAllTests.cpp ${prop_Sources} ${precompilatedObjects})
                    
    get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
    
    if(isSharedLibSupported)
        set_target_properties(${prop_NAME}
    	    PROPERTIES
    		    INSTALL_RPATH "../lib")
    endif()
    
    string(REPLACE "," ";" prop_FromDependency "${prop_FromDependency}")
    
    sbeAddDependencies(
        Target ${prop_Name} 
        DependencyTypesToAdd "Library;Project;Unit Test Framework"
        ${prop_FromDependency}) 

    sbeDoesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)

    if(dependenciesContainsDeclspecs)
        _handleDeclSpec(${prop_Name})
    endif()
    
    set_property(TARGET ${prop_Name} PROPERTY TEST "yes")
endfunction()

function(sbeAddObjects)
    sbeParseArguments(prop "ContainsDeclspec" "Name" "Sources" "" "${ARGN}")

    add_library(${prop_Name} OBJECT ${prop_Sources})
    
    sbeDoesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)
    
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
    set_property(TARGET ${targetName} PROPERTY ContainsDeclspec yes)
endfunction()