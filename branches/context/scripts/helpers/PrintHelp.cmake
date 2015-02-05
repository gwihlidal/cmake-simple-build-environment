if(NOT DEFINED File)
    return()
endif()

include(${File})

set(Others "")

foreach(group ${Groups})
    # add other on the end
    if("Other" STREQUAL "${group}")
        foreach(target ${Other_Targets})
            set(Others "${Others}${target} ... ${Other_${target}_Help}\n")
        endforeach()  
    else() 
        message("\n${group}")   
        foreach(target ${${group}_Targets})
            message("    ${target} ... ${${group}_${target}_Help}")
        endforeach()
    endif()
endforeach()

message("\n${Others}")