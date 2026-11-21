# SPDX-License-Identifier: BSL-1.0
#
# Run as: cmake -P tests/setup/test_timeouts.cmake

cmake_minimum_required(VERSION 3.24)

get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/test-timeouts-${test_id}")
set(source "${test_root}/source")
get_filename_component(cmake_directory "${CMAKE_COMMAND}" DIRECTORY)
find_program(ctest NAMES ctest HINTS "${cmake_directory}" REQUIRED)
file(MAKE_DIRECTORY "${source}/include/fixture" "${source}/src"
    "${source}/tests" "${source}/examples")
file(WRITE "${source}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
project(timed LANGUAGES CXX)
include(CTest)
include("${TOOLKIT_SOURCE}/tests/setup/fixtures/mock_doctest.cmake")
set(source_args)
if(COMPILED)
    set(source_args SOURCES library.cpp)
endif()
set(timeout_args)
if(DEFINED PROJECT_TIMEOUT)
    set(timeout_args TEST_TIMEOUT "${PROJECT_TIMEOUT}")
elseif(MISSING_TIMEOUT)
    set(timeout_args TEST_TIMEOUT)
endif()
cpp_library_setup(DESCRIPTION "Generated test timeouts" NAMESPACE fixture
    HEADERS api.hpp ${source_args}
    TESTS unit.cpp negative_fail.cpp
    EXAMPLES example.cpp example_fail.cpp ${timeout_args})
if(OVERRIDE_TEST)
    set_tests_properties(unit PROPERTIES TIMEOUT 300)
    if(COMPILED)
        set_tests_properties(timed_in_source_tests PROPERTIES TIMEOUT 300)
    endif()
endif()
add_test(NAME manual COMMAND "${CMAKE_COMMAND}" -E true)
set_tests_properties(manual PROPERTIES TIMEOUT 900)
if(SLOW_TESTS)
    target_compile_definitions(unit PRIVATE SLOW_TEST)
    set_property(TARGET negative_fail PROPERTY CXX_COMPILER_LAUNCHER
        "${CMAKE_COMMAND};-P;${CMAKE_CURRENT_SOURCE_DIR}/stall.cmake")
endif()
]=])
file(WRITE "${source}/include/fixture/api.hpp" "#pragma once\n")
file(WRITE "${source}/src/library.cpp" "int fixture_value() { return 42; }\n")
file(WRITE "${source}/tests/unit.cpp" [=[
#ifdef SLOW_TEST
#include <chrono>
#include <thread>
#endif
int main() {
#ifdef SLOW_TEST
    std::this_thread::sleep_for(std::chrono::seconds(30));
#endif
    return 0;
}
]=])
file(WRITE "${source}/tests/negative_fail.cpp" "#error Expected compile failure\n")
file(WRITE "${source}/examples/example.cpp" "int main() { return 0; }\n")
file(WRITE "${source}/examples/example_fail.cpp" "#error Expected compile failure\n")
file(WRITE "${source}/stall.cmake"
    "execute_process(COMMAND \"${CMAKE_COMMAND}\" -E sleep 30)\n")

# Runs a command successfully and returns its standard output.
function(run)
    execute_process(COMMAND ${ARGV} RESULT_VARIABLE result
        OUTPUT_VARIABLE output ERROR_VARIABLE error TIMEOUT 120)
    if(NOT result STREQUAL "0")
        message(FATAL_ERROR "${ARGV}\n${output}\n${error}\nResult: ${result}")
    endif()
    set(command_output "${output}" PARENT_SCOPE)
endfunction()

# Checks the effective timeout of every generated and manually registered test.
function(check_timeouts json timeout compiled overridden)
    set(expected unit compile_negative_fail example compile_example_fail manual)
    if(compiled)
        list(APPEND expected timed_in_source_tests)
    endif()
    string(JSON count LENGTH "${json}" tests)
    list(LENGTH expected expected_count)
    if(NOT count EQUAL expected_count)
        message(FATAL_ERROR "Expected ${expected_count} tests, got ${count}: ${json}")
    endif()
    math(EXPR last "${count} - 1")
    foreach(index RANGE ${last})
        string(JSON name GET "${json}" tests ${index} name)
        if(NOT name IN_LIST expected)
            message(FATAL_ERROR "Unexpected or duplicate test: ${name}")
        endif()
        list(REMOVE_ITEM expected "${name}")
        set(wanted "${timeout}")
        if(name STREQUAL "manual")
            set(wanted 900)
        elseif(overridden AND (name STREQUAL "unit" OR name STREQUAL "timed_in_source_tests"))
            set(wanted 300)
        endif()
        string(JSON properties GET "${json}" tests ${index} properties)
        string(JSON property_count LENGTH "${properties}")
        math(EXPR property_last "${property_count} - 1")
        set(found FALSE)
        if(property_count GREATER 0)
            foreach(property_index RANGE ${property_last})
                string(JSON property GET "${properties}" ${property_index} name)
                if(property STREQUAL "TIMEOUT")
                    string(JSON actual GET "${properties}" ${property_index} value)
                    if(NOT actual EQUAL wanted)
                        message(FATAL_ERROR "${name}: expected TIMEOUT ${wanted}, got ${actual}")
                    endif()
                    set(found TRUE)
                endif()
            endforeach()
        endif()
        if(NOT found)
            message(FATAL_ERROR "${name}: missing TIMEOUT (expected ${wanted})")
        endif()
    endforeach()
endfunction()

foreach(case default override header_only upper_bound slow)
    set(binary "${test_root}/${case}")
    set(options -DCOMPILED=ON)
    set(timeout 120)
    set(compiled TRUE)
    set(overridden FALSE)
    if(case STREQUAL "override")
        list(APPEND options -DPROJECT_TIMEOUT=7 -DOVERRIDE_TEST=ON)
        set(timeout 7)
        set(overridden TRUE)
    elseif(case STREQUAL "header_only")
        set(options -DCOMPILED=OFF -DPROJECT_TIMEOUT=7)
        set(timeout 7)
        set(compiled FALSE)
    elseif(case STREQUAL "upper_bound")
        list(APPEND options -DPROJECT_TIMEOUT=2147483647)
        set(timeout 2147483647)
    elseif(case STREQUAL "slow")
        list(APPEND options -DPROJECT_TIMEOUT=1 -DSLOW_TESTS=ON)
        set(timeout 1)
    endif()
    run("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" -DCPP_LIBRARY_VERSION=1.0.0
        -DFIXTURE_INSTALL=OFF -DBUILD_DOCS=OFF -DCMAKE_BUILD_TYPE=Debug ${options})
    run("${CMAKE_COMMAND}" --build "${binary}")
    run("${ctest}" --test-dir "${binary}" --show-only=json-v1)
    check_timeouts("${command_output}" "${timeout}" "${compiled}" "${overridden}")
    if(case STREQUAL "default")
        run("${CMAKE_COMMAND}" -E chdir "${source}"
            "${ctest}" --preset test --test-dir "${binary}" --show-only=json-v1)
        check_timeouts("${command_output}" 120 TRUE FALSE)
    endif()
    if(NOT case STREQUAL "slow")
        run("${ctest}" --test-dir "${binary}" --output-on-failure)
    else()
        foreach(test unit compile_negative_fail)
            execute_process(
                COMMAND "${ctest}" --test-dir "${binary}" -R "^${test}$" --output-on-failure
                RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE error TIMEOUT 15)
            if(NOT result STREQUAL "8" OR NOT "${output}\n${error}" MATCHES "Timeout")
                message(FATAL_ERROR "${test}: expected CTest timeout failure\n${output}\n${error}\n${result}")
            endif()
            message(STATUS "PASS ${test}: CTest terminates overlong test with TIMEOUT 1")
        endforeach()
    endif()
    message(STATUS "PASS ${case}: effective generated-test timeouts")
endforeach()

foreach(value 0 -1 0.5 invalid nan inf 2147483648 overflow missing)
    if(value STREQUAL "missing")
        set(option -DMISSING_TIMEOUT=ON)
    elseif(value STREQUAL "overflow")
        string(REPEAT "9" 400 oversized)
        set(option "-DPROJECT_TIMEOUT=${oversized}")
    else()
        set(option "-DPROJECT_TIMEOUT=${value}")
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${source}" -B "${test_root}/invalid-${value}" -G Ninja
            "-DTOOLKIT_SOURCE=${toolkit_source}" -DCPP_LIBRARY_VERSION=1.0.0
            -DFIXTURE_INSTALL=OFF -DBUILD_DOCS=OFF ${option}
        RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE error TIMEOUT 120)
    if(result STREQUAL "0" OR NOT "${output}\n${error}" MATCHES "TEST_TIMEOUT")
        message(FATAL_ERROR "Expected TEST_TIMEOUT diagnostic for '${value}'\n${output}\n${error}")
    endif()
    message(STATUS "PASS invalid TEST_TIMEOUT: ${value}")
endforeach()

message(STATUS "All generated-test timeout checks passed")
