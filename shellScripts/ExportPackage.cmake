cmake_minimum_required(VERSION 2.8)

if(NOT ContextFile AND NOT EXISTS Context.cmake)
    message(FATAL_ERROR "Context file has to be set")
endif()

if(NOT ContextFile)
    set(ContextFile Context.cmake)
endif()

include(SBE/PackageExporter)

sbeLoadContextFile(${ContextFile})

if(NOT Name)
    if(EXISTS Properties.cmake)
        include(Properties.cmake)
        sbeExportPackageDependencies(${Name} Properties.cmake)
    else()
        message(FATAL_ERROR "Name has to be set or Properties.cmake file has to exists")
    endif()
else()
    sbeExportPackage(${Name})
endif()
 

