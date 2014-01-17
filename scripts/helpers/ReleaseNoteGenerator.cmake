
MACRO (GET_CURRENT_TIME RESULT)
    IF (WIN32)
        EXECUTE_PROCESS(COMMAND "cmd" " /C date /T" OUTPUT_VARIABLE ${RESULT})
        string(REGEX REPLACE "(..)/(..)/..(..).*" "\\1/\\2/\\3" ${RESULT} ${${RESULT}})
    ELSEIF(UNIX)
        EXECUTE_PROCESS(COMMAND "date" OUTPUT_VARIABLE ${RESULT})
        string(REPLACE "\n" "" ${RESULT} ${${RESULT}})
    ELSE (WIN32)
        MESSAGE(SEND_ERROR "date not implemented")
        SET(${RESULT} 000000)
    ENDIF (WIN32)
ENDMACRO (GET_CURRENT_TIME)

MACRO (GET_USER RESULT)
    IF (WIN32)
        set(${RESULT} "$ENV{USERNAME}")
    ELSEIF(UNIX)
        set(${RESULT} "$ENV{USER}")
    ELSE ()
        MESSAGE(SEND_ERROR "user unknown")
        SET(${RESULT} "unknown")
    ENDIF ()
ENDMACRO (GET_USER)

function(GenerateReleaseNote svnRoot projectName tagName changelog)
    GET_USER(user)
    GET_CURRENT_TIME(time)
    
    # add first line
    set(${changelog} "${tagName} (${user} on ${time})" PARENT_SCOPE)
    
#    # add issues for jira
#    find_program(CURL NAMES curl)
#    
#    if("CURL-NOTFOUND" STREQUAL "${CURL}")
#        message("Curl not found. Not possible to get info from Jira.")
#        return()
#    endif()
#
#    set(issues PMC-620 PMC-171 PMC-21 PMC-489)
#    
#    foreach(issue ${issues})
#        execute_process(
#            COMMAND ${CURL} 
#                -x "" 
#                -s 
#                -u restapi_sbellus:AlwaysR3st-NeverCh1ll 
#                -X GET "Content-Type: application/json" 
#                http://jira.frequentis.frq:8080/rest/api/2/issue/${issue}
#                OUTPUT_VARIABLE issueJson
#            )
#            
#        set(summaryRegexp "\"summary\":\"([^\"]+)\"")
#        string(REGEX MATCH ${summaryRegexp} summary "${issueJson}")
#        set(summary ${CMAKE_MATCH_1})
#    
#        set(statusRegexp "\"status\":{\"self\":\"[^\"]*\",\"description\":\"[^\"]*\",\"iconUrl\":\"[^\"]*\",\"name\":\"([^\"]*)\",\"id\":\"[0-9]*\"}")
#        string(REGEX MATCH ${statusRegexp} status "${issueJson}")
#        set(status ${CMAKE_MATCH_1})
#    
#        set(typeRegexp "\"issuetype\":{\"self\":\"[^\"]*\",\"id\":\"[^\"]*\",\"description\":\"[^\"]*\",\"iconUrl\":\"[^\"]*\",\"name\":\"([^\"]*)\",\"subtask\":[a-z]*}")
#        string(REGEX MATCH ${typeRegexp} type "${issueJson}")
#        set(type ${CMAKE_MATCH_1})
#    
#        set(projectNameRegexp "\"project\":{\"self\":\"[^\"]*\",\"id\":\"[0-9]*\",\"key\":\"[^\"]*\",\"name\":\"([^\"]*)\"")
#        string(REGEX MATCH ${projectNameRegexp} projectName "${issueJson}")
#        set(projectName ${CMAKE_MATCH_1})
#        
#        set(parentRegexp "\"parent\":{\"id\":\"[0-9]*\",\"key\":\"([^\"]*)\"")
#        string(REGEX MATCH ${parentRegexp} parent "${issueJson}")
#        set(parent ${CMAKE_MATCH_1})
#        
#        message(
#            "${issue}\n"
#            "   ${summary}\n"
#            "   ${status}\n"
#            "   ${type}\n"
#            "   ${projectName}\n"
#            "   ${parent}")
#    endforeach()
    
endfunction(GenerateReleaseNote)

# GenerateReleaseNote("" "" "" mmm)
