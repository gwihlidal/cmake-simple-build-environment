cmake_minimum_required(VERSION 2.8)

include(SBE/helpers/SvnHelpers)

function(ConvertIssuesToLinksForDoxygen file content modifiedContent)

    set(mc "${content}")
    
    get_filename_component(fileDir "${file}" PATH)
    svnGetProperty("${fileDir}" "bugtraq:url" url)

    if(DEFINED url)
        svnGetProperty("${fileDir}" "bugtraq:logregex" logregex)
        
        if(DEFINED logregex)
            string(REPLACE "%BUGID%" "" url "${url}")
            
            string(REGEX REPLACE "${logregex}" "[\\1](${url}\\1)" mc "${mc}")
        endif()

    endif()
    
    set(${modifiedContent} "${mc}" PARENT_SCOPE)    
endfunction()
