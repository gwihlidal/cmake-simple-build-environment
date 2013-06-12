cmake_minimum_required(VERSION 2.8)

# check if this script is after AddBinaryTargets
if (NOT ${AddBinaryTargetsIncluded})
    message(FATAL_ERROR "AddTestTargets scripts has to be included after AddBinaryTargets.")
endif()

configure_file(${CMAKE_ROOT}/Modules/SBE/templates/CppUTestRunAllTests.cpp.in "RunAllTests.cpp" @ONLY)

add_executable(${PROJECT_NAME}Test ${PROJECT_BINARY_DIR}/RunAllTests.cpp ${TEST_FILES} $<TARGET_OBJECTS:${PROJECT_NAME}SourceObjects>)

if(${isSharedLibSupported})
    set_target_properties(${PROJECT_NAME}Test
        PROPERTIES
    	    INSTALL_RPATH "../lib")
endif()    	    
	    
set(INSTALL_TEST_EXECUTABLE ${PROJECT_NAME}Test)

include_directories(${CMAKE_SOURCE_DIR}/src)

set(DEP_TARGET ${PROJECT_NAME}Test)
set(DEP_TYPES_TO_ADD "Library" "Project" "Unit Test Framework")
include(SBE/helpers/AddDependenciesToTarget)

if(${CMAKE_CROSSCOMPILING})
    add_custom_target(test COMMENT "Not possible to run test because of cross-compiling." DEPENDS ${PROJECT_NAME}Test)
else()
    add_custom_target(test
        COMMAND cmake -E remove -f cpputest_*.xml 
        COMMAND bin/${PROJECT_NAME}Test \${CPPUTEST_FLAGS}
        DEPENDS ${PROJECT_NAME}Test)
endif()    