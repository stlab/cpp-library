cmake_minimum_required(VERSION 3.24)
project(runtime-dlls LANGUAGES CXX)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
enable_testing()
add_library(runtime SHARED runtime.cpp)
set_target_properties(runtime PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS ON
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/runtime")
add_executable(client main.cpp)
target_link_libraries(client PRIVATE runtime)
set_target_properties(client PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/client apps")
cpp_library_copy_runtime_dlls(client)
add_test(NAME runtime-consumer COMMAND client)
add_executable(static_client main.cpp runtime.cpp)
set_target_properties(static_client PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/static apps")
cpp_library_copy_runtime_dlls(static_client)
add_test(NAME static-consumer COMMAND static_client)
file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/runtime-dlls.cmake"
    CONTENT "set(runtime_dlls [[$<TARGET_RUNTIME_DLLS:client>]])\n")
