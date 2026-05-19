# SPDX-License-Identifier: BSL-1.0
#
# Integration test for setup.cmake version detection when run standalone
#
# Run as: cmake -P tests/setup/test_setup_version_resolution.cmake

cmake_minimum_required(VERSION 3.20)

set(TEST_ROOT_DIR "/tmp/cpp-library-setup-version-test")
set(TEST_PROJECT_NAME "setup-version-test-lib")

file(REMOVE_RECURSE "${TEST_ROOT_DIR}")
file(MAKE_DIRECTORY "${TEST_ROOT_DIR}")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/../../setup.cmake" DESTINATION "${TEST_ROOT_DIR}")

execute_process(
    COMMAND ${CMAKE_COMMAND} -P setup.cmake -- --name=${TEST_PROJECT_NAME} --namespace=testns --description=test --header-only=yes --examples=no --tests=no
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

if(NOT GENERATED_CONTENT MATCHES "CPMAddPackage\\(\"gh:stlab/cpp-library@([0-9]+\\.[0-9]+\\.[0-9]+|main)\"\\)")
    message(FATAL_ERROR "setup.cmake generated invalid cpp-library version reference in CPMAddPackage.")
endif()

message(STATUS "✓ setup.cmake generated a valid cpp-library version reference")
