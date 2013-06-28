if(NOT DEFINED DEP_INFO_FILE)
    message(FATAL_ERROR "DEP_INFO_FILE has to be defined")
endif()

if(NOT DEFINED DEP_INSTALL_PATH)
    message(FATAL_ERROR "DEP_INSTALL_PATH has to be defined")
endif()

include(SBE/helpers/DependenciesParser)

function(addDependencies)
    CMAKE_PARSE_ARGUMENTS(dep "" "TARGET;CONTAIN_DECLSPEC_FLAG" "DEPENDENCY_TYPES" ${ARGN})
    
    if(NOT DEFINED dep_TARGET)
        return()
    endif()
    
    if(NOT DEFINED dep_DEPENDENCY_TYPES)
        set(dep_DEPENDENCY_TYPES "Library" "Project")
    endif()  
    
    ParseDependencies("${DEPENDENCIES}" ownDependenciesIds)
    
    set(depContains "no")
    
    # link all dependend libraries
    if(NOT "${ownDependenciesIds}" STREQUAL "")
        include(${DEP_INFO_FILE})
    
        include_directories(${DEP_INSTALL_PATH}/include)
        link_directories(${DEP_INSTALL_PATH}/lib) 
    
        foreach(dep ${ownDependenciesIds})
            set(depName ${${dep}_Name})
            
            list(FIND dep_DEPENDENCY_TYPES "${${dep}_Type}" typeToAdd)
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
                
                if(${depName}_CONTAINS_DECLSPEC)
                    set(depContains "yes")
                endif()
                
                if(DEFINED ${dep}_LibrariesToLink)
                    # link only requested
                    target_link_libraries(${dep_TARGET} ${${dep}_LibrariesToLink})
                elseif(DEFINED ${depName}_LIBRARIES)
                    # link all exported
                    target_link_libraries(${dep_TARGET} ${${depName}_LIBRARIES})
                endif()                
            endif()
        endforeach()
        
        unset(OverallFoundPackages CACHE)
    endif()
    
    if(DEFINED dep_CONTAIN_DECLSPEC_FLAG)
        set(${dep_CONTAIN_DECLSPEC_FLAG} ${depContains} PARENT_SCOPE)
    endif()
endfunction()        

function(doesDependenciesContainsDeclSpecs containsDeclspecs)
    ParseDependencies("${DEPENDENCIES}" ownDependenciesIds)
    
    set(depContains "no")
    
    # link all dependend libraries
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


