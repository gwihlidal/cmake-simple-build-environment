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
    
    file(READ ${SOURCE} context)
    string(REGEX REPLACE "([^a-zA-Z0-9_]*)__EXPORT([ \t]+)" "\\1__IMPORT\\2" replacedContext "${context}")
    string(REPLACE ";" "\\;" replacedContext "${replacedContext}")
    file(WRITE ${DESTINATION} ${replacedContext})
endif()     



