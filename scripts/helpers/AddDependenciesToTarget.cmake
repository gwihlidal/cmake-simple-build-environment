if(NOT DEFINED DEP_TARGET)
    message(FATAL_ERROR "DEP_TARGET has to be defined")
endif()

if(NOT DEFINED DEP_TYPES_TO_ADD)
    message(FATAL_ERROR "DEP_TYPES_TO_ADD has to be defined")
endif()

if(NOT DEFINED DEP_INFO_FILE)
    message(FATAL_ERROR "DEP_INFO_FILE has to be defined")
endif()

if(NOT DEFINED DEP_INSTALL_PATH)
    message(FATAL_ERROR "DEP_INSTALL_PATH has to be defined")
endif()

# link all dependend libraries
if(NOT "${DEPENDENCIES}" STREQUAL "")
    include(${DEP_INFO_FILE})

    include_directories(${DEP_INSTALL_PATH}/include)
    link_directories(${DEP_INSTALL_PATH}/lib) 

    foreach(dep ${DEPENDENCIES})
        set(depName ${${dep}_Name})
        
        list(FIND DEP_TYPES_TO_ADD "${${dep}_Type}" typeToAdd)
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
            
            if(DEFINED ${depName}_LIBRARIES)
                target_link_libraries(${DEP_TARGET} ${${depName}_LIBRARIES})
            endif()                
        endif()
    endforeach()
    
    unset(OverallFoundPackages CACHE)
endif()    




