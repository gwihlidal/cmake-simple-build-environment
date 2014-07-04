
include(SBE/helpers/ArgumentParser)
include(SBE/helpers/DependenciesParser)

include(${DEP_INFO_FILE})
    
function(sbeAddDependencies)
    if(NOT DEFINED DEP_INFO_FILE)
        message(FATAL_ERROR "DEP_INFO_FILE has to be defined")
    endif()

    sbeParseArguments(dep "" "Target" "DependencyTypesToAdd;ExcludeDependencies" "FromDependency" "${ARGN}")
    
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
    foreach(dep ${${NAME}_Dependencies})
        # check if dependency has to be added
        if("" STREQUAL "${${dep}_Type}" OR "Container" STREQUAL "${${dep}_Type}")
            set(hasToBeAdded yes)
        else()
            list(FIND dep_DependencyTypesToAdd "${${dep}_Type}" index)
            if(index EQUAL -1)
                set(hasToBeAdded no)
            else()
                set(hasToBeAdded yes)
            endif()
        endif()
        
        if(hasToBeAdded AND DEFINED dep_ExcludeDependencies)
            list(FIND dep_ExcludeDependencies "${dep}" index)
            if (${index} EQUAL -1)
                set(hasToBeAdded yes)
            else()
                set(hasToBeAdded no)
            endif()
        endif()

        # add dependency            
        if(hasToBeAdded)
            add_dependencies(${dep_Target} ${dep})
            
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
            
    foreach(dep ${${NAME}_Dependencies})
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
    foreach(dep ${${NAME}_Dependencies})
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
