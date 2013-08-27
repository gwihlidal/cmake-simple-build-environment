cmake_minimum_required(VERSION 2.8)


function(addTestTarget)
    CMAKE_PARSE_ARGUMENTS(test "" "Executable" "" ${ARGN})
    
    if(${CMAKE_CROSSCOMPILING})
        add_custom_target(test COMMENT "Not possible to run test because of cross-compiling." DEPENDS ${test_Executable})
    else()
        set(testOptions "")
        if("Windows" STREQUAL "${CMAKE_SYSTEM_NAME}")
            set(testOptions "\$(CPPUTEST_FLAGS)")
            
            add_custom_target(test
                COMMAND set "PATH=%PATH%;${CMAKE_CURRENT_BINARY_DIR}/dependencies/installation/bin" 
                COMMAND cmake -E remove -f cpputest_*.xml 
                COMMAND bin/${test_Executable} ${testOptions}
                DEPENDS ${test_Executable})
        elseif("Linux" STREQUAL "${CMAKE_SYSTEM_NAME}")
            set(testOptions "\${CPPUTEST_FLAGS}")
            add_custom_target(test
                COMMAND cmake -E remove -f cpputest_*.xml 
                COMMAND bin/${test_Executable} ${testOptions}
                DEPENDS ${test_Executable})
        endif()
        

    endif()
endfunction()        