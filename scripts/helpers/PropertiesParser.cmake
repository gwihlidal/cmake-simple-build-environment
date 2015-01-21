if(DEFINED PropertyParserGuard)
    return()
endif()

set(PropertyParserGuard yes)

include(SBE/helpers/ArgumentParser)

 
function(sbeUpdateDateVersion version propertytFile)
    file(READ ${propertytFile} context)
    string(REGEX REPLACE "([ \t]*[sS][eE][tT][ \t]*\\([ \t]*DateVersion[ \t]+)[0-9]+([ \t]*\\))" "\\1${version}\\2" context "${context}")
    file(WRITE ${propertytFile} ${context})
endfunction()
