if(NOT DEFINED PackageRootDirectory)
    message(SEND_ERROR "PackageRootDirectory has to be defined")
endif()

include(SBE/helpers/SvnHelpers)

svnGetRepositoryForLocalDirectory(${PackageRootDirectory} url)

message(STATUS "Checking working copy for trunk...")
svnIsUrlTrunk(${url} isTrunk)
if(NOT isTrunk)
    message(SEND_ERROR "Currently checkouted sources are not trunk version")
endif()

message(STATUS "Checking working copy for modifications...")
svnIsLocalDirectoryModified(${PackageRootDirectory} isModified modifications)
if(isModified)
    message(SEND_ERROR "Working copy has modifications\n" ${modifications})
endif()

message(STATUS "Checking trunk is up to date...")
svnIslocalDirectoryOnLatesRevision(${PackageRootDirectory} isLatest modifications)
if(NOT isLatest)
    message(SEND_ERROR "New trunk in repository. Update first.\n${modifications}")
endif()

svnGetPackageRootInRepository(${url} packageUrlRoot)

message(STATUS "Checking snapshot exits in repository...")
svnIsDirectoryContains(snapshot/ ${packageUrlRoot} isThere errorReason)
if(DEFINED errorReason)
    message(SEND_ERROR "Could not get info about directory ${packageUrlRoot}.\n${errorReason}")
endif()
    
if(isThere)
    message(STATUS "Removing old snapshot...")
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} del -m "Deleting old snapshot" "${packageUrlRoot}/snapshot"
        RESULT_VARIABLE svnResultDelete
        OUTPUT_VARIABLE outd)
    
    if(${svnResultDelete} GREATER 0)
        message(SEND_ERROR "Delete of last snapshot fails.\n${outd}")
    endif()
endif()    


message(STATUS "Creating new snapshot of trunk in HEAD revison...")
# create commit comment
string(TIMESTAMP snapshotDateAsText "%d.%m.%Y %H:%M:%S")
set(COMMIT_COMMENT "Snapshot of ${Name} trunk revision ${revision} on ${snapshotDateAsText}")

svnGetRepositoryDirectoryRevision(${packageUrlRoot}/trunk revision error)
if(DEFINED error)
    message(SEND_ERROR "Snapshot of sources fails. Could not get trunk revision.\n${error}")
endif()

execute_process(
    COMMAND ${Subversion_SVN_EXECUTABLE} cp -m "${COMMIT_COMMENT}" -r ${revision} "${packageUrlRoot}/trunk" "${packageUrlRoot}/snapshot"
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out)

if(${svnResult} GREATER 0)
    message(SEND_ERROR "Snapshot of sources fails.\n${out}")
endif()

