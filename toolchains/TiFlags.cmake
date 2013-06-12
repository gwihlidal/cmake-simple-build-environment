if( NOT DEFINED TIDSP_TYPE)
    message(FATAL_ERROR "Dsp type has to be set e.g. mv64+")
endif()

set(CMAKE_CXX_FLAGS_DEBUG_INIT "-g")
set(CMAKE_C_FLAGS_DEBUG_INIT "-g")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT "-${TIDSP_TYPE} --stack_size=0x4000 --heap_size=0x4000 --reread_libs --warn_sections --rom_model")

set(CMAKE_CXX_FLAGS_RELEASE_INIT "-O3")
set(CMAKE_C_FLAGS_RELEASE_INIT "-O3")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT "-${TIDSP_TYPE} --stack_size=0x1000 --heap_size=0x1000 --reread_libs --warn_sections --rom_model")

set(CMAKE_CXX_FLAGS_DEBUGWITHCOVERAGE "-g")
set(CMAKE_C_FLAGS_DEBUGWITHCOVERAGE "-g")
set(CMAKE_EXE_LINKER_FLAGS_DEBUGWITHCOVERAGE "-${TIDSP_TYPE} --stack_size=0x4000 --heap_size=0x4000 --reread_libs --warn_sections --rom_model")

