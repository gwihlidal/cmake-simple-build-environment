cmake_minimum_required(VERSION 2.8)

if (DEFINED TargetImportedGuard)
    return()
endif()

set(TargetImportedGuard yes)

function(sbeImportsFrequentisVBT)
    # arguments
    # Dir - path where VBT is unpack
    # ImportedTargets - variable name with names of all imported targets
    # ExcludeLibraries - libraries that have to be excluded from import
    #
    # Only one of Url of File has to be specified.
    #
    # Function checks given file for libraries and imports them. It prefers shared over static when
    # target platform supports shared libraries. For shared libaries it tries to figure out SO name
    # and implementation files. 
    CMAKE_PARSE_ARGUMENTS(imp "" "Dir;ImportedTargets" "ExcludeLibraries" ${ARGN})

    if(NOT DEFINED imp_Dir)
        message(FATAL_ERROR "In command sbeImportsFrequentisVBT Dir has to be speciefied.")
    endif()

    get_property(areSharedLibrariesSupported GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
        
    # get list of libs
    file(GLOB_RECURSE libFiles ${imp_Dir}/lib/*)
    list(SORT libFiles)
    # get list of libraries and theirs files
    set(libs "")
    foreach(libFile ${libFiles})
        get_filename_component(libFileName "${libFile}" NAME)
        
        if ("${libFileName}" MATCHES "lib.*")
            string(REGEX REPLACE "lib([a-zA-Z0-9_+]+).*" "\\1" libName "${libFileName}")
        else()
            string(REGEX REPLACE "([a-zA-Z0-9_+]+).*" "\\1" libName "${libFileName}")
        endif()
        
        list(APPEND libs ${libName})
        list(APPEND ${libName}_FILES ${libFile})
    endforeach()  
    list(REMOVE_DUPLICATES libs)
    
    # exclude requested libraries
    if(NOT "" STREQUAL "${imp_ExcludeLibraries}")
        list(REMOVE_ITEM libs ${imp_ExcludeLibraries})
    endif()        
        
    # get types of libraries Shared/Static
    foreach(lib ${libs})
        foreach(libFile ${${lib}_FILES})
            get_filename_component(libFileName "${libFile}" NAME)

            if("${libFileName}" MATCHES ".so")
                # prefer frequentis style                
                if("${libFileName}" MATCHES ".*-([0-9.]+).so")
                    if(NOT IS_SYMLINK ${libFile})
                        set(${lib}_LIB_FILE ${libFile})
                    endif()
                endif()
                # get world style only if lib file is not frequentis style               
                if("${libFileName}" MATCHES ".*.so.([0-9.]+)" AND "" STREQUAL "${${lib}_LIB_FILE}")
                    if(NOT IS_SYMLINK ${libFile})
                        set(${lib}_LIB_FILE ${libFile})
                    endif()
                endif()
                # get without version               
                if("${libFileName}" MATCHES ".so$" AND "" STREQUAL "${${lib}_LIB_FILE}")
                    if(NOT IS_SYMLINK ${libFile})
                        set(${lib}_LIB_FILE ${libFile})
                    endif()
                endif()
            endif()
            
            if("${libFileName}" MATCHES ".a$")
                set(${lib}_STATIC_LIB_FILE ${libFile})
            endif()
        endforeach()
    endforeach()
        
    # when target supports shared library prefer shared
    foreach(lib ${libs})
        if(areSharedLibrariesSupported)
            if(NOT "" STREQUAL "${${lib}_LIB_FILE}")
                set(${lib}_TYPE "Shared")
            elseif(NOT "" STREQUAL "${${lib}_STATIC_LIB_FILE}")
                set(${lib}_TYPE "Static")
            endif()
        else()
            if(NOT "" STREQUAL "${${lib}_STATIC_LIB_FILE}")
                set(${lib}_TYPE "Static")
            else()
                message(STATUS "Removing library ${lib} because target has no shared libraries")
                list(REMOVE_ITEM libs ${lib})
            endif()
        endif()
    endforeach()
        
    # get so names for shared libraries
    find_program(OBJDUMP objdump)
    
    if(NOT DEFINED OBJDUMP-NOTFOUND)
        # when objdump is found, get soname from library
        foreach(lib ${libs})
            if("Shared" STREQUAL "${${lib}_TYPE}" )
                execute_process(COMMAND ${OBJDUMP} -p "${${lib}_LIB_FILE}" RESULT_VARIABLE result OUTPUT_VARIABLE out)
                if("${out}" MATCHES ".*SONAME[ \t]+([^\n]+)\n.*")
                    string(REGEX REPLACE ".*SONAME[ \t]+([^\n]+)\n.*" "\\1" soName "${out}")
                    set(${lib}_LIB_SO_FILE ${soName})
                else()
                    set(${lib}_LIB_SO_FILE ${${lib}_LIB_FILE})
                endif()
            endif()
        endforeach()        
    else()
        # when objdump is not found, get soname from versions
        foreach(lib ${libs})
            foreach(libFile ${${lib}_FILES})
                get_filename_component(libFileName "${libFile}" NAME)
                
                if("${libFileName}" MATCHES ".so")
                    # get frequentis style so versions                
                    if("${libFileName}" MATCHES ".*-([0-9.]+).so")
                        string(REGEX REPLACE ".*-([0-9.]+).so" "\\1" soVersion "${libFileName}")
                        set(${lib}_FRQ_${soVersion}_FILE "${libFileName}")
                        list(APPEND ${lib}_FRQ_SOVERSIONS ${soVersion})
                        list(SORT ${lib}_FRQ_SOVERSIONS)
                    endif()
                    # get world style so versions               
                    if("${libFileName}" MATCHES ".*.so.([0-9.]+)")
                        string(REGEX REPLACE ".*.so.([0-9.]+)" "\\1" soVersion "${libFileName}")
                        set(${lib}_WORLD_${soVersion}_FILE "${libFileName}")
                        list(APPEND ${lib}_WORLD_SOVERSIONS ${soVersion})
                        list(SORT ${lib}_WORLD_SOVERSIONS)
                    endif()
                endif()
                
                # get library file and so file, prefere frequentis
                set(soVersionType "")
                if(NOT "" STREQUAL "${${lib}_FRQ_SOVERSIONS}")
                    set(soVersionType "FRQ")
                elseif(NOT "" STREQUAL "${${lib}_WORLD_SOVERSIONS}")
                    set(soVersionType "WORLD")
                endif()
            
                if(NOT "" STREQUAL "${soVersionType}")
                    set(soVersions ${${lib}_${soVersionType}_SOVERSIONS})
                    list(REVERSE soVersions)
                    list(LENGTH soVersions count)
                    if(${count} GREATER 1)
                        list(GET soVersions 1 libSoVersion)
                        set(${lib}_LIB_SO_FILE ${${lib}_${soVersionType}_${libSoVersion}_FILE})
                    else()
                        set(${lib}_LIB_SO_FILE ${lib}_LIB_FILE)
                    endif()
                endif()
            endforeach()
        endforeach()        
    endif()
    
    # add imported targets and its properties
    foreach(lib ${libs})
        if("Shared" STREQUAL "${${lib}_TYPE}")
            ADD_LIBRARY(${lib} SHARED IMPORTED)
            SET_TARGET_PROPERTIES(${lib} PROPERTIES
                IMPORTED_LOCATION "${${lib}_LIB_FILE}"
                IMPORTED_SONAME "${${lib}_LIB_SO_FILE}"
                SBE_ALL_LIBRARY_FILES "${${lib}_FILES}")
        endif()
        if("Static" STREQUAL "${${lib}_TYPE}")
            ADD_LIBRARY(${lib} STATIC IMPORTED)
            SET_TARGET_PROPERTIES(${lib} PROPERTIES
                IMPORTED_LOCATION "${${lib}_STATIC_LIB_FILE}"
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX;C"
                SBE_ALL_LIBRARY_FILES "${${lib}_STATIC_LIB_FILE}")
        endif()
    endforeach()
    
    # return list of imported targets
    if(DEFINED imp_ImportedTargets)
        set(${imp_ImportedTargets} ${libs} PARENT_SCOPE)
    endif()
endfunction()


function(sbeImportsLibrary)
    message(FATAL_ERROR "sbeImportsLibrary not implemented")
endfunction()



