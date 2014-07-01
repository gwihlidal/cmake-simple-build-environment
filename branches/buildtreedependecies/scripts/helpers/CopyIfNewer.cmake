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
        COMMAND ${CMAKE_COMMAND} -E copy ${SOURCE} ${DESTINATION})
endif()     



