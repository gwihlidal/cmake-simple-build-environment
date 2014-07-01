cmake_minimum_required(VERSION 2.8)

include(SBE/helpers/DependenciesParser)
    
set(INSTALL_LIBRARIES "")
set(INSTALL_TARGETS "")

include(${DEP_INFO_FILE})

ParseDependencies("${DEPENDENCIES}" ownDependenciesIds)

foreach(dep ${ownDependenciesIds})
    set(depName ${${dep}_Name})
    
    list(APPEND INSTALL_TARGETS ${depName})
 endforeach()
    
# Create the Config.cmake and ConfigVersion files
configure_file(${CMAKE_ROOT}/Modules/SBE/templates/ContainerPackageConfig.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake" @ONLY)
configure_file(${CMAKE_ROOT}/Modules/SBE/templates/PackageConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)
 
# Install the Config.cmake and ConfigVersion.cmake
install(FILES
  "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}Config.cmake"
  "${PROJECT_BINARY_DIR}/Export/config/${PROJECT_NAME}ConfigVersion.cmake"
  DESTINATION config COMPONENT Configs) 


