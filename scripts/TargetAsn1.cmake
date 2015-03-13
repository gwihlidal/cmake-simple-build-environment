cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetAsn1Guard)
    return()
endif()

set(TargetAsn1Guard yes)

include(SBE/helpers/ArgumentParser)

function(sbeAddAsn1Library)
    cmake_parse_arguments(asn1 "" "Name;SkeletonsDirectory;ExportHeadersDirectory" "Source;" ${ARGN})

    if(NOT DEFINED ASN1_COMPILER)
        find_program(ASN1_COMPILER asn1c HINTS /usr/local/share/cross-compilers/asn1c/*)
        
        if(DEFINED ASN1_COMPILER-NOTFOUND)
            message(FATAL_ERROR "Asn1 compiler is not found in PATH and /usr/local/share/cross-compilers/asn1c/*")
        else()
            message(STATUS "Asn1 compiler found ${ASN1_COMPILER}")
        endif()
    endif() 
    
    file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build)
    
    set(generatedHeadersDirectory "${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/inc")
    if(DEFINED asn1_ExportHeadersDirectory)
        set(generatedHeadersDirectory "${PROJECT_BINARY_DIR}/Export/include/${asn1_ExportHeadersDirectory}")
    endif()
    
    set(genLibraryName ${asn1_Name})
    set(genLibraryIncludeDirs ${asn1_SkeletonsDirectory} ${generatedHeadersDirectory})
    set(genLibrarySourceDir ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/src)
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/Asn1CMakeLists.txt.in "${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/CMakeLists.txt" @ONLY)

    add_custom_target(${asn1_Name} DEPENDS ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build/lib/${asn1_Name}.genlib)
    
    set_target_properties(${asn1_Name} PROPERTIES
      SBE_GENERATED_LIBRARY TRUE
      SBE_GENERATED_LIBRARY_LOCATION "${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build/lib/${asn1_Name}.genlib"
      SBE_GENERATED_LIBRARY_HEADERS_DIR  "${generatedHeadersDirectory}"
      )
    if(DEFINED asn1_ExportHeadersDirectory)
        set_target_properties(${asn1_Name} PROPERTIES
          SBE_GENERATED_LIBRARY_EXPORT_HEADERS_DIR  "${generatedHeadersDirectory}"
          )
    endif()      
    add_custom_command(OUTPUT ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build/projectIsGenerated
	    DEPENDS ${asn1_Source}
	    COMMAND ${CMAKE_COMMAND} -E remove_directory  ../src
	    COMMAND ${CMAKE_COMMAND} -E remove_directory  ${generatedHeadersDirectory}
	    COMMAND ${CMAKE_COMMAND} -E make_directory  ../src
	    COMMAND ${CMAKE_COMMAND} -E make_directory  ${generatedHeadersDirectory}
	    COMMAND ${CMAKE_COMMAND} -E chdir ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/src ${ASN1_COMPILER} -fcompound-names -fnative-types -S ${asn1_SkeletonsDirectory} ${PROJECT_SOURCE_DIR}/${asn1_Source}
	    COMMAND ${CMAKE_COMMAND} -E copy_directory ../src ${generatedHeadersDirectory}
	    COMMAND ${CMAKE_COMMAND} -E remove ${generatedHeadersDirectory}/*.c
	    COMMAND ${CMAKE_COMMAND} -E remove ${generatedHeadersDirectory}/Makefile*
	    COMMAND ${CMAKE_COMMAND} -E remove ../src/*.h
	    COMMAND ${CMAKE_COMMAND} -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DRULE_LAUNCH_COMPILE=${RULE_LAUNCH_COMPILE} -DRULE_LAUNCH_LINK=${RULE_LAUNCH_LINK} ..
	    COMMAND ${CMAKE_COMMAND} -E touch projectIsGenerated
	    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build
	    COMMENT "Generating Asn1 C files"
    )
    add_custom_command(OUTPUT ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build/lib/${asn1_Name}.genlib
	    DEPENDS ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build/projectIsGenerated
	    COMMAND + ${CMAKE_COMMAND} --build ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build --use-stderr
	    COMMENT "Compiling Asn1 C files"
    )    
endfunction()