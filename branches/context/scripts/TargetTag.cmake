cmake_minimum_required(VERSION 2.8)

if(DEFINED TargetTagGuard)
    return()
endif()

set(TargetTagGuard yes)

include(SBE/helpers/ArgumentParser)

function(sbeAddTagTarget)
    cmake_parse_arguments(tag "" "JiraUrl" "JiraProjectKeys" ${ARGN})
    
    set(ending "")
    set(force "")
    set(releaseNoteOverview "")
    set(cc "")
    set(sd "")
    set(st "")
    
    if("Windows" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}")
        set(ending "\$(TAG_ENDING)")
        set(force "\$(FORCE)")
        set(sd "\$(SKIP_DEPENDENCIES)")
        set(releaseNoteOverview "\$(RELEASE_NOTE_OVERVIEW)")
        set(cc "\$(COMMIT_COMMENT)")
        set(st "\$(SWITCH_TO_NEW_TAG)")
    elseif("Linux" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}")
        set(ending "\${TAG_ENDING}")
        set(force "\${FORCE}")
        set(sd "\${SKIP_DEPENDENCIES}")
        set(releaseNoteOverview "\${RELEASE_NOTE_OVERVIEW}")
        set(cc "\${COMMIT_COMMENT}")
        set(st "\${SWITCH_TO_NEW_TAG}")
    endif()
    
    get_property(ContextFile GLOBAL PROPERTY ContextFile)
    string(REPLACE ";" "," OverallDependenciesAsArgument "${OverallDependencies}") 
            
    add_custom_target(tag
        COMMAND ${CMAKE_COMMAND}
            -DCOMMIT_COMMENT=${cc}
            -DRELEASE_NOTE_OVERVIEW=${releaseNoteOverview}
            -DTAG_ENDING=${ending}
            -DFORCE=${force}
            -DSKIP_DEPENDENCIES=${sd}
            -DSWITCH_TO_NEW_TAG=${st}
            -DOverallDependencies=${OverallDependenciesAsArgument}
            -DContextFile=${ContextFile}
            -DPackageRootDirectory=${PROJECT_SOURCE_DIR}
            -DJiraUrl=${tag_JiraUrl}
            -DJiraProjectKeys=${tag_JiraProjectKeys}
            -DCMAKE_HOST_SYSTEM_NAME=${CMAKE_HOST_SYSTEM_NAME}
            -P ${CMAKE_ROOT}/Modules/SBE/helpers/TagSources.cmake
            )
            
    add_custom_target(snapshot
        COMMAND ${CMAKE_COMMAND}
            -DPackageRootDirectory=${PROJECT_SOURCE_DIR}
            -P ${CMAKE_ROOT}/Modules/SBE/helpers/SnapshotSources.cmake
            )            
endfunction()            
