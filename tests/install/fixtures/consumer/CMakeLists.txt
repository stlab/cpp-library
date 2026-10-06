cmake_minimum_required(VERSION 3.24)
project(consumer LANGUAGES CXX)
include(CTest)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
find_package(stlab-parent 1.0.0 REQUIRED)
get_target_property(imported stlab::leaf IMPORTED)
get_target_property(leaf_type stlab::leaf TYPE)
if(NOT imported OR NOT leaf_type STREQUAL EXPECTED_LEAF_TYPE)
    message(FATAL_ERROR "Expected installed ${EXPECTED_LEAF_TYPE}, got ${leaf_type}")
endif()

# These standalone main functions need no doctest headers or runtime.
add_library(doctest::doctest INTERFACE IMPORTED)
_cpp_library_setup_executables(
    NAME parent NAMESPACE stlab TYPE tests EXECUTABLES consumer.cpp)
_cpp_library_setup_executables(
    NAME parent NAMESPACE stlab TYPE examples EXECUTABLES example.cpp)
set_target_properties(consumer PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/client apps/tests")
set_target_properties(example PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/client apps/examples")

if(WIN32)
    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/runtime-dlls.cmake"
        CONTENT "set(runtime_dlls \"$<TARGET_RUNTIME_DLLS:consumer>\")\n")
endif()
