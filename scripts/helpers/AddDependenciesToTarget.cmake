if(NOT DEFINED DEP_INFO_FILE)
    message(FATAL_ERROR "DEP_INFO_FILE has to be defined")
endif()

if(NOT DEFINED DEP_INSTALL_PATH)
    message(FATAL_ERROR "DEP_INSTALL_PATH has to be defined")
endif()

include(SBE/helpers/ArgumentParser)

function(sbeAddDependencies)
    sbeParseArguments(dep "" "Target" "DependencyTypesToAdd" "FromDependency" "${ARGN}")
    
    if(NOT DEFINED dep_Target)
        return()
    endif()

    foreach(fd ${dep_FromDependency})
        string(REPLACE "," ";" fd "${fd}")
        CMAKE_PARSE_ARGUMENTS(d "" "FromDependency" "LinkOnly" "${fd}")
        
        if(DEFINED d_FromDependency)
            if(DEFINED ${d_FromDependency}_LibrariesToLink)
                list(APPEND ${d_FromDependency}_LibrariesToLink ${d_LinkOnly})
            else()
                set(${d_FromDependency}_LibrariesToLink ${d_LinkOnly})
            endif()
        endif()        
    endforeach()
    
    # link all dependend libraries
    if(NOT "${OwnDependenciesIds}" STREQUAL "")
        include(${DEP_INFO_FILE})
    
        include_directories(${DEP_INSTALL_PATH}/include)
        link_directories(${DEP_INSTALL_PATH}/lib) 
    
        foreach(dep ${ownDependenciesIds})
            set(depName ${${dep}_Name})
            
            list(FIND dep_DependencyTypesToAdd "${${dep}_Type}" typeToAdd)
            if(${typeToAdd} GREATER -1)
                
                if(NOT DEFINED ${depName}_FOUND)
                    find_package(${depName} REQUIRED CONFIG PATHS ${DEP_INSTALL_PATH}/config NO_DEFAULT_PATH)
                    set(tmp ${OverallFoundPackages})
                    list(APPEND tmp ${depName})
                    set(OverallFoundPackages ${tmp} CACHE INTERNAL "" FORCE)
                endif()
                
                if(DEFINED ${depName}_INCLUDE_DIRS)
                    include_directories(${${depName}_INCLUDE_DIRS})
                endif()             
                
                if(DEFINED ${dep}_LibrariesToLink)
                    # link only requested
                    target_link_libraries(${dep_Target} ${${dep}_LibrariesToLink})
                elseif(DEFINED ${depName}_LIBRARIES)
                    # link all exported
                    target_link_libraries(${dep_Target} ${${depName}_LIBRARIES})
                endif()                
            endif()
        endforeach()
        
        unset(OverallFoundPackages CACHE)
    endif()
endfunction()        

function(sbeDoesDependenciesContainsDeclSpecs containsDeclspecs)
    set(depContains "no")
    
    # check dependend packages
    if(NOT "${OwnDependenciesIds}" STREQUAL "")
        include(${DEP_INFO_FILE})
    
        foreach(dep ${ownDependenciesIds})
            if(NOT depContains)
                set(depName ${${dep}_Name})
                
                if(NOT DEFINED ${depName}_FOUND)
                    find_package(${depName} REQUIRED CONFIG PATHS ${DEP_INSTALL_PATH}/config NO_DEFAULT_PATH)
                    set(tmp ${OverallFoundPackages})
                    list(APPEND tmp ${depName})
                    set(OverallFoundPackages ${tmp} CACHE INTERNAL "" FORCE)
                endif()
                
                if(${depName}_CONTAINS_DECLSPEC)
                    set(depContains "yes")
                endif()
            endif()
        endforeach()
        
        unset(OverallFoundPackages CACHE)
    endif()
    
    set(${containsDeclspecs} ${depContains} PARENT_SCOPE)
endfunction()


