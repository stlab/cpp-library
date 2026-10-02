cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
cpp_library_enable_dependency_tracking()
project(sample LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
set(FIXTURE_INSTALL OFF CACHE BOOL "" FORCE)
set(type_args)
if(MISSING_LIBRARY_TYPE)
    list(APPEND type_args LIBRARY_TYPE)
elseif(DEFINED REQUESTED_TYPE)
    list(APPEND type_args LIBRARY_TYPE "${REQUESTED_TYPE}")
endif()
set(source_args SOURCES sample.cpp)
if(OMIT_SOURCES)
    set(source_args)
endif()
cpp_library_setup(
    DESCRIPTION "Explicit compiled target fixture"
    NAMESPACE fixture
    HEADERS sample.hpp
    ${source_args}
    ${type_args})
get_target_property(actual sample TYPE)
if(NOT actual STREQUAL EXPECTED_TYPE)
    message(FATAL_ERROR "Expected ${EXPECTED_TYPE}, got ${actual}")
endif()
if(NOT BUILD_SHARED_LIBS STREQUAL EXPECTED_BUILD_SHARED_LIBS)
    message(FATAL_ERROR "Setup changed parent BUILD_SHARED_LIBS")
endif()
