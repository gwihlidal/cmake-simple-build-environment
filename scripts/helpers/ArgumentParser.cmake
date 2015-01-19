cmake_minimum_required(VERSION 2.8)

if (DEFINED ArgumentParserGuard)
    return()
endif()

set(ArgumentParserGuard yes)

include (CMakeParseArguments)

macro(sbeReportErrorWhenFileDoesntExists)
    cmake_parse_arguments(err "" "File" "Message" ${ARGN})
    
    if(NOT DEFINED ${err_File} OR NOT EXISTS ${${err_File}})
        message(FATAL_ERROR ${err_Message})
    endif()
    
    unset(err_File)
    unset(err_Message)
endmacro()

macro(sbeReportErrorWhenVariablesNotDefined)
    cmake_parse_arguments(err "" "" "OneOf;Var;Message" ${ARGN})
    
    foreach(var ${err_Var})
        if(NOT DEFINED ${var})
            message(FATAL_ERROR ${err_Message})
        endif()
    endforeach()
    
    foreach(var ${err_OneOf})
        if(DEFINED ${var})
           break()
        endif()
    endforeach()
    
    unset(err_Var)
    unset(err_Message)
endmacro()

macro(sbeParseArguments prefix options oneArg multiArg multiOccurrence args)
    
    set(defaultArgs ${args})
    
    foreach(occurrence ${multiOccurrence})
        set(otherOccurrencies ${multiOccurrence})
        list(REMOVE_ITEM otherOccurrencies ${occurrence})
        set(allOtherArgs ${options} ${oneArg} ${multiArg} ${otherOccurrencies})
            
        set(occurrenceAllOutput "")
        set(occurrenceOutput "")
        set(add "no")
        foreach(arg ${defaultArgs})
            if ("${arg}" STREQUAL "${occurrence}")
                if (add)
                    string(REPLACE "${occurrenceOutput}" "" defaultArgs "${defaultArgs}")
                    string(REPLACE ";" "," occurrenceOutput "${occurrenceOutput}")
                    list(APPEND occurrenceAllOutput ${occurrenceOutput})
                    set(occurrenceOutput "")
                endif()
                set(add "yes")
            endif()
            
            list(FIND allOtherArgs ${arg} isFound)

            if(isFound EQUAL -1 AND add)
                list(APPEND occurrenceOutput ${arg})
            else()
                if (add)
                    string(REPLACE "${occurrenceOutput}" "" defaultArgs "${defaultArgs}")
                    string(REPLACE ";" "," occurrenceOutput "${occurrenceOutput}")
                    list(APPEND occurrenceAllOutput ${occurrenceOutput})
                    set(add "no")
                    set(occurrenceOutput "")
                endif()
            endif()
        endforeach()
        
         if (add)
            string(REPLACE "${occurrenceOutput}" "" defaultArgs "${defaultArgs}")
            string(REPLACE ";" "," occurrenceOutput "${occurrenceOutput}")
            list(APPEND occurrenceAllOutput ${occurrenceOutput})
        endif()
                
        set(${prefix}_${occurrence} ${occurrenceAllOutput})
    endforeach()
    
    CMAKE_PARSE_ARGUMENTS(${prefix} "${options}" "${oneArg}" "${multiArg}" "${defaultArgs}")
endmacro()

