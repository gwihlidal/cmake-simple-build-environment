cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetGraphGuard)
    return()
endif()

set(TargetGraphGuard yes)

function(sbeAddGraphTarget)
    add_custom_target(graph)
    
    add_custom_command(TARGET graph
        COMMAND cmake -E remove_directory ${PROJECT_BINARY_DIR}/graph
        COMMAND cmake -E make_directory ${PROJECT_BINARY_DIR}/graph
        COMMAND cmake -DOutputDirectory=${PROJECT_BINARY_DIR}/graph -DContextFile=${ContextFile} -DName=${PROJECT_NAME} -P ${CMAKE_ROOT}/Modules/SBE/helpers/GenerateGraph.cmake 
        COMMENT "Generating Graph...")
    
endfunction()                
