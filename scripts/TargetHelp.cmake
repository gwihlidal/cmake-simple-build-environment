cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetHelpGuard)
    return()
endif()

set(TargetHelpGuard yes)

set(targetsHelpFile ${PROJECT_BINARY_DIR}/help/targetsHelp.cmake)
file(REMOVE ${targetsHelpFile})

function(sbeAddHelpForTarget group target help)
    set(content
        "list(APPEND Groups ${group})\n"
        "list(REMOVE_DUPLICATES Groups)\n"
        "list(APPEND ${group}_Targets ${target})\n"
        "set(${group}_${target}_Help \"${help}\")\n"
    )
    file(APPEND ${targetsHelpFile} ${content})
endfunction()

function(sbeAddHelpTarget)
    add_custom_target(targets
        COMMAND ${CMAKE_COMMAND} -DFile=${targetsHelpFile} -P ${CMAKE_ROOT}/Modules/SBE/helpers/PrintHelp.cmake
        COMMENT "")    
endfunction()