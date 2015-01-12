cmake_minimum_required(VERSION 2.8)

function(AddPlantUMLForDoxygen file imageDir content modifiedContent)
    get_filename_component(fileName "${file}" NAME_WE)
    get_filename_component(extension "${file}" EXT)
    string(REPLACE "." "_" extension "${extension}")
    set(fileName "${fileName}${extension}")
    
    set(umlContent "")
    set(umlSectionBegin "")
    set(lineNumber 0)
    set(imageName "")
    set(isInUMLSection no)
    set(mc "")
    
    foreach(line ${content})
        if("${line}" MATCHES ".*@enduml[ \t]*$")
            if ("${file}" IS_NEWER_THAN "${imageDir}/${imageName}.txt")
                set(umlContent "${umlContent}${line}\n")
                file(WRITE "${imageDir}/${imageName}.txt" ${umlContent})
                execute_process(
                    COMMAND plantuml -tsvg "${imageDir}/${imageName}.txt"
                RESULT_VARIABLE result)
                execute_process(
                    COMMAND plantuml -teps "${imageDir}/${imageName}.txt"
                RESULT_VARIABLE result)
            endif()
            set(isInUMLSection no)
            set(umlSectionBegin "")
            set(umlContent "")
            set(imageName "")
        elseif(isInUMLSection)
            string(REPLACE "\\[" "[" umlLine "${line}")
            string(REPLACE "\\]" "]" umlLine "${umlLine}")
            set(umlContent "${umlContent}${umlLine}\n")
        elseif("${line}" MATCHES ".*@startuml.*$")
            set(caption "")
            set(anchor "")
            if("${line}" MATCHES ".*@startuml[ \t]*([a-zA-Z0-9_]*)[ \t]*\"(.*)\"[ \t]*$")
                set(anchor ${CMAKE_MATCH_1})
                set(caption ${CMAKE_MATCH_2})
            endif()
            string(REGEX REPLACE "@startuml.*$" "" umlSectionBegin "${line}")
            set(umlContent "${umlSectionBegin}@startuml\n")
            set(imageName "${fileName}_${lineNumber}_plantuml")

            if (NOT "" STREQUAL "${anchor}")
                list(APPEND mc "${umlSectionBegin}\\anchor ${anchor}_Figure")
                list(APPEND mc "${umlSectionBegin}[${anchor}]: @ref ${anchor}_Figure \"${caption}\"")
                list(APPEND mc "${umlSectionBegin}[Fig_${anchor}]: @ref ${anchor}_Figure \"Fig. ${caption}\"")
            endif()
            
            list(APPEND mc "${umlSectionBegin}\\image html ${imageDir}/${imageName}.svg \"${caption}\"")
            list(APPEND mc "${umlSectionBegin}\\image latex ${imageDir}/${imageName}.eps \"${caption}\" scale=0.5")          
            
            set(isInUMLSection yes)
        else()
            list(APPEND mc "${line}")
        endif()
        
        math(EXPR lineNumber "${lineNumber} + 1")
    endforeach()
    
    set(${modifiedContent} "${mc}" PARENT_SCOPE)
endfunction()
 

