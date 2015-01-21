cmake_minimum_required(VERSION 2.8)

if(NOT DEFINED ToolchainFile)
    set(ToolchainFile host-linux-vcxi-default-default-default)
endif()

if(NOT DEFINED BuildType)
    set(BuildType Debug)
endif()

file(MAKE_DIRECTORY build/${ToolchainFile}/${BuildType})

list(APPEND cmakeArgs -G "Unix Makefiles")
list(APPEND cmakeArgs -DCMAKE_BUILD_TYPE=${BuildType})
list(APPEND cmakeArgs -DCMAKE_TOOLCHAIN_FILE=SBE/toolchains/${ToolchainFile})

if(AddToolInvocationMessage)
    list(APPEND cmakeArgs -DRULE_LAUNCH_COMPILE=${CMAKE_ROOT}/Modules/SBE/tools/printAndExecuteCommand)
    list(APPEND cmakeArgs -DRULE_LAUNCH_LINK=${CMAKE_ROOT}/Modules/SBE/tools/printAndExecuteCommand)
endif()

execute_process(
    COMMAND ${CMAKE_COMMAND} -E chdir build/${ToolchainFile}/${BuildType} ${CMAKE_COMMAND} ${cmakeArgs} ../../..
)
