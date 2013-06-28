cmake_minimum_required(VERSION 2.8)


function(addTestTarget)
    CMAKE_PARSE_ARGUMENTS(test "" "EXECUTABLE_NAME" "" ${ARGN})
    
    if(${CMAKE_CROSSCOMPILING})
        add_custom_target(test COMMENT "Not possible to run test because of cross-compiling." DEPENDS ${test_EXECUTABLE_NAME})
    else()
        set(testOptions "")
        if("Windows" STREQUAL "${CMAKE_SYSTEM_NAME}")
            set(testOptions "\$(CPPUTEST_FLAGS)")
        elseif("Linux" STREQUAL "${CMAKE_SYSTEM_NAME}")
            set(testOptions "\${CPPUTEST_FLAGS}")
        endif()
        add_custom_target(test
            COMMAND cmake -E remove -f cpputest_*.xml 
            COMMAND bin/${test_EXECUTABLE_NAME} ${testOptions}
            DEPENDS ${test_EXECUTABLE_NAME})
    endif()
endfunction()        