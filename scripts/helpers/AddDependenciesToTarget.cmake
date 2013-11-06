
include(SBE/helpers/ArgumentParser)
include(SBE/helpers/DependenciesParser)

function(sbeAddDependencies)
    if(NOT DEFINED DEP_INFO_FILE)
        message(FATAL_ERROR "DEP_INFO_FILE has to be defined")
    endif()

    sbeParseArguments(dep "" "Target" "DependencyTypesToAdd;ExcludeDependencies" "FromDependency" "${ARGN}")
    
    if(NOT DEFINED dep_Target)
        return()
    endif()

    # check if mock libraries has to be used
    get_property(isTestTarget TARGET ${dep_Target} PROPERTY TEST)
    get_property(isMockTarget TARGET ${dep_Target} PROPERTY IsMock)
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
    
    ParseDependencies("${DEPENDENCIES}" ownDependenciesIds)
    
    # link all dependend libraries
    if(NOT "${ownDependenciesIds}" STREQUAL "")
        include(${DEP_INFO_FILE})
    
        include_directories(${DEP_INSTALL_PATH}/include)
    
        foreach(dep ${ownDependenciesIds})
            set(depName ${${dep}_Name})
            
            # check if dependency has to be added
            if("" STREQUAL "${${dep}_Type}")
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
                list(FIND dep_ExcludeDependencies "${depName}" index)
                if (${index} EQUAL -1)
                    set(hasToBeAdded yes)
                else()
                    set(hasToBeAdded no)
                endif()
            endif()

            # add dependency            
            if(hasToBeAdded)
                if(NOT DEFINED ${depName}_FOUND)
                    find_package(${depName} REQUIRED CONFIG PATHS ${DEP_INSTALL_PATH}/config NO_DEFAULT_PATH)
                    set(tmp ${OverallFoundPackages})
                    list(APPEND tmp ${depName})
                    set(OverallFoundPackages ${tmp} CACHE INTERNAL "" FORCE)
                endif()
                
                if(useMock)
                    if(DEFINED ${depName}_INCLUDE_DIRS OR DEFINED ${depName}_MOCK_INCLUDE_DIRS)
                        set(includes  ${${depName}_MOCK_INCLUDE_DIRS} ${${depName}_INCLUDE_DIRS})
                        
                        foreach(include ${includes})
                            target_include_directories(${dep_Target} PRIVATE ${include})
                        endforeach()
                    endif()
                elseif(DEFINED ${depName}_INCLUDE_DIRS)
                    foreach(include ${${depName}_INCLUDE_DIRS})
                        target_include_directories(${dep_Target} PRIVATE ${include})
                    endforeach()
                endif()
                
                if(DEFINED ${depName}_LibrariesToLink)
                    # link only requested
                    target_link_libraries(${dep_Target} ${${depName}_LibrariesToLink})
                else()
                    if(useMock)
                        set(libType "MOCK_LIBRARIES")
                    else()
                        set(libType "LIBRARIES")
                    endif()
                    if(DEFINED ${depName}_${libType})
                        # link all exported
                        target_link_libraries(${dep_Target} ${${depName}_${libType}})
                    endif()
                endif()                
            endif()
        endforeach()
        
        unset(OverallFoundPackages CACHE)
    endif()
endfunction()        

function(sbeAddDependenciesIncludes)
    if(NOT DEFINED DEP_INFO_FILE)
        message(FATAL_ERROR "DEP_INFO_FILE has to be defined")
    endif()

    sbeParseArguments(dep "" "Target" "" "" "${ARGN}")
    
    if(NOT DEFINED dep_Target)
        return()
    endif()

    # check if mock libraries has to be used
    get_property(isTestTarget TARGET ${dep_Target} PROPERTY TEST)
    get_property(isMockTarget TARGET ${dep_Target} PROPERTY IsMock)
    set(useMock no)
    if(isTestTarget OR isMockTarget)
        set(useMock yes)
    endif()
    
    ParseDependencies("${DEPENDENCIES}" ownDependenciesIds)
    
    # link all dependend libraries
    if(NOT "${ownDependenciesIds}" STREQUAL "")
        include(${DEP_INFO_FILE})
    
        include_directories(${DEP_INSTALL_PATH}/include)
    
        foreach(dep ${ownDependenciesIds})
            set(depName ${${dep}_Name})
            
            # check if dependency has to be added
            if("" STREQUAL "${${dep}_Type}")
                set(hasToBeAdded yes)
            else()
                set(hasToBeAdded no)
            endif()
            
            # add dependency includes            
            if(hasToBeAdded)
                if(NOT DEFINED ${depName}_FOUND)
                    find_package(${depName} REQUIRED CONFIG PATHS ${DEP_INSTALL_PATH}/config NO_DEFAULT_PATH)
                    set(tmp ${OverallFoundPackages})
                    list(APPEND tmp ${depName})
                    set(OverallFoundPackages ${tmp} CACHE INTERNAL "" FORCE)
                endif()
                
                if(useMock)
                    if(DEFINED ${depName}_INCLUDE_DIRS OR DEFINED ${depName}_MOCK_INCLUDE_DIRS)
                        set(includes  ${${depName}_MOCK_INCLUDE_DIRS} ${${depName}_INCLUDE_DIRS})
                        
                        foreach(include ${includes})
                            target_include_directories(${dep_Target} PRIVATE ${include})
                        endforeach()
                    endif()
                elseif(DEFINED ${depName}_INCLUDE_DIRS)
                    foreach(include ${${depName}_INCLUDE_DIRS})
                        target_include_directories(${dep_Target} PRIVATE ${include})
                    endforeach()
                endif()
            endif()
        endforeach()
        
        unset(OverallFoundPackages CACHE)
    endif()
endfunction()        

function(sbeDoesDependenciesContainsDeclSpecs containsDeclspecs)
    set(depContains "no")
    
    ParseDependencies("${DEPENDENCIES}" ownDependenciesIds)
    
    # check dependend packages
    if(NOT "${ownDependenciesIds}" STREQUAL "")
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


