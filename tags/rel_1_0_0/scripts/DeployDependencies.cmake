cmake_minimum_required(VERSION 2.8)

if(NOT DEP_SRC_DEPLOYMENT_PATH)
    set(DEP_SOURCE_DIR ${PROJECT_SOURCE_DIR})
    
    include(SBE/ExportDependencies)
else()
    set(DEP_SOURCES_PATH "${DEP_SRC_DEPLOYMENT_PATH}/sources")
    set(DEP_INFO_FILE "${DEP_SRC_DEPLOYMENT_PATH}/info/info.cmake")    
endif()
    
include(SBE/InstallDependencies)
    
include(${DEP_INFO_FILE} OPTIONAL)
include(${DEP_INST_INFO_FILE} OPTIONAL)












