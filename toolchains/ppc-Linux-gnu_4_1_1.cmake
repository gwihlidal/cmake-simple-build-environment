SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_SYSTEM_PROCESSOR "ppc")

# specify the cross compiler
SET(CMAKE_C_COMPILER   /project/devtools/ext-tools/crosstools/rel_0_22_0/powerpc-603e-linux-gnu/bin/powerpc-603e-linux-gnu-gcc)
SET(CMAKE_CXX_COMPILER /project/devtools/ext-tools/crosstools/rel_0_22_0/powerpc-603e-linux-gnu/bin/powerpc-603e-linux-gnu-g++)
SET(CMAKE_STRIP        /project/devtools/ext-tools/crosstools/rel_0_22_0/powerpc-603e-linux-gnu/bin/powerpc-603e-linux-gnu-strip)

# where is the target environment 
SET(CMAKE_FIND_ROOT_PATH  
    /project/devtools/ext-tools/crosstools/rel_0_22_0/powerpc-603e-linux-gnu
    /project/devtools/ext-tools/crosstools/rel_0_22_0/powerpc-603e-linux-gnu/powerpc-603e-linux-gnu)

# search for programs in the build host directories
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# for libraries and headers in the target directories
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CMAKE_USER_MAKE_RULES_OVERRIDE SBE/toolchains/GnuFlags)
