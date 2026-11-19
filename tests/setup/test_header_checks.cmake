# SPDX-License-Identifier: BSL-1.0
#
# Run as: cmake -P tests/setup/test_header_checks.cmake

cmake_minimum_required(VERSION 3.24)

get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/header-checks-${test_id}")
set(source "${test_root}/source")
file(MAKE_DIRECTORY "${source}/library/include/fixture" "${source}/library/src"
    "${source}/library/usage")
file(WRITE "${source}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.24)
project(consumer LANGUAGES CXX)
add_subdirectory(library)
]=])
file(WRITE "${source}/library/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
project(checked LANGUAGES CXX)
include(CTest)
include("${TOOLKIT_SOURCE}/tests/setup/fixtures/mock_doctest.cmake")
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(source_args)
if(COMPILED)
    set(source_args SOURCES library.cpp)
    set(usage PUBLIC)
else()
    set(usage INTERFACE)
endif()
foreach(header dependent late)
    if((header STREQUAL "dependent" AND BAD_PRIMARY) OR
            (header STREQUAL "late" AND BAD_LATE))
        set(include "")
    else()
        set(include "#include <cstdint>\n")
    endif()
    file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/${header}.hpp"
        "#pragma once\n${include}using ${header}_integer = std::uint32_t;\n")
endforeach()
cpp_library_setup(DESCRIPTION "Independent public headers" NAMESPACE fixture
    HEADERS api.hpp platform.hpp dependent.hpp
    REQUIRES_CPP_VERSION "${CMAKE_CXX_STANDARD}" ${source_args})

add_library(public_requirements INTERFACE)
target_include_directories(public_requirements INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/usage")
target_compile_definitions(public_requirements INTERFACE
    REQUIRED_PUBLIC_VALUE=42 "REQUIRED_STANDARD=${CMAKE_CXX_STANDARD}")
target_link_libraries(checked ${usage} public_requirements)

set(generated "${CMAKE_CURRENT_BINARY_DIR}/generated include/fixture/generated.hpp")
add_custom_command(OUTPUT "${generated}"
    COMMAND "${CMAKE_COMMAND}" "-DOUTPUT=${generated}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/generate.cmake"
    VERBATIM)
add_custom_target(generate_header DEPENDS "${generated}")
add_dependencies(checked generate_header)
target_sources(checked ${usage} FILE_SET extra_headers TYPE HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" "${CMAKE_CURRENT_BINARY_DIR}/generated include"
    FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/late.hpp" "${generated}")
]=])
file(WRITE "${source}/library/generate.cmake" [=[
get_filename_component(directory "${OUTPUT}" DIRECTORY)
file(MAKE_DIRECTORY "${directory}")
file(WRITE "${OUTPUT}" "#pragma once\n#define FIXTURE_PLATFORM_AVAILABLE 0\n")
]=])
file(WRITE "${source}/library/usage/public_requirement.hpp" "#pragma once\n")
file(WRITE "${source}/library/include/fixture/api.hpp" [=[
#pragma once
#include <cstdint>
#include <optional>
#include <fixture/generated.hpp>
#include <public_requirement.hpp>

static_assert(REQUIRED_PUBLIC_VALUE == 42);
static_assert(std::optional<int>{42}.value() == 42);
#if defined(_MSVC_LANG)
#define FIXTURE_CPLUSPLUS _MSVC_LANG
#else
#define FIXTURE_CPLUSPLUS __cplusplus
#endif
#if REQUIRED_STANDARD >= 20
static_assert(FIXTURE_CPLUSPLUS >= 202002L);
#endif
#if REQUIRED_STANDARD == 23
static_assert(FIXTURE_CPLUSPLUS > 202002L);
#endif
]=])
file(WRITE "${source}/library/include/fixture/platform.hpp" [=[
#pragma once
#include <fixture/generated.hpp>
#if FIXTURE_PLATFORM_AVAILABLE
#include <unavailable_platform_sdk.hpp>
#endif
]=])
file(WRITE "${source}/library/src/library.cpp" [=[
#include <fixture/api.hpp>
#include <fixture/dependent.hpp>
#include <fixture/late.hpp>
]=])

# Builds a fixture and checks automatic header verification or its scope boundary.
function(run_case name)
    cmake_parse_arguments(ARG "COMPILED;BAD_PRIMARY;BAD_LATE;TESTING_OFF;NESTED" "STANDARD" "" ${ARGN})
    if(NOT ARG_STANDARD)
        set(ARG_STANDARD 20)
    endif()
    if(ARG_NESTED)
        set(project_source "${source}")
        set(project_binary "${test_root}/${name}/library")
    else()
        set(project_source "${source}/library")
        set(project_binary "${test_root}/${name}")
    endif()
    if(ARG_TESTING_OFF)
        set(testing OFF)
    else()
        set(testing ON)
    endif()
    execute_process(COMMAND "${CMAKE_COMMAND}" -S "${project_source}" -B "${test_root}/${name}"
        -G Ninja "-DTOOLKIT_SOURCE=${toolkit_source}" "-DCMAKE_CXX_STANDARD=${ARG_STANDARD}"
        "-DCOMPILED=${ARG_COMPILED}" "-DBAD_PRIMARY=${ARG_BAD_PRIMARY}" "-DBAD_LATE=${ARG_BAD_LATE}"
        "-DBUILD_TESTING=${testing}" -DBUILD_DOCS=OFF -DFIXTURE_INSTALL=OFF
        -DCPP_LIBRARY_VERSION=1.0.0 -DCPP_LIBRARY_VERSION_checked=1.0.0
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "${name}: configure failed:\n${out}\n${err}")
    endif()
    execute_process(COMMAND "${CMAKE_COMMAND}" --build "${test_root}/${name}"
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if((ARG_BAD_PRIMARY OR ARG_BAD_LATE) AND NOT ARG_TESTING_OFF AND NOT ARG_NESTED)
        if(ARG_BAD_PRIMARY)
            set(broken_header dependent.hpp)
        else()
            set(broken_header late.hpp)
        endif()
        string(FIND "${out}\n${err}" "${broken_header}" found)
        if(result EQUAL 0 OR found LESS 0)
            message(FATAL_ERROR
                "${name}: normal build did not reject ${broken_header}:\n${out}\n${err}")
        endif()
    elseif(NOT result EQUAL 0)
        message(FATAL_ERROR "${name}: build failed:\n${out}\n${err}")
    elseif(NOT ARG_TESTING_OFF AND NOT ARG_NESTED AND
            NOT EXISTS "${project_binary}/generated include/fixture/generated.hpp")
        message(FATAL_ERROR "${name}: generated public header was not built")
    endif()
    message(STATUS "PASS ${name}")
endfunction()

run_case(broken_interface BAD_PRIMARY)
run_case(broken_compiled COMPILED BAD_LATE)
foreach(standard 17 20 23)
    run_case(interface_${standard} STANDARD "${standard}")
    run_case(compiled_${standard} COMPILED STANDARD "${standard}")
endforeach()
run_case(testing_off BAD_PRIMARY TESTING_OFF)
run_case(subproject COMPILED BAD_LATE NESTED)

file(REMOVE_RECURSE "${test_root}")
message(STATUS "All independent header compilation cases passed!")
