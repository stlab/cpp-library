# SPDX-License-Identifier: BSL-1.0
#
# Run as: cmake -P tests/setup/test_version_override.cmake

cmake_minimum_required(VERSION 3.24)

get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/version-override-${test_id}")
set(source "${test_root}/source")
file(MAKE_DIRECTORY "${source}")

# Runs fixture setup commands and reports their diagnostics on failure.
function(run_command)
    execute_process(COMMAND ${ARGV}
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Command failed (${result}): ${ARGV}\n${out}\n${err}")
    endif()
endfunction()

file(WRITE "${source}/assert-version.cmake" [=[
# Checks the current project's published version and its numeric components.
function(assert_project_version)
    set(expected "${EXPECTED_${PROJECT_NAME}}")
    if(NOT PROJECT_VERSION STREQUAL expected)
        message(FATAL_ERROR "${PROJECT_NAME}: expected ${expected}, got '${PROJECT_VERSION}'")
    endif()
    set(components "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")
    if(NOT components STREQUAL expected)
        message(FATAL_ERROR "${PROJECT_NAME}: wrong version components '${components}'")
    endif()
endfunction()
]=])

set(project_template [=[
cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    cpp_library_enable_dependency_tracking()
endif()
project(@project_name@ LANGUAGES CXX)
include("${CMAKE_SOURCE_DIR}/assert-version.cmake")
cpp_library_set_version()
assert_project_version()
set(source_args)
if(PROJECT_NAME STREQUAL "child-version")
    set(source_args SOURCES version.cpp)
endif()
cpp_library_setup(DESCRIPTION "Version isolation fixture" NAMESPACE fixture
    HEADERS version.hpp ${source_args})
assert_project_version()
add_subdirectory(helper)
]=])

foreach(project_name parent-version child-version sibling-version)
    if(project_name STREQUAL "parent-version")
        set(project_source "${source}")
        set(tag v0.8.0)
    elseif(project_name STREQUAL "child-version")
        set(project_source "${source}/child")
        set(tag v1.1.0)
    else()
        set(project_source "${source}/sibling")
        set(tag v2.3.4)
    endif()
    file(MAKE_DIRECTORY "${project_source}/include/fixture" "${project_source}/src"
        "${project_source}/helper")
    file(WRITE "${project_source}/include/fixture/version.hpp" "#pragma once\n")
    file(WRITE "${project_source}/src/version.cpp" "int version_fixture() { return 0; }\n")
    string(CONFIGURE "${project_template}" project_contents @ONLY)
    file(WRITE "${project_source}/CMakeLists.txt" "${project_contents}")
    file(WRITE "${project_source}/helper/CMakeLists.txt" [=[
cpp_library_set_version()
assert_project_version()
]=])
    run_command(git -C "${project_source}" init --quiet)
    run_command(git -C "${project_source}" -c user.name=cpp-library
        -c user.email=cpp-library@example.invalid -c commit.gpgsign=false
        -c "core.hooksPath=${test_root}/no-hooks"
        commit --allow-empty --quiet -m "Version fixture"
        -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>")
    run_command(git -C "${project_source}" -c tag.gpgSign=false tag "${tag}")
endforeach()
file(APPEND "${source}/CMakeLists.txt" [=[
add_subdirectory(child)
add_subdirectory(sibling)
assert_project_version()
]=])

# Checks a generated version file without installing or consuming the package.
function(check_config_version path expected)
    include("${path}")
    if(NOT PACKAGE_VERSION STREQUAL expected)
        message(FATAL_ERROR "${path}: expected ${expected}, got '${PACKAGE_VERSION}'")
    endif()
endfunction()

set(failed_cases)

# Configures independent projects and checks their generated package versions.
function(run_case name parent_version child_version sibling_version)
    set(binary "${test_root}/${name}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}"
        "-DEXPECTED_parent-version=${parent_version}"
        "-DEXPECTED_child-version=${child_version}"
        "-DEXPECTED_sibling-version=${sibling_version}"
        -DBUILD_TESTING=OFF -DBUILD_DOCS=OFF -DFIXTURE_INSTALL=ON ${ARGN}
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(STATUS "FAIL ${name}:\n${out}\n${err}")
        list(APPEND failed_cases "${name}")
    else()
        check_config_version("${binary}/fixture-parent-versionConfigVersion.cmake" "${parent_version}")
        check_config_version("${binary}/child/fixture-child-versionConfigVersion.cmake" "${child_version}")
        check_config_version("${binary}/sibling/fixture-sibling-versionConfigVersion.cmake" "${sibling_version}")
        message(STATUS "PASS ${name}: ${parent_version}; ${child_version}; ${sibling_version}")
    endif()
    set(failed_cases "${failed_cases}" PARENT_SCOPE)
endfunction()

run_case(git_tags 0.8.0 1.1.0 2.3.4)
run_case(legacy_top_level_only 0.1.0 1.1.0 2.3.4 -DCPP_LIBRARY_VERSION=0.1.0)
run_case(scoped_overrides 0.2.0 1.5.0 2.3.4
    -DCPP_LIBRARY_VERSION_parent-version=0.2.0 -DCPP_LIBRARY_VERSION_child-version=1.5.0)
run_case(scoped_precedence 0.3.0 1.6.0 2.3.4 -DCPP_LIBRARY_VERSION=0.1.0
    -DCPP_LIBRARY_VERSION_parent-version=0.3.0 -DCPP_LIBRARY_VERSION_child-version=1.6.0)
run_case(empty_scoped_fallback 0.1.0 1.1.0 2.3.4 -DCPP_LIBRARY_VERSION=0.1.0
    -DCPP_LIBRARY_VERSION_parent-version= -DCPP_LIBRARY_VERSION_child-version=)
run_case(case_sensitive_names 0.8.0 1.1.0 2.3.4
    -DCPP_LIBRARY_VERSION_PARENT-VERSION=9.9.9 -DCPP_LIBRARY_VERSION_CHILD-VERSION=9.9.9)

file(REMOVE_RECURSE "${test_root}")
if(failed_cases)
    message(FATAL_ERROR "Version override cases failed: ${failed_cases}")
endif()
message(STATUS "All project version override cases passed!")
