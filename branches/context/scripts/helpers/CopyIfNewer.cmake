if(NOT DEFINED SOURCE)
    message(SEND_ERROR "SOURCE has to be defined")
endif()

if(NOT DEFINED DESTINATION)
    message(SEND_ERROR "DESTINATION has to be defined")
endif()

if(IS_DIRECTORY ${SOURCE})
    set(isMessagePrinted no)
    if(NOT DEFINED MESSAGE)
        set(isMessagePrinted yes)
    endif()
    
    # remove trailing /
    string(REGEX REPLACE "[/]+$" "" SOURCE "${SOURCE}")
    string(REGEX REPLACE "[/]+$" "" DESTINATION "${DESTINATION}")
        
    file(GLOB_RECURSE sourceFiles RELATIVE ${SOURCE} ${SOURCE}/*)
    file(GLOB_RECURSE destinationFiles RELATIVE ${DESTINATION} ${DESTINATION}/*)
    # remove destination files that are missing in source
    if(NOT "" STREQUAL "${destinationFiles}")
        if(NOT "" STREQUAL "${sourceFiles}")
            list(REMOVE_ITEM destinationFiles ${sourceFiles}) 
        endif()
        foreach(fr ${destinationFiles})
            if(NOT isMessagePrinted)
                message(${MESSAGE})
                set(isMessagePrinted yes)
            endif()
            file(REMOVE ${DESTINATION}/${fr})
        endforeach()
    endif()
    # copy source file only if is newer
    foreach(src ${sourceFiles})
        if(${SOURCE}/${src} IS_NEWER_THAN ${DESTINATION}/${src})
            if(NOT isMessagePrinted)       
                message(${MESSAGE})
                set(isMessagePrinted yes)
            endif()
            execute_process(
                COMMAND ${CMAKE_COMMAND} -E copy ${SOURCE}/${src} ${DESTINATION}/${src}
                RESULT_VARIABLE result)
            if(NOT 0 EQUAL ${result})
                message(FATAL_ERROR "Could not copy ${SOURCE}/${src} to ${DESTINATION}/${src}")
            endif()
        endif()
    endforeach()
    
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



