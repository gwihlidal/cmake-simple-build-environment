cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED FILE_TO_CHECK OR NOT EXISTS ${FILE_TO_CHECK})
    return()
endif()

if(NOT DEFINED IMAGE_DIR)
    return()
endif()

include(SBE/documentation/AddReferencedIssuesSectionForDoxygen)
include(SBE/documentation/ConvertIssuesToLinksForDoxygen)
include(SBE/documentation/GeneratePlantUMLForDoxygen)

# get file content
file(READ ${FILE_TO_CHECK} content)
# make list of lines
string(REPLACE ";" "##-##-##" content "${content}")
# character [ and ] somhow corupts list
string(REPLACE "[" "\\[" content "${content}")
string(REPLACE "]" "\\]" content "${content}")
string(REPLACE "\n" ";" content "${content}")
# do not allow empty lines
string(REPLACE ";;" ";ee-ee-ee;" content "${content}")


AddPlantUMLForDoxygen(${FILE_TO_CHECK} "${IMAGE_DIR}" "${content}" modifiedContent)
AddReferencedIssuesSection(${FILE_TO_CHECK} "${modifiedContent}" modifiedContent)
ConvertIssuesToLinksForDoxygen(${FILE_TO_CHECK} "${modifiedContent}" modifiedContent)


string(REPLACE ";" "\n" modifiedContent "${modifiedContent}")
string(REPLACE "ee-ee-ee"  "" modifiedContent "${modifiedContent}")
string(REPLACE "##-##-##"  ";" modifiedContent "${modifiedContent}")
string(REPLACE "\\[" "[" modifiedContent "${modifiedContent}")
string(REPLACE "\\]" "]" modifiedContent "${modifiedContent}")
execute_process(COMMAND ${CMAKE_COMMAND} -E echo "${modifiedContent}")
 

