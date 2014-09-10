cmake_minimum_required(VERSION 2.8)

function(AddPlantUMLForDoxygen file imageDir content modifiedContent)
    get_filename_component(fileName "${file}" NAME_WE)
    
    set(umlContent "")
    set(umlSectionBegin "")
    set(lineNumber 0)
    set(imageName "")
    set(isInUMLSection no)
    
    foreach(line ${content})
        if("${line}" MATCHES ".*@enduml[ \t]*$")
            list(REMOVE_AT content ${lineNumber})
            list(INSERT content ${lineNumber} "${umlSectionBegin}")
        
            set(umlContent "${umlContent}${line}\n")
            file(WRITE "${IMAGE_DIR}/${imageName}.txt" ${umlContent})
            execute_process(
                COMMAND plantuml -tsvg "${IMAGE_DIR}/${imageName}.txt"
            RESULT_VARIABLE result)
            execute_process(
                COMMAND plantuml -teps "${IMAGE_DIR}/${imageName}.txt"
            RESULT_VARIABLE result)
            set(isInUMLSection no)
            set(umlSectionBegin "")
            set(umlContent "")
            set(imageName "")
        elseif(isInUMLSection)
            set(umlContent "${umlContent}${line}\n")
            list(REMOVE_AT content ${lineNumber})
            list(INSERT content ${lineNumber} "${umlSectionBegin}")
        elseif("${line}" MATCHES ".*@startuml.*$")
            set(caption "")
            if("${line}" MATCHES ".*@startuml[ \t]*\"(.*)\"[ \t]*$")
                set(caption ${CMAKE_MATCH_1})
            endif()
            string(REGEX REPLACE "@startuml.*$" "" umlSectionBegin "${line}")
            set(umlContent "${umlSectionBegin}@startuml\n")
            set(imageName "${fileName}_${lineNumber}_plantuml")
            list(REMOVE_AT content ${lineNumber})
            list(INSERT content ${lineNumber} "${umlSectionBegin}\\image html ${imageDir}/${imageName}.svg \"${caption}\"\n${umlSectionBegin}\\image latex ${imageDir}/${imageName}.eps \"${caption}\" scale=0.5 \n${umlSectionBegin}")
            set(isInUMLSection yes)
        endif()
        
        math(EXPR lineNumber "${lineNumber} + 1")
    endforeach()
    
    set(${modifiedContent} "${content}" PARENT_SCOPE)
endfunction()
 

