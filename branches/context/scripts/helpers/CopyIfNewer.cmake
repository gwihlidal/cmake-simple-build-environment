if(NOT DEFINED SOURCE)
    message(SEND_ERROR "SOURCE has to be defined")
endif()

if(NOT DEFINED DESTINATION)
    message(SEND_ERROR "DESTINATION has to be defined")
endif()

if(IS_DIRECTORY ${SOURCE})
    if(DEFINED MESSAGE)
        message(${MESSAGE})
    endif()
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${SOURCE} ${DESTINATION}
        RESULT_VARIABLE result)
    if(NOT 0 EQUAL ${result})
        message(FATAL_ERROR "Could not copy ${SOURCE} to ${DESTINATION}")
    endif()
    if(DEFINED TIMESTAMP_FILE)
        execute_process(
        COMMAND ${CMAKE_COMMAND} -E touch ${TIMESTAMP_FILE})
    endif()
elseif(${SOURCE} IS_NEWER_THAN ${DESTINATION})
    if(DEFINED MESSAGE)
        message(${MESSAGE})
    endif()
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E copy ${SOURCE} ${DESTINATION}
        RESULT_VARIABLE result)
    if(NOT 0 EQUAL ${result})
        message(FATAL_ERROR "Could not copy ${SOURCE} to ${DESTINATION}")
    endif()
    if(DEFINED TIMESTAMP_FILE)
        execute_process(
        COMMAND ${CMAKE_COMMAND} -E touch ${TIMESTAMP_FILE})
    endif()
endif()     



