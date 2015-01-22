cmake_minimum_required(VERSION 2.8)

if(DEFINED TargetTagGuard)
    return()
endif()

set(TargetTagGuard yes)

function(sbeAddTagTarget)
    set(uid "")
    set(force "")
    set(releaseNoteOverview "")
    set(cc "")
    
    if("Windows" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}")
        set(uid "\$(ADD_UNIQUE_ID)")
        set(force "\$(FORCE)")
        set(releaseNoteOverview "\$(RELEASE_NOTE_OVERVIEW)")
        set(cc "\$(COMMIT_COMMENT)")
    elseif("Linux" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}")
        set(uid "\${ADD_UNIQUE_ID}")
        set(force "\${FORCE}")
        set(releaseNoteOverview "\${RELEASE_NOTE_OVERVIEW}")
        set(cc "\${COMMIT_COMMENT}")
    endif()
    
    get_property(ContextFile GLOBAL PROPERTY ContextFile)
    string(REPLACE ";" "," OverallDependenciesAsArgument "${OverallDependencies}") 
            
    add_custom_target(tag
        COMMAND ${CMAKE_COMMAND}
            -DCOMMIT_COMMENT=${cc}
            -DRELEASE_NOTE_OVERVIEW=${releaseNoteOverview}
            -DADD_UNIQUE_ID=${uid}
            -DFORCE=${force}
            -DOverallDependencies=${OverallDependenciesAsArgument}
            -DContextFile=${ContextFile}
            -DPackageRootDirectory=${PROJECT_SOURCE_DIR}
            -P ${CMAKE_ROOT}/Modules/SBE/helpers/TagSources.cmake
            )
endfunction()            
