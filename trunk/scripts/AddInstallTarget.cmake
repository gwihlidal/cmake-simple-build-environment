cmake_minimum_required(VERSION 2.8)

install(TARGETS ${INSTALL_LIBRARIES} ${INSTALL_EXECUTABLE} EXPORT ${PROJECT_NAME}Targets
            RUNTIME DESTINATION bin COMPONENT Binaries
            LIBRARY DESTINATION lib NAMELINK_SKIP COMPONENT Binaries
            ARCHIVE DESTINATION lib)

if(DEFINED INSTALL_TEST_EXECUTABLE)
    install(TARGETS ${INSTALL_TEST_EXECUTABLE} EXPORT ${PROJECT_NAME}Targets
            RUNTIME DESTINATION bin COMPONENT Binaries CONFIGURATIONS Debug | DebugWithCoverage)
endif()

install(EXPORT ${PROJECT_NAME}Targets DESTINATION config COMPONENT Configs)
if(DEFINED PUBLIC_HEADER_FILES)
    install(FILES ${PUBLIC_HEADER_FILES} DESTINATION include/${PROJECT_NAME} COMPONENT Headers)
endif()
if(DEFINED PUBLIC_MOCK_HEADER_FILES)
    install(FILES ${PUBLIC_MOCK_HEADER_FILES} DESTINATION include/${PROJECT_NAME}/mock COMPONENT Headers)
endif()
    
# Create the Config.cmake and ConfigVersion files
if(DEFINED INSTALL_LIBRARIES)
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/LibraryPackageConfig.cmake.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake" @ONLY)
endif()
if(DEFINED INSTALL_EXECUTABLE)
    configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ExecutablePackageConfig.cmake.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake" @ONLY)
endif()
configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)
 
# Install the Config.cmake and ConfigVersion.cmake
install(FILES
  "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
  "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  DESTINATION config COMPONENT Configs) 


