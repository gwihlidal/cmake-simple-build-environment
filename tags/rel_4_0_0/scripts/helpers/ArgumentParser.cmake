include (CMakeParseArguments)

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

