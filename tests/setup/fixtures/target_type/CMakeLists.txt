cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
cpp_library_enable_dependency_tracking()
project(sample LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
set(FIXTURE_INSTALL OFF CACHE BOOL "" FORCE)
set(source_args SOURCES sample.cpp)
if(OMIT_SOURCES)
    set(source_args)
endif()
cpp_library_setup(
    DESCRIPTION "Consumer-selected target type fixture"
    NAMESPACE fixture
    HEADERS sample.hpp
    ${source_args})
get_target_property(actual sample TYPE)
if(NOT actual STREQUAL EXPECTED_TYPE)
    message(FATAL_ERROR "Expected ${EXPECTED_TYPE}, got ${actual}")
endif()
if(NOT BUILD_SHARED_LIBS STREQUAL EXPECTED_BUILD_SHARED_LIBS)
    message(FATAL_ERROR "Setup changed parent BUILD_SHARED_LIBS")
endif()
