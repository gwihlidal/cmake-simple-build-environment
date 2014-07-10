if(NOT DEFINED SOURCE)
    message(SEND_ERROR "SOURCE has to be defined")
endif()

if(NOT DEFINED DESTINATION)
    message(SEND_ERROR "DESTINATION has to be defined")
endif()

if(${SOURCE} IS_NEWER_THAN ${DESTINATION})
    if(DEFINED MESSAGE)
        message(${MESSAGE})
    endif()
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E copy ${SOURCE} ${DESTINATION}
        RESULT_VARIABLE result)
    if(NOT 0 EQUAL ${result})
        message(FATAL_ERROR "")
    endif()
    if(DEFINED TIMESTAMP_FILE)
        execute_process(
        COMMAND ${CMAKE_COMMAND} -E touch ${TIMESTAMP_FILE})
    endif()
endif()     



