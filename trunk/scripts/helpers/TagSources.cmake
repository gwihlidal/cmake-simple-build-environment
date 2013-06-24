if(NOT DEFINED PROJECT_SOURCE_DIR)
    message(SEND_ERROR "PROJECT_SOURCE_DIR has to be defined")
endif()

if(NOT DEFINED PROJECT_NAME)
    message(SEND_ERROR "PROJECT_NAME has to be defined")
endif()

if(NOT DEFINED VERSION_MAJOR)
    message(SEND_ERROR "VERSION_MAJOR has to be defined")
endif()

if(NOT DEFINED VERSION_MINOR)
    message(SEND_ERROR "VERSION_MINOR has to be defined")
endif()

if(NOT DEFINED VERSION_PATCH)
    message(SEND_ERROR "VERSION_MINOR has to be defined")
endif()

find_package(Subversion)
if(NOT Subversion_SVN_EXECUTABLE)
    message(SEND_ERROR "error: could not find svn.")
endif()

include(SBE/helpers/SvnHelpers)

# get working copy info
message(STATUS "Checking working copy for trunk...")
execute_process(
    COMMAND ${Subversion_SVN_EXECUTABLE} info "${PROJECT_SOURCE_DIR}"
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out)
if(${svnResult} GREATER 0)
    message(STATUS "Could not get info about working copy")
    message(SEND_ERROR "exit")
endif()    

set(SOURCES_INFO ${out})
string(REGEX MATCH "URL: ([^ \n]+)/[0-9_a-zA-Z]+" PROJECT_SVN_ROOT "${SOURCES_INFO}")
set(PROJECT_SVN_ROOT ${CMAKE_MATCH_1})
string(REGEX MATCH "URL: [^ \n]+/([0-9_a-zA-Z]+)" SOURCES_TAG "${SOURCES_INFO}")
set(SOURCES_TAG ${CMAKE_MATCH_1})
string(REGEX MATCH "Revision: ([0-9]+)" SOURCES_REVISION "${SOURCES_INFO}")
set(SOURCES_REVISION ${CMAKE_MATCH_1})

if (NOT "${SOURCES_TAG}" STREQUAL "trunk")
    message(STATUS "Currently checkouted sources are not trunk version")
    message(SEND_ERROR "exit")
endif()

# fire error when working copy has modifications
message(STATUS "Checking working copy for modifications...")
execute_process(
    COMMAND ${Subversion_SVN_EXECUTABLE} status ${PROJECT_SOURCE_DIR}
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out)

if(${svnResult} GREATER 0)
    message(STATUS "SVN status fails")
    message(SEND_ERROR "exit")
endif()

string(LENGTH "${out}" statusLength)

if (${statusLength} GREATER 0)
    message(STATUS "Working copy has modifications\n" ${out})
    message(SEND_ERROR "exit")
endif()

#  fire error when there are new sources in repository
message(STATUS "Checking trunk is up to date...")
execute_process(
    COMMAND ${Subversion_SVN_EXECUTABLE} status --show-updates ${PROJECT_SOURCE_DIR}
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out)
if(${svnResult} GREATER 0)
    message(STATUS "Could not get info about trunk")
    message(SEND_ERROR "exit")
endif()

string(REGEX REPLACE "Status against revision:.*\n" "" out ${out})

if (NOT "${out}" STREQUAL "")
    message(STATUS "New trunk in repository. Update first.\n${out}")
    message(SEND_ERROR "exit")
endif()
    
# calculate tag name
if(VERSION_BUILD_NUMBER)
    set(TAG_NAME "rel_${VERSION_MAJOR}_${VERSION_MINOR}_${VERSION_PATCH}_${VERSION_BUILD_NUMBER}")
else()
    set(TAG_NAME "rel_${VERSION_MAJOR}_${VERSION_MINOR}_${VERSION_PATCH}")
endif()    

# check if sources are already tagged
message(STATUS "Checking tag ${TAG_NAME} in repository...")

svnIsDirectoryContains("${TAG_NAME}/" "${PROJECT_SVN_ROOT}/tags" isThere errorReason)

if(NOT "" STREQUAL ${errorReason})
    message(STATUS "Error accessing svn, when checking tag in repository:\n${errorReason}")
    message(SEND_ERROR "exit")
endif()

if(isThere)
    message(STATUS "Tag ${TAG_NAME} already exists in repository")
    message(SEND_ERROR "exit")
endif()

# when sources are not tagged and working copy is on trunk
# 1. Generate documentation for sources
# 2. Tag sources
message(STATUS "Generating Release notes...")
include(SBE/helpers/ReleaseNoteGenerator)
GenerateReleaseNote(${PROJECT_SVN_ROOT} ${PROJECT_NAME} ${TAG_NAME} releaseNote)

message(STATUS "Tagging sources, tag is ${TAG_NAME}...")

# create commit comment
if(VERSION_BUILD_NUMBER)
    set(COMMIT_COMMENT "Automatic release ${PROJECT_NAME} version ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}.${VERSION_BUILD_NUMBER}")
    set(COMMIT_RELEASE_NOTES_COMMENT "Added Release notes for ${PROJECT_NAME} version ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}.${VERSION_BUILD_NUMBER}")
else()
    set(COMMIT_COMMENT "Release ${PROJECT_NAME} version ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
    set(COMMIT_RELEASE_NOTES_COMMENT "Added Release notes for ${PROJECT_NAME} version ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
endif()

execute_process(
    COMMAND ${Subversion_SVN_EXECUTABLE} cp -m "${COMMIT_COMMENT}" "${PROJECT_SVN_ROOT}/trunk" "${PROJECT_SVN_ROOT}/tags/${TAG_NAME}"
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out)

if(${svnResult} GREATER 0)
    message(STATUS "Source tagging fails.\n${out}")
    message(SEND_ERROR "exit")
endif()

message(STATUS "Importing documentation...")

file(WRITE "ReleaseNotes" "${releaseNote}")

execute_process(
    COMMAND ${Subversion_SVN_EXECUTABLE} import -m "${COMMIT_RELEASE_NOTES_COMMENT}" "ReleaseNotes" "${PROJECT_SVN_ROOT}/tags/${TAG_NAME}/ReleaseNotes"
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out)

if(${svnResult} GREATER 0)
    file(REMOVE "ReleaseNotes")
    message(ERROR "Adding documentation fails.")
endif()

file(REMOVE "ReleaseNotes")




