cmake_minimum_required(VERSION 2.8)

include(SBE/helpers/SvnHelpers)

function(AddReferencedIssuesSection file content modifiedContent)
    
    string(REGEX MATCHALL "@defgroup[ \t]+[^ \t]+" groups "${content}")

    if(NOT "${groups}" STREQUAL "")
        string(REGEX REPLACE "@defgroup[ \t]+" "" groups "${groups}")
        
        get_filename_component(fileDir "${file}" PATH)
        svnGetProperty("${fileDir}" "bugtraq:logregex" logregex)

        if(DEFINED logregex)
            svnGetLog(${fileDir} svnlog)

            string(REGEX MATCHALL "${logregex}" issues "${svnlog}")
           
            if(DEFINED issues)
                list(REMOVE_DUPLICATES issues)
                
                string(REGEX MATCHALL "[Rr]emoved?[ \t]+${logregex}" issuesToRemove "${svnlog}")
                string(REGEX MATCHALL "${logregex}" issuesToRemove "${issuesToRemove}")
                if(NOT "" STREQUAL "${issuesToRemove}")
                    list(REMOVE_ITEM issues ${issuesToRemove})
                endif()
                
                string(REPLACE ";" ", " issues "${issues}")
                
                set(mc "${content}")
                foreach(group ${groups})
                    list(APPEND mc "/**")
                    list(APPEND mc " * @addtogroup ${group}")
                    list(APPEND mc " * @section ReferencedIssues_${group} Referenced Issues")
                    list(APPEND mc " * ")
                    list(APPEND mc " * ${issues}")
                    list(APPEND mc " */")
                endforeach()
                
                set(${modifiedContent} "${mc}" PARENT_SCOPE)
                return()                    
            endif()    
        endif()
    endif()
    
    set(${modifiedContent} "${content}" PARENT_SCOPE)    
endfunction()
