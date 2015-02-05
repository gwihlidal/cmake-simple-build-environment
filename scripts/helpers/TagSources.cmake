if(NOT DEFINED PackageRootDirectory)
    message(SEND_ERROR "PackageRootDirectory has to be defined")
endif()

if(NOT DEFINED ContextFile)
    message(SEND_ERROR "ContextFile has to be defined")
endif()

include(SBE/helpers/SvnHelpers)
include(SBE/helpers/ContextParser)

function(UpdateReleaseNoteFile dependencies tagName releaseDate overview)
    getUser(user)
    list(APPEND content "${tagName} (${user} ${releaseDate})\n")
    
    if(NOT "" STREQUAL "${overview}" OR NOT "" STREQUAL "${dependencies}")
        list(APPEND content "---[ALL]---\n")
    endif()
    
    if(NOT "" STREQUAL "${overview}")
        list(APPEND content "   <overview>\n")
        string(REPLACE "\n" "\n      " overview "${overview}")
        list(APPEND content "      ${overview}\n")
    endif()
    
    if(NOT "" STREQUAL "${dependencies}")
        list(APPEND content "   <dependencies>\n")
        foreach(dep ${dependencies})
            sbeGetPackageUrl(${dep} depUrl)
            list(APPEND content "      ${dep} ${depUrl}\n")
        endforeach()
    endif() 
    
    if(EXISTS ${PackageRootDirectory}/ReleaseNotes)
        file(READ ${PackageRootDirectory}/ReleaseNotes old)
    endif()
    file(WRITE ${PackageRootDirectory}/ReleaseNotes ${content} ${old})   
endfunction()


macro(getUser user)
    if(WIN32)
        set(${user} "$ENV{USERNAME}")
    elseif(UNIX)
        set(${user} "$ENV{USER}")
    else()
        set(${user} "unknown")
    endif()
endmacro()


sbeLoadContextFile(${ContextFile})
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

if(NOT FORCE)
    message(STATUS "Checking trunk changes against last tag...")
    svnIsTrunkChangedAgainstLastTags("${packageUrlRoot}" isChanged errorReason)

    if (NOT "${errorReason}" STREQUAL "")
        message(SEND_ERROR "Error when getting info about trunk or tags.\n${errorReason}")
    endif()

    if (NOT isChanged)
        svnGetNewestSubdirectory("${packageUrlRoot}/tags" newestSubDirectory errorReason)
        message(STATUS "Trunk is already tagged in ${newestSubDirectory}")
        return()
    endif()
endif()


# calculate tag name
include(${PackageRootDirectory}/Properties.cmake)

set(tagName "")
set(version "")
set(versionRevision "")
string(TIMESTAMP releaseDate "%Y%m%d%H%M%S")
string(TIMESTAMP releaseDateAsText "%d.%m.%Y %H:%M:%S")
if(DEFINED SemanticVersion)
    include(SBE/helpers/VersionParser)
    sbeSplitSemanticVersion(${SemanticVersion} major minor bugfix)
    set(version "${major}_${minor}_${bugfix}")
    set(tagName "rel_${version}")
elseif(DEFINED DateVersion)
    set(version ${releaseDate})
    set(tagName "rel_${version}")
else()
    message(SEND_ERROR "One of SemanticVersion or DateVersion has to be defined")
endif()

if(TAG_ENDING)
    set(tagName "${tagName}-${TAG_ENDING}")
endif()

# check if sources are already tagged
message(STATUS "Checking tag ${tagName} in repository...")

svnIsDirectoryContains("${tagName}/" "${packageUrlRoot}/tags" isThere errorReason)

if(NOT "" STREQUAL "${errorReason}")
    message(SEND_ERROR "Error accessing svn, when checking tag in repository:\n${errorReason}")
endif()

if(isThere)
    message(SEND_ERROR "Tag ${tagName} already exists in repository")
endif()

# check dependencies
if(DEFINED OverallDependencies AND NOT SKIP_DEPENDENCIES)
    message(STATUS "Checking dependencies...")

    string(REPLACE "," ";" OverallDependencies "${OverallDependencies}")
    
    foreach(dep ${OverallDependencies})
        message(STATUS "   Checking ${dep}...")
        sbeGetPackageLocalPath(${dep} packagePath)
        sbeGetPackageUrl(${dep} packageUrl)
        
        svnIsLocalDirectoryModified(${packagePath} isModified modifications)
        if(isModified)
            message(SEND_ERROR "Dependency ${dep} is locally modified")
        endif()
        
        svnGetRepositoryForLocalDirectory(${packagePath} url)
        svnIsUrlTag(${url} isTag)
        
        if(isTag)
            if(NOT "${url}" STREQUAL "${packageUrl}")
                message(SEND_ERROR "Dependency ${dep} has checkouted different tag as in context file")
            endif()
        else()
            svnGetRepositoryDirectoryRevision("${packageUrl}" tagsRevision error)
            svnGetRepositoryDirectoryRevision("${url}" trunkRevision error)
            # Report error sources are different between context file and local checkout
            # the sources are equal if tag mentioned in context file has bigger revision as trunk (tagged trunk)
            # and revision of this lates trunk is also in local checkout
            if(${trunkRevision} GREATER ${tagsRevision})
                message(SEND_ERROR "Dependency ${dep} has checkouted newer trunk as release in context file")
            endif()
            svnIslocalDirectoryOnLatesRevision(${packagePath} isLatest modifications)
            if(NOT isLatest)
                message(SEND_ERROR "Dependency ${dep} has checkouted older trunk as released in context file")
            endif()
                        
        endif()        
    endforeach()
endif()

# update version in properties file in case of date version
if(DEFINED DateVersion)
    message(STATUS "Updating Date version...")
    include(SBE/helpers/PropertiesParser)
    sbeUpdateDateVersion(${releaseDate} ${PackageRootDirectory}/Properties.cmake)
endif()

# update release notes
message(STATUS "Updating Release notes...")
UpdateReleaseNoteFile(
    "${OverallDependencies}" 
    ${tagName} 
    "${releaseDateAsText}" 
    "${RELEASE_NOTE_OVERVIEW}"
)

# check if ReleaseNotes has to be added before commit
svnGetStatus(LocalDirectory ${PackageRootDirectory} IsError isError Status status)
if(isError)
    message(SEND_ERROR "Could not get status of package directory")
endif()

if("${status}" MATCHES "\\?[ \t].*ReleaseNotes\n")
    # add ReleaseNotes to repository
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} add ReleaseNotes
        WORKING_DIRECTORY ${PackageRootDirectory}
        RESULT_VARIABLE svnResult
        OUTPUT_VARIABLE out)
        
    if(${svnResult} GREATER 0)
        message(SEND_ERROR "Could not adding ReleaseNotes to repository")
    endif()
endif()

# commit changed files
execute_process(
    COMMAND ${Subversion_SVN_EXECUTABLE} commit -m "Adding modified files for release ${tagName}"
    WORKING_DIRECTORY ${PackageRootDirectory} 
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out)

if(${svnResult} GREATER 0)
    message(SEND_ERROR "Could not commit of modified files")
endif()

# Tag sources
message(STATUS "Tagging sources, tag is ${tagName}...")

# create commit comment
if(NOT COMMIT_COMMENT)
    if(NOT DEFINED TAG_ENDING)
        set(COMMIT_COMMENT "Release ${Name} version ${version}")
    else()
        set(COMMIT_COMMENT "Release ${Name} version ${version} (${TAG_ENDING})")
    endif()
endif()

execute_process(
    COMMAND ${Subversion_SVN_EXECUTABLE} cp -m "${COMMIT_COMMENT}" "${packageUrlRoot}/trunk" "${packageUrlRoot}/tags/${tagName}"
    RESULT_VARIABLE svnResult
    OUTPUT_VARIABLE out)

if(${svnResult} GREATER 0)
    message(SEND_ERROR "Source tagging fails.\n${out}")
endif()

message(STATUS "Updating context file...")
sbeUpdateUrlInContextFile(${ContextFile} ${Name} ${packageUrlRoot}/tags/${tagName})



