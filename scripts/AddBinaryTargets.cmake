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


function(addBinaryTarget)
    sbeParseArguments(bt "HANDLE_DECLSPEC;STATIC_LIBRARY" "TARGET_NAME;TARGET_TYPE;OBJECT_LIBRARY" "SOURCES;DEPENDENCY_TYPES_TO_LINK;PUBLIC_HEADERS" "FromDependency;FromXXX" "${ARGN}")

    if(
        (NOT DEFINED bt_TARGET_NAME) OR
        (NOT DEFINED bt_TARGET_TYPE) OR
        ((NOT DEFINED bt_OBJECT_LIBRARY) AND (NOT DEFINED bt_SOURCES))
      )
        return()
    endif()
    
    if(NOT DEFINED bt_DEPENDENCY_TYPES_TO_LINK)
        if("Test Executable" STREQUAL "${bt_TARGET_TYPE}")
            set(bt_DEPENDENCY_TYPES_TO_LINK "Library" "Project" "Unit Test Framework")
        else()
            set(bt_DEPENDENCY_TYPES_TO_LINK "Library" "Project")
        endif()
    endif()  
    
    if(DEFINED bt_OBJECT_LIBRARY)
        set(precompilatedObjects "\$<TARGET_OBJECTS:${bt_OBJECT_LIBRARY}>")
    endif()
    
    if("${bt_TARGET_TYPE}" STREQUAL "Library")
    
        _addLibraryTarget(
            NAME ${bt_TARGET_NAME}
            SOURCES ${bt_SOURCES}
            OBJECTS ${precompilatedObjects} 
            PUBLIC_HEADERS ${bt_PUBLIC_HEADERS}
            DEPENDENCY_TYPES_TO_LINK ${bt_DEPENDENCY_TYPES_TO_LINK}
            HANDLE_DECLSPEC ${bt_HANDLE_DECLSPEC}
            STATIC_LIBRARY ${bt_STATIC_LIBRARY})
            
    elseif("${bt_TARGET_TYPE}" STREQUAL "Executable")
    
        _addExecutable(
            NAME ${bt_TARGET_NAME}
            SOURCES ${bt_SOURCES}
            OBJECTS ${precompilatedObjects} 
            DEPENDENCY_TYPES_TO_LINK ${bt_DEPENDENCY_TYPES_TO_LINK})
            
    elseif("${bt_TARGET_TYPE}" STREQUAL "Test Executable")
    
        _addExecutable(
            NAME ${bt_TARGET_NAME}
            SOURCES ${bt_SOURCES}
            OBJECTS ${precompilatedObjects} 
            DEPENDENCY_TYPES_TO_LINK ${bt_DEPENDENCY_TYPES_TO_LINK}
            TEST)
            
    elseif("${bt_TARGET_TYPE}" STREQUAL "Object Library")
    
        _addObjectLibrary(
            NAME ${bt_TARGET_NAME}
            SOURCES ${bt_SOURCES}
            HANDLE_DECLSPEC ${bt_HANDLE_DECLSPEC})
    endif()
endfunction()

function(_addLibraryTarget)
    CMAKE_PARSE_ARGUMENTS(lib "" "NAME;HANDLE_DECLSPEC;STATIC_LIBRARY" "SOURCES;OBJECTS;PUBLIC_HEADERS;DEPENDENCY_TYPES_TO_LINK" ${ARGN})
    
    get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
    
    if(isSharedLibSupported AND NOT lib_STATIC_LIBRARY)
        add_library(${lib_NAME} SHARED ${lib_SOURCES} ${lib_OBJECTS})
        
        set_target_properties(${lib_NAME}
    	    PROPERTIES
    		    # create *nix style library versions + symbolic links
    		    VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
    		    SOVERSION ${VERSION_MAJOR}.${VERSION_MINOR}
    		    INSTALL_RPATH ".")
    else()
        add_library(${lib_NAME} STATIC ${lib_SOURCES} ${lib_OBJECTS})            
    endif()
    
    addDependencies(
        TARGET ${lib_NAME} 
        DEPENDENCY_TYPES ${lib_DEPENDENCY_TYPES_TO_LINK} 
        CONTAIN_DECLSPEC_FLAG containsDependnecyDeclspec)

    if(lib_HANDLE_DECLSPEC OR containsDependnecyDeclspec)
        _handleDeclSpec(${lib_NAME})
    endif()
            
    if(DEFINED lib_PUBLIC_HEADERS)
        set_property(TARGET ${lib_NAME} PROPERTY SBE_PUBLIC_HEADERS ${lib_PUBLIC_HEADERS})
    endif()
    
    set_property(TARGET ${lib_NAME} PROPERTY SBE_TYPE "Library")
endfunction()

function(_addExecutable)
    CMAKE_PARSE_ARGUMENTS(exe "TEST" "NAME" "SOURCES;OBJECTS;DEPENDENCY_TYPES_TO_LINK" ${ARGN})
    
    if(exe_TEST)
        configure_file(${CMAKE_ROOT}/Modules/SBE/templates/CppUTestRunAllTests.cpp.in "${PROJECT_BINARY_DIR}/GeneratedSources/RunAllTests.cpp" @ONLY)

        add_executable(${exe_NAME} ${PROJECT_BINARY_DIR}/GeneratedSources/RunAllTests.cpp ${exe_SOURCES} ${exe_OBJECTS})
    
        set_property(TARGET ${exe_NAME} PROPERTY SBE_IS_TEST_TARGET "yes")
        set_property(TARGET ${exe_NAME} PROPERTY SBE_TYPE "Test Executable")
    else()
        add_executable(${exe_NAME} ${exe_SOURCES} ${exe_OBJECTS})
        set_property(TARGET ${exe_NAME} PROPERTY SBE_TYPE "Executable")
    endif()

    get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
        
    if(isSharedLibSupported)
        set_target_properties(${exe_NAME}
    	    PROPERTIES
    		    INSTALL_RPATH "../lib")
    endif()
    
    addDependencies(
        TARGET ${exe_NAME} 
        DEPENDENCY_TYPES ${exe_DEPENDENCY_TYPES_TO_LINK} 
        CONTAIN_DECLSPEC_FLAG containsDependnecyDeclspec)
    
    if(containsDependnecyDeclspec)
        _handleDeclSpec(${exe_NAME})
    endif()
endfunction()

function(_addObjectLibrary)
    CMAKE_PARSE_ARGUMENTS(obj "" "NAME;HANDLE_DECLSPEC" "SOURCES" ${ARGN})
    
    add_library(${obj_NAME} OBJECT ${obj_SOURCES})
    
    doesDependenciesContainsDeclSpecs(dependenciesContainsDeclspecs)
    
    if(obj_HANDLE_DECLSPEC OR dependenciesContainsDeclspecs)
        _handleDeclSpec(${obj_NAME})
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