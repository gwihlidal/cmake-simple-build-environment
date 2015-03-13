if(NOT DEFINED Directory)
    message(SEND_ERROR "Directory has to be defined")
endif()

if(NOT DEFINED ContentFile)
    message(SEND_ERROR "ContentFile has to be defined")
endif()

if(NOT DEFINED Name)
    message(SEND_ERROR "Name has to be defined")
endif()

if(NOT DEFINED OverallDependencies)
    # it is ok
endif()

include(SBE/helpers/ArgumentParser)
include(SBE/helpers/ContextParser)

sbeLoadContextFile(${ContentFile})
string(REPLACE "," ";" OverallDependencies "${OverallDependencies}")
file(MAKE_DIRECTORY ${Directory}/doc)

# generate Releases
set(releases "")
foreach(dep ${OverallDependencies})
    sbeGetPackageLocalPath(${dep} path)
    set(ReleaseNotes "${path}/ReleaseNotes")
    file(STRINGS ${ReleaseNotes} firstLine LIMIT_COUNT 1)
    string(CONCAT releases ${releases} "${dep}: ${firstLine}\n")
endforeach()

file(WRITE ${Directory}/doc/Releases.${Name} "${releases}")

# generate md5 check sum
set(md5 "")
file(GLOB_RECURSE packedFiles RELATIVE ${Directory} ${Directory}/*)
foreach(f ${packedFiles})
    file(MD5 ${Directory}/${f} sum)
    string(CONCAT md5 ${md5} "${sum} ${f}\n")
endforeach()

file(WRITE ${Directory}/doc/md5.${Name} "${md5}")

