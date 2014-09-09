cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED FILE_TO_CHECK OR NOT EXISTS ${FILE_TO_CHECK})
    return()
endif()

if(NOT DEFINED IMAGE_DIR)
    return()
endif()
# get file content
file(READ ${FILE_TO_CHECK} content)
# make list of lines
string(REPLACE ";" "##-##-##" content "${content}")
string(REPLACE "\n" ";" content "${content}")
# do not allow empty lines
string(REPLACE ";;" ";ee-ee-ee;" content "${content}")

# search for startuml
# get content up to enduml
# replace content by doxygen image keyword
# generate image from content
get_filename_component(fileName "${FILE_TO_CHECK}" NAME_WE)
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
        list(INSERT content ${lineNumber} "${umlSectionBegin}\\image html ${IMAGE_DIR}/${imageName}.svg \"${caption}\"\n${umlSectionBegin}\\image latex ${IMAGE_DIR}/${imageName}.eps \"${caption}\" scale=0.5 \n${umlSectionBegin}")
        set(isInUMLSection yes)
    endif()
    
    math(EXPR lineNumber "${lineNumber} + 1")
endforeach()

string(REPLACE ";" "\n" content "${content}")
string(REPLACE "ee-ee-ee"  "" content "${content}")
string(REPLACE "##-##-##"  ";" content "${content}")
execute_process(COMMAND ${CMAKE_COMMAND} -E echo "${content}")
 

