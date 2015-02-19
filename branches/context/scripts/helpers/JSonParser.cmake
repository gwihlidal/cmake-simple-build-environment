cmake_minimum_required(VERSION 2.8)

if (DEFINED JSonParserGuard)
    return()
endif()

set(JSonParserGuard yes)

macro(sbeParseJson prefix jsonString)
    cmake_policy(PUSH)

    set(json_string ${jsonString})    
    
    string(LENGTH ${json_string} json_jsonLen)
    set(json_index 0)
    set(json_AllVariables ${prefix})

    _sbeParse(${prefix})
    
    unset(json_index)
    unset(json_AllVariables)
    unset(json_jsonLen)
    unset(json_string)
    unset(json_value)
    unset(json_inValue)    
    unset(json_name)
    unset(json_inName)
    unset(json_newPrefix)
    unset(json_nextChar)
    unset(json_nextIndex)
    unset(json_reservedWord)
    unset(json_arrayIndex)
    unset(json_char)
    unset(json_end)
    cmake_policy(POP)
endmacro()

macro(sbeClearJson prefix)
    foreach(var ${${prefix}})
        unset(${var})
    endforeach()
    
    unset(${prefix})
endmacro()

macro(sbePrintJson prefix)
    foreach(var ${${prefix}})
        message("${var} = ${${var}}")
    endforeach()
    
    unset(${prefix})
endmacro()

macro(_sbeParse prefix)

    while(${json_index} LESS ${json_jsonLen})
        string(SUBSTRING ${json_string} ${json_index} 1 json_char)
        
        if("\"" STREQUAL "${json_char}")    
            _sbeParseNameValue(${prefix})
        elseif("{" STREQUAL "${json_char}")
            math(EXPR json_index "${json_index} + 1")
            _sbeParseObject(${prefix})
        elseif("[" STREQUAL "${json_char}")
            math(EXPR json_index "${json_index} + 1")
            _sbeParseArray(${prefix})
        endif()

        if(${json_index} LESS ${json_jsonLen})
            string(SUBSTRING ${json_string} ${json_index} 1 json_char)
        else()
            break()
        endif()

        if ("}" STREQUAL "${json_char}" OR "]" STREQUAL "${json_char}")
            break()
        endif()
        
        math(EXPR json_index "${json_index} + 1")
    endwhile()    
endmacro()

macro(_sbeParseNameValue prefix)
    set(json_name "")
    set(json_inName no)

    while(${json_index} LESS ${json_jsonLen})
        string(SUBSTRING ${json_string} ${json_index} 1 json_char)
        
        # check if name ends
        if("\"" STREQUAL "${json_char}" AND json_inName)
            set(json_inName no)
            math(EXPR json_index "${json_index} + 1")
            string(SUBSTRING ${json_string} ${json_index} 1 json_char)
            set(json_newPrefix ${prefix}.${json_name})
            set(json_name "")
            
            if(":" STREQUAL "${json_char}")
                math(EXPR json_nextIndex "${json_index} + 1")
                string(SUBSTRING ${json_string} ${json_nextIndex} 1 json_nextChar)

                if("\"" STREQUAL "${json_nextChar}")    
                    _sbeParseValue(${json_newPrefix})
                    break()
                elseif("{" STREQUAL "${json_nextChar}")
                    math(EXPR json_index "${json_index} + 2")
                    _sbeParseObject(${json_newPrefix})
                    break()
                elseif("[" STREQUAL "${json_nextChar}")
                    math(EXPR json_index "${json_index} + 2")
                    _sbeParseArray(${json_newPrefix})
                    break()
                else()
                    # reserved word starts
                    math(EXPR json_index "${json_index} + 1")
                    set(json_reservedWord "")
                    set(json_end no)
                    while(json_index LESS ${json_jsonLen} AND NOT json_end)
                        string(SUBSTRING ${json_string} ${json_index} 1 json_char)
                        
                        if("," STREQUAL "${json_char}" OR "}" STREQUAL "${json_char}" OR "]" STREQUAL "${json_char}")
                            set(json_end yes)
                        else()
                            set(json_reservedWord "${json_reservedWord}${json_char}")
                            math(EXPR json_index "${json_index} + 1")
                        endif()
                    endwhile()

                    list(APPEND ${json_AllVariables} ${json_newPrefix})
                    set(${json_newPrefix} ${json_reservedWord})
                    break()
                endif()
            else()
                # name without value
                list(APPEND ${json_AllVariables} ${json_newPrefix})
                set(${json_newPrefix} "")
                break()            
            endif()           
        endif()

        if(json_inName)
            # escapes remove
            if("\\" STREQUAL "${json_char}")
                math(EXPR json_index "${json_index} + 1")
                string(SUBSTRING ${json_string} ${json_index} 1 json_char)
            endif()
        
            set(json_name "${json_name}${json_char}")
        endif()
        
        # check if name starts
        if("\"" STREQUAL "${json_char}" AND NOT json_inName)
            set(json_inName yes)
        endif()
       
        math(EXPR json_index "${json_index} + 1")
    endwhile()    
endmacro()

macro(_sbeParseValue prefix)
    cmake_policy(SET CMP0054 NEW) # turn off implicit expansions in if statement
    
    set(json_value "")
    set(json_inValue no)
    
    while(${json_index} LESS ${json_jsonLen})
        string(SUBSTRING ${json_string} ${json_index} 1 json_char)

        # check if json_value ends
        if("\"" STREQUAL "${json_char}" AND json_inValue)
            set(json_inValue no)
            
            set(${prefix} ${json_value})
            list(APPEND ${json_AllVariables} ${prefix})
            math(EXPR json_index "${json_index} + 1")
            break()
        endif()
                
        if(json_inValue)
            # escapes remove
            if("\\" STREQUAL "${json_char}")
                math(EXPR json_index "${json_index} + 1")
                string(SUBSTRING ${json_string} ${json_index} 1 json_char)
            endif()      
              
            set(json_value "${json_value}${json_char}")
        endif()
        
        # check if value starts
        if("\"" STREQUAL "${json_char}" AND NOT json_inValue)
            set(json_inValue yes)
        endif()
        
        math(EXPR json_index "${json_index} + 1")
    endwhile()
    
endmacro()

macro(_sbeParseObject prefix)
    _sbeParse(${prefix})
    math(EXPR json_index "${json_index} + 1")
endmacro()

macro(_sbeParseArray prefix)
    set(json_arrayIndex 0)

    set(${prefix} "")
    list(APPEND ${json_AllVariables} ${prefix})

    while(${json_index} LESS ${json_jsonLen})
        string(SUBSTRING ${json_string} ${json_index} 1 json_char)
        
        if("\"" STREQUAL "${json_char}")
            # simple value
            list(APPEND ${prefix} ${json_arrayIndex})
            _sbeParseValue(${prefix}[${json_arrayIndex}])
        elseif("{" STREQUAL "${json_char}")
            # object
            math(EXPR json_index "${json_index} + 1")
            list(APPEND ${prefix} ${json_arrayIndex})
            _sbeParseObject(${prefix}[${json_arrayIndex}])
        endif()
        
        string(SUBSTRING ${json_string} ${json_index} 1 json_char)
        
        if("]" STREQUAL "${json_char}")
            math(EXPR json_index "${json_index} + 1")
            break()
        elseif("," STREQUAL "${json_char}")
            math(EXPR json_arrayIndex "${json_arrayIndex} + 1")            
        endif()

        math(EXPR json_index "${json_index} + 1")
    endwhile()    

endmacro()
