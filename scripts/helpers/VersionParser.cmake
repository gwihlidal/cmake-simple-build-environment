if(DEFINED VersionParserGuard)
    return()
endif()

set(VersionParserGuard yes)

function(sbeSplitSemanticVersion version major minor bugfix)
    if("${version}" MATCHES "([0-9]+).([0-9]+).([0-9]+)")
        set(${major} ${CMAKE_MATCH_1} PARENT_SCOPE)
        set(${minor} ${CMAKE_MATCH_2} PARENT_SCOPE)
        set(${bugfix} ${CMAKE_MATCH_3} PARENT_SCOPE)
    endif()
endfunction()
