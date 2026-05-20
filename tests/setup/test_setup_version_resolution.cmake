# SPDX-License-Identifier: BSL-1.0
#
# Integration test for setup.cmake version detection when run standalone
#
# Run as: cmake -P tests/setup/test_setup_version_resolution.cmake

cmake_minimum_required(VERSION 3.20)

# Must match setup.cmake CPM shorthand rules
function(_assert_cpp_library_cpm_spec VERSION EXPECTED)
    if(VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
        set(ACTUAL "gh:stlab/cpp-library@${VERSION}")
    else()
        set(ACTUAL "gh:stlab/cpp-library#${VERSION}")
    endif()
    if(NOT ACTUAL STREQUAL "${EXPECTED}")
        message(FATAL_ERROR "CPM spec for '${VERSION}': expected '${EXPECTED}', got '${ACTUAL}'")
    endif()
endfunction()

_assert_cpp_library_cpm_spec("5.1.1" "gh:stlab/cpp-library@5.1.1")
_assert_cpp_library_cpm_spec("main" "gh:stlab/cpp-library#main")

# Must match setup.cmake release-tag pattern (no substring match on pre-release refs)
set(_RELEASE_TAG_PATTERN "refs/tags/v[0-9]+\\.[0-9]+\\.[0-9]+([^0-9.\\-]|$)")
string(REGEX MATCHALL "${_RELEASE_TAG_PATTERN}" _PRERELEASE_MATCHES "deadbeef\trefs/tags/v2.0.0-rc1\n")
if(_PRERELEASE_MATCHES)
    message(FATAL_ERROR "Pre-release tag must not match release pattern; got: ${_PRERELEASE_MATCHES}")
endif()
string(REGEX MATCHALL "${_RELEASE_TAG_PATTERN}" _RELEASE_MATCHES "deadbeef\trefs/tags/v5.1.1\n")
if(NOT _RELEASE_MATCHES)
    message(FATAL_ERROR "Release tag v5.1.1 should match release pattern")
endif()

if(DEFINED ENV{TMPDIR} AND NOT "$ENV{TMPDIR}" STREQUAL "")
    set(TEST_BASE_DIR "$ENV{TMPDIR}")
elseif(DEFINED ENV{TEMP} AND NOT "$ENV{TEMP}" STREQUAL "")
    set(TEST_BASE_DIR "$ENV{TEMP}")
elseif(DEFINED ENV{TMP} AND NOT "$ENV{TMP}" STREQUAL "")
    set(TEST_BASE_DIR "$ENV{TMP}")
else()
    set(TEST_BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
endif()

set(TEST_ROOT_DIR "${TEST_BASE_DIR}/cpp-library-setup-version-test")
set(TEST_PROJECT_NAME "setup-version-test-lib")

file(REMOVE_RECURSE "${TEST_ROOT_DIR}")
file(MAKE_DIRECTORY "${TEST_ROOT_DIR}")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/../../setup.cmake" DESTINATION "${TEST_ROOT_DIR}")

execute_process(
    COMMAND
        ${CMAKE_COMMAND}
        -P
        setup.cmake
        --
        --name=${TEST_PROJECT_NAME}
        --namespace=testns
        --description=test
        --header-only=yes
        --examples=no
        --tests=no
    WORKING_DIRECTORY "${TEST_ROOT_DIR}"
    RESULT_VARIABLE SETUP_RESULT
    OUTPUT_VARIABLE SETUP_OUTPUT
    ERROR_VARIABLE SETUP_ERROR
)

if(NOT SETUP_RESULT EQUAL 0)
    message(FATAL_ERROR "setup.cmake failed with exit code ${SETUP_RESULT}\nstdout:\n${SETUP_OUTPUT}\nstderr:\n${SETUP_ERROR}")
endif()

set(GENERATED_CMAKE_LISTS "${TEST_ROOT_DIR}/${TEST_PROJECT_NAME}/CMakeLists.txt")
if(NOT EXISTS "${GENERATED_CMAKE_LISTS}")
    message(FATAL_ERROR "Generated CMakeLists.txt not found: ${GENERATED_CMAKE_LISTS}")
endif()

file(READ "${GENERATED_CMAKE_LISTS}" GENERATED_CONTENT)

if(GENERATED_CONTENT MATCHES "CPMAddPackage\\(\"gh:stlab/cpp-library@X\\.Y\\.Z\"\\)")
    message(FATAL_ERROR "setup.cmake generated placeholder version X.Y.Z, which should never be emitted.")
endif()

if(GENERATED_CONTENT MATCHES "CPMAddPackage\\(\"gh:stlab/cpp-library@main\"\\)")
    message(FATAL_ERROR "setup.cmake used @main for branch fallback; CPM maps @ to VERSION and defaults GIT_TAG to v\${VERSION} (vmain). Use #main for branches.")
endif()

set(VALID_CPM_REF FALSE)
if(GENERATED_CONTENT MATCHES "CPMAddPackage\\(\"gh:stlab/cpp-library@([0-9]+\\.[0-9]+\\.[0-9]+)\"\\)")
    set(VALID_CPM_REF TRUE)
endif()
if(GENERATED_CONTENT MATCHES "CPMAddPackage\\(\"gh:stlab/cpp-library#main\"\\)")
    set(VALID_CPM_REF TRUE)
endif()
if(NOT VALID_CPM_REF)
    message(FATAL_ERROR "setup.cmake generated invalid cpp-library version reference in CPMAddPackage (expected @X.Y.Z release or #main branch).")
endif()

message(STATUS "✓ setup.cmake generated a valid cpp-library version reference")

file(REMOVE_RECURSE "${TEST_ROOT_DIR}")
