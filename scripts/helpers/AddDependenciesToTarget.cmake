
include(SBE/helpers/ArgumentParser)

function(sbeAddDependencies)
    sbeParseArguments(dep "" "Target" "ExcludeDependencies" "FromDependency" "${ARGN}")
    
    if(NOT DEFINED dep_Target)
        return()
    endif()

    # check if mock libraries has to be used
    get_property(isTestTarget TARGET ${dep_Target} PROPERTY SBE_TEST)
    get_property(isMockTarget TARGET ${dep_Target} PROPERTY SBE_MOCK)
    set(useMock no)
    if(isTestTarget OR isMockTarget)
        set(useMock yes)
    endif()
    
    foreach(fd ${dep_FromDependency})
        string(REPLACE "," ";" fd "${fd}")
        CMAKE_PARSE_ARGUMENTS(d "" "FromDependency" "LinkOnly" ${fd})

        if(DEFINED d_FromDependency)
            set(${d_FromDependency}_LibrariesToLink ${d_LinkOnly})
        endif()        
    endforeach()

    # link all dependend libraries
    # loop through over all dependencies due to include paths, but link only direct dependencies
    sbeAddDependenciesIncludes(Target ${dep_Target})
    
    foreach(dep ${DirectDependencies})
        set(hasToBeAdded yes)
        
        if(DEFINED dep_ExcludeDependencies)
            list(FIND dep_ExcludeDependencies "${dep}" index)
            if (${index} EQUAL -1)
                set(hasToBeAdded yes)
            else()
                set(hasToBeAdded no)
            endif()
        endif()

        # add dependency            
        if(hasToBeAdded)
            if(DEFINED ${dep}_LibrariesToLink)
                set(tmpList ${${dep}_LibrariesToLink})
                if(useMock)
                    set(libType "MOCK_LIBRARIES")
                else()
                    set(libType "LIBRARIES")
                endif()
                list(REMOVE_ITEM tmpList ${${dep}_${libType}})
                if(NOT "" STREQUAL "${tmpList}")
                    message(FATAL_ERROR "Libraries ${tmpList} are not provided by ${dep} but requested in target ${dep_Target}.")
                endif()
                # link only requested
                _AddLibraries(${dep_Target} "${${dep}_LibrariesToLink}")                    
            else()
                if(useMock)
                    set(libType "MOCK_LIBRARIES")
                else()
                    set(libType "LIBRARIES")
                endif()
                if(DEFINED ${dep}_${libType})
                    # link all exported
                    _AddLibraries(${dep_Target} "${${dep}_${libType}}")
                endif()
            endif()                
        endif()
    endforeach()
endfunction()        

function(sbeAddDependenciesIncludes)
    sbeParseArguments(dep "" "Target" "" "" "${ARGN}")
    
    if(NOT DEFINED dep_Target)
        return()
    endif()

    # check if mock libraries has to be used
    get_property(isTestTarget TARGET ${dep_Target} PROPERTY SBE_TEST)
    get_property(isMockTarget TARGET ${dep_Target} PROPERTY SBE_MOCK)
    set(useMock no)
    if(isTestTarget OR isMockTarget)
        set(useMock yes)
    endif()
            
    foreach(dep ${OverallDependencies})
        # add dependency includes            
        if(useMock)
            if(DEFINED ${dep}_INCLUDE_DIRS OR DEFINED ${dep}_MOCK_INCLUDE_DIRS)
                set(includes  ${${dep}_MOCK_INCLUDE_DIRS} ${${dep}_INCLUDE_DIRS})
                
                foreach(include ${includes})
                    target_include_directories(${dep_Target} PRIVATE ${include})
                endforeach()
            endif()
        elseif(DEFINED ${dep}_INCLUDE_DIRS)
            foreach(include ${${dep}_INCLUDE_DIRS})
                target_include_directories(${dep_Target} PRIVATE ${include})
            endforeach()
        endif()
    endforeach()

endfunction()        

function(sbeDoesDependenciesContainsDeclSpecs containsDeclspecs)
    # check dependend packages
    foreach(dep ${DirectDependencies})
        if(${dep}_CONTAINS_DECLSPEC)
            set(depContains "yes")
            break()
        endif()
    endforeach()
   
    set(${containsDeclspecs} ${depContains} PARENT_SCOPE)
endfunction()
  
function(_AddLibraries targetName libraries)
    add_dependencies(${targetName} dependencies)

    foreach(lib ${libraries})
        get_target_property(libType ${lib} TYPE)
        
        if("STATIC_LIBRARY" STREQUAL "${libType}")
            target_link_libraries(${targetName} ${lib})
        else()
            # use private to not add transitive dependencies to target when shared libraries are used 
            target_link_libraries(${targetName} LINK_PRIVATE ${lib})
        endif()
    endforeach()    
endfunction()
