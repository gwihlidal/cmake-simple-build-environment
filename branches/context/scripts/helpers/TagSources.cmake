if(NOT DEFINED PackageRootDirectory)
    message(SEND_ERROR "PackageRootDirectory has to be defined")
endif()

if(NOT DEFINED ContextFile)
    message(SEND_ERROR "ContextFile has to be defined")
endif()

include(SBE/helpers/SvnHelpers)
include(SBE/helpers/ContextParser)
include(SBE/helpers/JSonParser)

set(Ident "    ")

function(UpdateReleaseNoteFile dependencies tagName releaseDate overview)
    generateHeaderSection(headerSection ${releaseDate} ${tagName})
    generateOverviewSection(overviewSection "${overview}")
    generateIssuesSection(issuesSection)
    generateDependneciesSection(dependenciesSection "${dependencies}")
    
    set(content "${headerSection}\n")
    if(DEFINED overviewSection)
        string(CONCAT content ${content} "\n${overviewSection}\n")
    endif()
    if(DEFINED issuesSection)
        string(CONCAT content ${content} "\n${issuesSection}\n")
    endif()
    if(DEFINED dependenciesSection)
        string(CONCAT content ${content} "\n${dependenciesSection}\n")
    endif()
    
    if(EXISTS ${PackageRootDirectory}/ReleaseNotes)
        file(READ ${PackageRootDirectory}/ReleaseNotes old)
    endif()
    file(WRITE ${PackageRootDirectory}/ReleaseNotes ${content} ${old})   
endfunction()

function(generateIssuesSection content)
    if("" STREQUAL "${JiraUrl}" OR "" STREQUAL "${JiraProjectKeys}")
        return()
    endif()

    # get credentials for access jira
    set(configurationFile "")
    if("Windows" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}")
        set(configurationFile "$ENV{APPDATA}\\SimpleBuildEnvironmentE\\JiraConfiguration.cmake")
    elseif("Linux" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}")
        set(configurationFile "$ENV{HOME}/.SimpleBuildEnvironment/JiraConfiguration.cmake")
    endif()
    if(NOT EXISTS ${configurationFile})
        message(STATUS "   Skipping jira issues due to no configuration file [${configurationFile}] is found")
        return()
    endif()
    
    # get last tag from ReleaseNotes and its revision
    If(EXISTS ${PackageRootDirectory}/ReleaseNotes)
        file(READ ${PackageRootDirectory}/ReleaseNotes old LIMIT 500)
        string(REGEX MATCH "^([^ \t]+)" stringTag "${old}")
        set(lastTag ${CMAKE_MATCH_1})
        svnGetRepositoryForLocalDirectory(${PackageRootDirectory} url)
        svnGetPackageRootInRepository(${url} urlRoot)
        svnGetRepositoryDirectoryRevision(${urlRoot}/tags/${lastTag} revision error)
    endif()

    # get commit log between last tag and trunk HEAD
    if (DEFINED revision)
        svnGetLogBetweenRevisions(${PackageRootDirectory} ${revision} HEAD svnlog)
    else()
        svnGetLog(${PackageRootDirectory} svnlog)
    endif()
    
    message(STATUS "   Getting issues from svn ${revision}:HEAD for ${JiraProjectKeys}")
    # get issues from log
    string(REPLACE ";" "\\;" svnlog "${svnlog}")
    string(REGEX REPLACE "^-+\n" "" svnlog "${svnlog}")
    string(REGEX REPLACE "\n-+\n" "\n;" svnlog "${svnlog}")

    set(issues "")
    string(REPLACE "," ";" JiraProjectKeys "${JiraProjectKeys}")
    foreach(logEntry ${svnlog})
        string(REGEX MATCH "^r[0-9]+ \\| ([a-z]+)" commiter "${logEntry}")
        set(commiter "${CMAKE_MATCH_1}")

        foreach(key ${JiraProjectKeys})
            string(REGEX MATCHALL "(${key}-[0-9]+)" keyIssues "${svnlog}")
            
            list(APPEND issues ${keyIssues})
            
            foreach(entryIssue ${keyIssues})
                set(${entryIssue}_Key ${key})
                list(APPEND ${entryIssue}_Commiters ${commiter})
                list(REMOVE_DUPLICATES ${entryIssue}_Commiters)
            endforeach()
        endforeach()
    endforeach()
    list(REMOVE_DUPLICATES issues)
    
    if("" STREQUAL "${issues}")
        message(STATUS "   No issue found")
        return()
    endif()
    
    include(${configurationFile} OPTIONAL)
    
    # get issues data
    foreach(issue ${issues})
        message(STATUS "   Exporting issue ${issue}")
        setIssueData(${issue})
    endforeach()
    
    # check if it is necessary to get data of parent issues
    set(parentIssues "")
    foreach(issue ${issues})
        if(NOT "" STREQUAL "${${issue}_ParentIssue}")
            list(APPEND parentIssues ${${issue}_ParentIssue})
            list(APPEND ${${issue}_ParentIssue}_Commiters ${${issue}_Commiters})
            set(${${issue}_ParentIssue}_Key ${${issue}_Key})
        endif()
    endforeach()    
    list(REMOVE_DUPLICATES parentIssues)
    if(NOT "" STREQUAL "${issues}")
        list(REMOVE_ITEM parentIssues ${issues})
        list(APPEND issues ${parentIssues})
    endif()
    foreach(issue ${parentIssues})
        message(STATUS "   Exporting issue ${issue}")
        setIssueData(${issue})
    endforeach()
    
    # compose the section text
    set(extensions "")
    set(bugfixes "")
    foreach(issue ${issues})
        if(DEFINED ${${issue}_Key}_extension)
            list(FIND ${${issue}_Key}_extension "${${issue}_Type}" isFound)
            if(${isFound} GREATER -1)    
                list(APPEND extensions ${issue})
            endif()
        endif()
        
        if(DEFINED ${${issue}_Key}_bugfix)
            list(FIND ${${issue}_Key}_bugfix "${${issue}_Type}" isFound)
            if(${isFound} GREATER -1)
                list(APPEND bugfixes ${issue})
            endif()
        endif()
    endforeach()
    
    set(c "")
    if(NOT "" STREQUAL "${extensions}")
        string(CONCAT c ${c} "${Ident}<extensions>\n")
        foreach(ext ${extensions})
            set(issueIdText "${Ident}${Ident}+ <jira ${ext}>")
            string(CONCAT c ${c} "${issueIdText} ${${ext}_Subject}\n")
            string(LENGTH "${issueIdText}" issueIdLen)
            foreach(n RANGE ${issueIdLen})
                string(CONCAT c ${c} " ")
            endforeach()
            string(REGEX REPLACE ";$" "" commiters "${${ext}_Commiters}")
            string(REPLACE ";" ", " commiters ${commiters})
            string(CONCAT c ${c} "Developers ${commiters}\n")
        endforeach()            
    endif()
    if(NOT "" STREQUAL "${bugfixes}")
        string(CONCAT c ${c} "${Ident}<bugfixes>\n")
        foreach(ext ${bugfixes})
            set(issueIdText "${Ident}${Ident}+ <jira ${ext}>")
            string(CONCAT c ${c} "${issueIdText} ${${ext}_Subject}\n")
            string(LENGTH "${issueIdText}" issueIdLen)
            foreach(n RANGE ${issueIdLen})
                string(CONCAT c ${c} " ")
            endforeach()
            string(REGEX REPLACE ";$" "" commiters "${${ext}_Commiters}")
            string(REPLACE ";" ", " commiters ${commiters})
            string(CONCAT c ${c} "Developers ${commiters}\n")
        endforeach()            
    endif()    
    
    set(${content} ${c} PARENT_SCOPE)    
endfunction()

macro(setIssueData issue)
    # get project key from issue name
    string(REGEX REPLACE "-[0-9]+" "" key "${issue}")
    set(credentials "")
    if(NOT "" STREQUAL "${${key}_user}" AND NOT "" STREQUAL "${${key}_pass}")
        set(credentials -u "${${key}_user}:${${key}_pass}")
    endif()
    # get data from jira
    execute_process(
        COMMAND  curl -m 60 -s --noproxy "*" ${credentials} -X GET "\"Content-Type: application/json\"" ${JiraUrl}:8080/rest/api/2/issue/${issue}
        OUTPUT_VARIABLE issueJsonData
        )
    sbeParseJson(issue "${issueJsonData}")
    set(${issue}_Projects "")
    foreach(labelId ${issue.fields.labels})
        list(APPEND ${issue}_Projects "${issue.fields.labels_${labelId}}")
    endforeach()
    set(${issue}_Subject "${issue.fields.summary}")
    set(${issue}_Type "${issue.fields.issuetype.name}")
    set(${issue}_ParentIssue "${issue.fields.parent.key}")
    sbeClearJson(issue)        
endmacro()

function(generateDependneciesSection content dependencies)
    if("" STREQUAL "${dependencies}")
        return()
    endif()
    
    message(STATUS "   Adding Dependencies")
    
    set(maxNameLength 0)
    foreach(dep ${dependencies})
        string(LENGTH "${dep}" len)
        if(${maxNameLength} LESS ${len})
            set(maxNameLength ${len})
        endif()
    endforeach()
    
    set(c "${Ident}<dependencies>")
    foreach(dep ${dependencies})
        string(CONCAT c ${c} "\n${Ident}${Ident}${dep}")
        string(LENGTH "${dep}" len)
        math(EXPR spaceNumber "${maxNameLength} - ${len}")
        foreach(n RANGE ${spaceNumber})
            string(CONCAT c ${c} " ")
        endforeach()
        
        sbeGetPackageUrl(${dep} depUrl)
        string(CONCAT c ${c} "${depUrl}")
    endforeach()
    
    set(${content} ${c} PARENT_SCOPE)        
endfunction()

function(generateOverviewSection content overview)
    if(NOT "" STREQUAL "${overview}")
        message(STATUS "   Adding Overview")
        string(REPLACE "\n\r?" "\n${Ident}${Ident}" o "${Ident}${Ident}${overview}")
        string(REPLACE "\\n" "\n${Ident}${Ident}" o "${o}")
        string(REPLACE "\n+$" "" o "${o}")
        set(${content} "${Ident}<overview>\n${o}" PARENT_SCOPE)
    endif()
endfunction()

function(generateHeaderSection content releaseDate tagName)
    getUser(user)
    set(${content} "${tagName} (${user} ${releaseDate})" PARENT_SCOPE)
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
    string(REPLACE "." "_" version "${SemanticVersion}")
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
if(DEFINED OverallDependencies)
    string(REPLACE "," ";" OverallDependencies "${OverallDependencies}")
    
    if(NOT SKIP_DEPENDENCIES)
        message(STATUS "Checking dependencies...")
    
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
    if(NOT TAG_ENDING)
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

sbeGetPackageUrl(${Name} urlInContextFile)
if(DEFINED urlInContextFile)
    message(STATUS "Updating context file...")
    sbeUpdateUrlInContextFile(${ContextFile} ${packageUrlRoot}/tags/${tagName} ${urlInContextFile})
else()
    message(STATUS "Adding ${Name} to context file...")
    sbeAddUrlInContextFile(${ContextFile} ${Name} ${packageUrlRoot}/tags/${tagName})
endif()

if(SWITCH_TO_NEW_TAG)
    message(STATUS "Switching to new tag ${tagName}...")
    
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} switch "${packageUrlRoot}/tags/${tagName}"
        WORKING_DIRECTORY ${PackageRootDirectory}
        RESULT_VARIABLE svnResult
        OUTPUT_VARIABLE out)
    
    if(${svnResult} GREATER 0)
        message(SEND_ERROR "Switch to new tag fails.\n${out}")
    endif()
endif()


