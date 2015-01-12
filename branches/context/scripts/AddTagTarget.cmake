cmake_minimum_required(VERSION 2.8)

set(versionBuildNum "")
set(force "")
if("Windows" STREQUAL "${CMAKE_SYSTEM_NAME}")
    set(versionBuildNum "\$(VERSION_BUILD_NUMBER)")
    set(force "\$(FORCE)")
elseif("Linux" STREQUAL "${CMAKE_SYSTEM_NAME}")
    set(versionBuildNum "\${VERSION_BUILD_NUMBER}")
    set(force "\${FORCE}")
endif()
        
add_custom_target(tag
    COMMAND ${CMAKE_COMMAND}
        -DVERSION_PATCH=${VERSION_PATCH}
        -DVERSION_MINOR=${VERSION_MINOR} 
        -DVERSION_MAJOR=${VERSION_MAJOR}
        -DVERSION_BUILD_NUMBER=${versionBuildNum}
        -DFORCE=\${FORCE}
        -DPROJECT_NAME=${PROJECT_NAME}
        -DPROJECT_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -P ${CMAKE_ROOT}/Modules/SBE/helpers/TagSources.cmake)
