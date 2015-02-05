cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetAsn1Guard)
    return()
endif()

set(TargetAsn1Guard yes)

include(SBE/helpers/ArgumentParser)

function(sbeAddAsn1Library)
    cmake_parse_arguments(asn1 "" "Name;SkeletonsDirectory;ExportHeadersDirectory" "Source;" ${ARGN})

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
    sbeAddHelpForTarget(Build ${asn1_Name} "Build static library for ${asn1_Source}")
    
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
    add_custom_command(OUTPUT ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build/lib/${asn1_Name}.genlib
	    DEPENDS ${asn1_Source}
	    COMMAND echo "asn1c -fcompound-names -fnative-types -S ${asn1_SkeletonsDirectory} ${PROJECT_SOURCE_DIR}/${asn1_Sources}"
	    COMMAND ${CMAKE_COMMAND} -E remove_directory  ../src
	    COMMAND ${CMAKE_COMMAND} -E remove_directory  ${generatedHeadersDirectory}
	    COMMAND ${CMAKE_COMMAND} -E make_directory  ../src
	    COMMAND ${CMAKE_COMMAND} -E make_directory  ${generatedHeadersDirectory}
	    COMMAND ${CMAKE_COMMAND} -E chdir ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/src asn1c -fcompound-names -fnative-types -S ${asn1_SkeletonsDirectory} ${PROJECT_SOURCE_DIR}/${asn1_Source}
	    COMMAND ${CMAKE_COMMAND} -E copy_directory ../src ${generatedHeadersDirectory}
	    COMMAND ${CMAKE_COMMAND} -E remove ${generatedHeadersDirectory}/*.c
	    COMMAND ${CMAKE_COMMAND} -E remove ${generatedHeadersDirectory}/Makefile*
	    COMMAND ${CMAKE_COMMAND} -E remove ../src/*.h
	    COMMAND ${CMAKE_COMMAND} -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DRULE_LAUNCH_COMPILE=${RULE_LAUNCH_COMPILE} -DRULE_LAUNCH_LINK=${RULE_LAUNCH_LINK} ..
	    COMMAND ${CMAKE_COMMAND} --build . --use-stderr
	    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}/Asn1/${asn1_Name}/build
    )
endfunction()