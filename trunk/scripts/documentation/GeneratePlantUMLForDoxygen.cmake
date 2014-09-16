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
            string(REPLACE "\\[" "[" umlLine "${line}")
            string(REPLACE "\\]" "]" umlLine "${umlLine}")
            set(umlContent "${umlContent}${umlLine}\n")
        elseif("${line}" MATCHES ".*@startuml.*$")
            set(caption "")
            if("${line}" MATCHES ".*@startuml[ \t]*\"(.*)\"[ \t]*$")
                set(caption ${CMAKE_MATCH_1})
            endif()
            string(REGEX REPLACE "@startuml.*$" "" umlSectionBegin "${line}")
            set(umlContent "${umlSectionBegin}@startuml\n")
            set(imageName "${fileName}_${lineNumber}_plantuml")

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
 

