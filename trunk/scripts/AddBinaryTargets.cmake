cmake_minimum_required(VERSION 2.8)

if(CMAKE_TOOLCHAIN_FILE)
endif()

# set AddBinaryTargets script usage flag, for checking dependencies between scripts
set(AddBinaryTargetsIncluded "yes")

set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
set (CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
set (CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib) 

if(("${SOURCE_FILES}" STREQUAL "") AND ("${SOURCE_FILES_OUTOF_TEST}" STREQUAL ""))
    return()
endif()

set(sourceObjects "")

if(NOT "${SOURCE_FILES}" STREQUAL "")
    add_library(${PROJECT_NAME}SourceObjects OBJECT ${SOURCE_FILES})
endif()    

get_property(isSharedLibSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)

if("${TYPE}" STREQUAL "Library")
    if(${isSharedLibSupported})
    
        add_library(${PROJECT_NAME} SHARED ${SOURCE_FILES_OUTOF_TEST} $<TARGET_OBJECTS:${PROJECT_NAME}SourceObjects>)
        
        set_target_properties(${PROJECT_NAME}
    	    PROPERTIES
    		    # create *nix style library versions + symbolic links
    		    VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
    		    SOVERSION ${VERSION_MAJOR}.${VERSION_MINOR}
    		    INSTALL_RPATH ".")
    		    
        if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC" OR "${CMAKE_C_COMPILER_ID}" STREQUAL "MSVC")
            set(IES "__declspec(dllexport)")
            configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ImportExportSpecifier.h.in "${PROJECT_BINARY_DIR}/GeneratedSources/ImportExportSpecifier.h" @ONLY)
        else()
            set(IES "")
            configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ImportExportSpecifier.h.in "${PROJECT_BINARY_DIR}/GeneratedSources/ImportExportSpecifier.h" @ONLY)            
        endif()
        
        include_directories(${PROJECT_BINARY_DIR}/GeneratedSources)
    else()
        add_library(${PROJECT_NAME} STATIC ${SOURCE_FILES_OUTOF_TEST} $<TARGET_OBJECTS:${PROJECT_NAME}SourceObjects>)
	endif()
	
    set(INSTALL_LIBRARIES ${PROJECT_NAME})	    
elseif("${TYPE}" STREQUAL "Executable")

    add_executable(${PROJECT_NAME} ${SOURCE_FILES_OUTOF_TEST} $<TARGET_OBJECTS:${PROJECT_NAME}SourceObjects>)

    if(${isSharedLibSupported})
        set_target_properties(${PROJECT_NAME}
    	    PROPERTIES
    		    INSTALL_RPATH "../lib")
    endif()
    set(INSTALL_EXECUTABLE ${PROJECT_NAME})
else()
    return()    
endif()

include_directories(${CMAKE_SOURCE_DIR}/src)

set(DEP_TARGET ${PROJECT_NAME})
set(DEP_TYPES_TO_ADD "Library" "Project")
include(SBE/helpers/AddDependenciesToTarget)

