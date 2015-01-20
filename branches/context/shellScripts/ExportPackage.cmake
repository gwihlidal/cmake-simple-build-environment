cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED ContextFile)
    message(FATAL_ERROR "Context file has to be set")
endif()

if(NOT DEFINED Name)
    message(FATAL_ERROR "Package name has to be set")
endif()

include(SBE/PackageExporter)

sbeLoadContextFile(${ContextFile}) 
sbeExportPackage(${Name})
