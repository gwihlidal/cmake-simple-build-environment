set(CMAKE_SYSTEM_NAME "Generic")
SET(CMAKE_SYSTEM_PROCESSOR "tidsp_mv64")
set(TIDSP_TYPE "mv64+")

# specify the cross compiler
SET(CMAKE_C_COMPILER   /project/devtools/ext-tools/crosstools_ti/C6000/rel_6_1_13/CGT/bin/cl6x)
SET(CMAKE_CXX_COMPILER /project/devtools/ext-tools/crosstools_ti/C6000/rel_6_1_13/CGT/bin/cl6x)
SET(CMAKE_AR           /project/devtools/ext-tools/crosstools_ti/C6000/rel_6_1_13/CGT/bin/ar6x)
SET(CMAKE_STRIP        /project/devtools/ext-tools/crosstools_ti/C6000/rel_6_1_13/CGT/bin/strip6x)
SET(CMAKE_RANLIB       "")

# where is the target environment 
SET(CMAKE_FIND_ROOT_PATH  /project/devtools/ext-tools/crosstools_ti/C6000/rel_6_1_13/CGT)

# search for programs in the build host directories
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# for libraries and headers in the target directories
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

include_directories(/project/devtools/ext-tools/crosstools_ti/C6000/rel_6_1_13/CGT/include)
link_directories(/project/devtools/ext-tools/crosstools_ti/C6000/rel_6_1_13/CGT/lib)

set(CMAKE_USER_MAKE_RULES_OVERRIDE SBE/toolchains/TiFlags)