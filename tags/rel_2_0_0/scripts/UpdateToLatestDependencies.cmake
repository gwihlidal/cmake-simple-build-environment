cmake_minimum_required(VERSION 2.8)

if(NOT PROPERTIES_PATH)
    message(FATAL_ERROR "Path to Properties.txt has to be defined as PROPERTIES_PATH=path.")
endif()

message(STATUS "Fake update of ${PROPERTIES_PATH}/Properties.cmake")  
