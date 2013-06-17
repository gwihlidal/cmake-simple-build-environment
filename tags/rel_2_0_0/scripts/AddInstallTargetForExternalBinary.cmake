cmake_minimum_required(VERSION 2.8)

# only to suppress waring "Not used CMAKE_TOOLCHAIN_FILE"
if(CMAKE_TOOLCHAIN_FILE)
endif()

# only to suppress waring "Not used DEP_DEPLOYMENT_PATH"
if(DEP_DEPLOYMENT_PATH)
endif()

if(NOT DEFINED TARGET_SUPPORTS_SHARED_LIBS)
    set(TARGET_SUPPORTS_SHARED_LIBS "yes")
endif()

# find all necessary tools
find_package(Subversion)
if(NOT Subversion_SVN_EXECUTABLE)
    message(FATAL_ERROR "error: could not find svn.")
endif()

get_filename_component(tarFileName "${${CMAKE_SYSTEM_NAME}_${CMAKE_SYSTEM_PROCESSOR}_${CMAKE_BUILD_TYPE}_SDK_TARGZ}" NAME)

if(NOT EXISTS ${PROJECT_SOURCE_DIR}/${tarFileName})
    message(STATUS "Exporting ${tarFileName}...")
    execute_process(COMMAND svn export ${${CMAKE_SYSTEM_NAME}_${CMAKE_SYSTEM_PROCESSOR}_${CMAKE_BUILD_TYPE}_SDK_TARGZ} ${PROJECT_SOURCE_DIR}/${tarFileName}
        RESULT_VARIABLE svnResult
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(${svnResult} GREATER 0)
        message(FATAL_ERROR "SVN Export Fails:\n${out}")
    endif()
    
    if(EXISTS ${PROJECT_BINARY_DIR}/preinstallation)    
        file(REMOVE_RECURSE ${PROJECT_BINARY_DIR}/preinstallation)
    endif()
endif()

if(NOT EXISTS ${PROJECT_BINARY_DIR}/preinstallation)
    message(STATUS "Preinstalling ${tarFileName}...")
    file(MAKE_DIRECTORY  ${PROJECT_BINARY_DIR}/preinstallation)
    execute_process(COMMAND tar -xzf ${PROJECT_SOURCE_DIR}/${tarFileName} -C ${PROJECT_BINARY_DIR}/preinstallation
        RESULT_VARIABLE result
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(${result} GREATER 0)
        message(FATAL_ERROR "Untar Fails:\n${out}")
    endif()


    message(STATUS "Generating config and import files...")    
    # get list of libs
    file(GLOB_RECURSE libFiles ${PROJECT_BINARY_DIR}/preinstallation/lib/*)
    # get list of libraries and theirs files
    set(libs "")
    foreach(libFile ${libFiles})
        get_filename_component(libFileName "${libFile}" NAME)
        
        string(REGEX REPLACE "lib([a-zA-Z0-9_]+).*" "\\1" libName "${libFileName}")
        list(APPEND libs ${libName})
        list(APPEND ${libName}_FILES ${libFile})
    endforeach()  
    list(REMOVE_DUPLICATES libs)
    
    # get types of libraries Shared/Static
    foreach(lib ${libs})
        foreach(libFile ${${lib}_FILES})
            get_filename_component(libFileName "${libFile}" NAME)

            if("${libFileName}" MATCHES ".so")
                # prefer frequentis style                
                if("${libFileName}" MATCHES ".*-([0-9.]+).so")
                    if(NOT IS_SYMLINK ${libFile})
                        set(${lib}_LIB_FILE ${libFileName})
                    endif()
                endif()
                # get world style only if lib file is not frequentis style               
                if("${libFileName}" MATCHES ".*.so.([0-9.]+)" AND "" STREQUAL "${${lib}_LIB_FILE}")
                    if(NOT IS_SYMLINK ${libFile})
                        set(${lib}_LIB_FILE ${libFileName})
                    endif()
                endif()
            endif()
            
            if("${libFileName}" MATCHES ".a$")
                set(${lib}_STATIC_LIB_FILE ${libFileName})
            endif()
        endforeach()
    endforeach()
    
    # when target supports shared library prefer shared
    foreach(lib ${libs})
        if(NOT ${TARGET_SUPPORTS_SHARED_LIBS} AND NOT "" STREQUAL "${${lib}_STATIC_LIB_FILE}" )
            set(${lib}_LIB_FILE ${${lib}_STATIC_LIB_FILE})
            set(${lib}_TYPE "Static")
        endif()
        if(${TARGET_SUPPORTS_SHARED_LIBS} AND NOT "" STREQUAL "${${lib}_LIB_FILE}" )
            set(${lib}_TYPE "Shared")
        endif()
        
        # if target doesn't support shared libraries remove shared library
        if(NOT ${TARGET_SUPPORTS_SHARED_LIBS} AND "" STREQUAL "${${lib}_STATIC_LIB_FILE}")
            message(STATUS "Removing library ${lib} because target has no shared libraries")
            list(REMOVE_ITEM ${lib})
        endif()        
    endforeach()
    
    # get so names for shared libraries
    find_program(OBJDUMP objdump)
    
    if(NOT DEFINED OBJDUMP-NOTFOUND)
        # when objdump is found, get soname from library
        foreach(lib ${libs})
            if("Shared" STREQUAL "${${lib}_TYPE}" )
                execute_process(COMMAND ${OBJDUMP} -p "${PROJECT_BINARY_DIR}/preinstallation/lib/${${lib}_LIB_FILE}" RESULT_VARIABLE result OUTPUT_VARIABLE out)
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
                    
   
    # create Targets.cmake
    set(ADD_ALL_LIBRARIES "")       
    foreach(lib ${libs})
        if("Shared" STREQUAL "${${lib}_TYPE}")
            list(APPEND ADD_ALL_LIBRARIES "# Create imported target ${lib}\n")
            list(APPEND ADD_ALL_LIBRARIES "ADD_LIBRARY(${lib} SHARED IMPORTED)\n")
        endif()
        if("Static" STREQUAL "${${lib}_TYPE}")
            list(APPEND ADD_ALL_LIBRARIES "# Create imported target ${lib}\n")
            list(APPEND ADD_ALL_LIBRARIES "ADD_LIBRARY(${lib} STATIC IMPORTED)\n")
        endif()
    endforeach()         

    string(REPLACE ";" "" ADD_ALL_LIBRARIES "${ADD_ALL_LIBRARIES}")
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ExternalTargets.cmake.in "${PROJECT_BINARY_DIR}/preinstallation/Configs/${PROJECT_NAME}Targets.cmake" @ONLY)

    # create imported Targets.cmake
    set(IMPORT_ALL_LIBRARIES "")       
    foreach(lib ${libs})
        string(TOUPPER "${CMAKE_BUILD_TYPE}" buildType)
        
        list(APPEND IMPORT_ALL_LIBRARIES "# Import target \"${lib}\" for configuration \"${CMAKE_BUILD_TYPE}\"\n")
        list(APPEND IMPORT_ALL_LIBRARIES "SET_PROPERTY(TARGET ${lib} APPEND PROPERTY IMPORTED_CONFIGURATIONS ${buildType})\n")
        
        if("Shared" STREQUAL "${${lib}_TYPE}")
            list(APPEND IMPORT_ALL_LIBRARIES "SET_TARGET_PROPERTIES(${lib} PROPERTIES\n")
            list(APPEND IMPORT_ALL_LIBRARIES "  IMPORTED_LOCATION_${buildType} \"\${_IMPORT_PREFIX}/lib/${${lib}_LIB_FILE}\"\n")
            list(APPEND IMPORT_ALL_LIBRARIES "  IMPORTED_SONAME_${buildType} \"${${lib}_LIB_SO_FILE}\"\n")
            list(APPEND IMPORT_ALL_LIBRARIES "  )\n")
        endif()
        
        if("Static" STREQUAL "${${lib}_TYPE}")
            list(APPEND IMPORT_ALL_LIBRARIES "SET_TARGET_PROPERTIES(${lib} PROPERTIES\n")
            list(APPEND IMPORT_ALL_LIBRARIES "   IMPORTED_LINK_INTERFACE_LANGUAGES_${buildType} \"CXX\"\n")
            list(APPEND IMPORT_ALL_LIBRARIES "   IMPORTED_LOCATION_${buildType} "\${_IMPORT_PREFIX}/lib/${${lib}_LIB_FILE}"\n")
        endif()
        
        list(APPEND IMPORT_ALL_LIBRARIES "LIST(APPEND _IMPORT_CHECK_TARGETS ${lib} )\n")
        list(APPEND IMPORT_ALL_LIBRARIES "LIST(APPEND _IMPORT_CHECK_FILES_FOR_${lib} \"\${_IMPORT_PREFIX}/lib/${${lib}_LIB_FILE}\")\n")
    endforeach() 
    
    string(REPLACE ";" "" IMPORT_ALL_LIBRARIES "${IMPORT_ALL_LIBRARIES}")
    string(TOLOWER "${CMAKE_BUILD_TYPE}" buildType)
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ExternalTargetImportFile.cmake.in "${PROJECT_BINARY_DIR}/preinstallation/Configs/${PROJECT_NAME}Targets-${buildType}.cmake" @ONLY)
    
    set(INSTALL_LIBRARIES "")
    foreach(lib ${libs})
        list(APPEND INSTALL_LIBRARIES ${lib})
    endforeach()      

    # Create the Config.cmake and ConfigVersion files
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ExternalBinaryPackageConfig.cmake.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake" @ONLY)
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)
 
    # Install the Config.cmake and ConfigVersion.cmake
    install(FILES
      "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
      "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
      DESTINATION config COMPONENT Configs) 

    # Install the Targets.cmake
    install(FILES
      "${PROJECT_BINARY_DIR}/preinstallation/Configs/${PROJECT_NAME}Targets.cmake"
      "${PROJECT_BINARY_DIR}/preinstallation/Configs/${PROJECT_NAME}Targets-${buildType}.cmake"
      DESTINATION config COMPONENT Configs)
      
    # Install the Headers
    install(DIRECTORY ${PROJECT_BINARY_DIR}/preinstallation/include/ DESTINATION include COMPONENT Headers)        
              
    # Install the Libs
    install(DIRECTORY ${PROJECT_BINARY_DIR}/preinstallation/lib/ DESTINATION lib COMPONENT Binaries)
endif()    


