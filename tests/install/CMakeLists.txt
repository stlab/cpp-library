# SPDX-License-Identifier: BSL-1.0
#
# Unit tests for cpp-library-install.cmake
#
# Run as: cmake -P tests/install/CMakeLists.txt

cmake_minimum_required(VERSION 3.20)
set(PROJECT_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}")

# Include the modules we're testing
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/cpp-library-install.cmake)

# Include dependency provider functions in test mode
# This loads the function definitions without installing the provider
set(CPP_LIBRARY_TEST_MODE TRUE)
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/cpp-library-dependency-provider.cmake)

# Test counter
set(TEST_COUNT 0)
set(TEST_PASSED 0)
set(TEST_FAILED 0)

# Mock get_target_property to return pre-defined link libraries
# This allows us to test without creating actual targets
function(get_target_property OUTPUT_VAR TARGET PROPERTY)
    if(PROPERTY STREQUAL "INTERFACE_LINK_LIBRARIES")
        if(DEFINED MOCK_LINK_LIBS_${TARGET})
            set(${OUTPUT_VAR} "${MOCK_LINK_LIBS_${TARGET}}" PARENT_SCOPE)
        else()
            set(${OUTPUT_VAR} "NOTFOUND" PARENT_SCOPE)
        endif()
    elseif(PROPERTY STREQUAL "BINARY_DIR")
        set(${OUTPUT_VAR} "${CMAKE_CURRENT_BINARY_DIR}" PARENT_SCOPE)
    else()
        set(${OUTPUT_VAR} "NOTFOUND" PARENT_SCOPE)
    endif()
endfunction()

# Supplies the owning project for mock targets without configured directories.
function(get_directory_property OUTPUT_VAR DIRECTORY_KEYWORD DIRECTORY_PATH DEFINITION_KEYWORD VARIABLE)
    if(NOT DIRECTORY_KEYWORD STREQUAL "DIRECTORY"
            OR NOT DIRECTORY_PATH STREQUAL CMAKE_CURRENT_BINARY_DIR
            OR NOT DEFINITION_KEYWORD STREQUAL "DEFINITION"
            OR NOT VARIABLE STREQUAL "PROJECT_BINARY_DIR")
        message(FATAL_ERROR "Unexpected mock directory lookup: ${ARGN}")
    endif()
    set(${OUTPUT_VAR} "${PROJECT_BINARY_DIR}" PARENT_SCOPE)
endfunction()

# Helper macro to run a test
macro(run_test TEST_NAME)
    math(EXPR TEST_COUNT "${TEST_COUNT} + 1")
    message(STATUS "Running test ${TEST_COUNT}: ${TEST_NAME}")
    
    # Clear global state before each test
    get_property(ALL_PKG_KEYS GLOBAL PROPERTY _CPP_LIBRARY_PKG_KEYS)
    foreach(prop IN LISTS ALL_PKG_KEYS)
        set_property(GLOBAL PROPERTY "_CPP_LIBRARY_PKG_COMPONENTS_${prop}")
    endforeach()
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_PKG_KEYS "")
    
    # Clear all dependency mappings from previous tests
    get_property(ALL_MAPPING_PROPERTIES GLOBAL PROPERTY _CPP_LIBRARY_ALL_MAPPING_PROPERTIES)
    foreach(property IN LISTS ALL_MAPPING_PROPERTIES)
        set_property(GLOBAL PROPERTY "${property}")
    endforeach()
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_ALL_MAPPING_PROPERTIES "")
    
    # Clear dependency provider tracking state
    get_property(ALL_TRACKED_DEPS GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS)
    foreach(dep IN LISTS ALL_TRACKED_DEPS)
        set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_${dep}")
    endforeach()
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "")

    # Clear the CPM package registry
    set(CPM_PACKAGES "")
endmacro()

# Helper macro to set up mock link libraries for a test target
macro(mock_target_links TARGET)
    set(MOCK_LINK_LIBS_${TARGET} "${ARGN}")
endmacro()

# Helper macro to verify expected output (using macro instead of function for scope)
macro(verify_output ACTUAL EXPECTED TEST_NAME)
    if("${ACTUAL}" STREQUAL "${EXPECTED}")
        message(STATUS "  ✓ PASS: ${TEST_NAME}")
        math(EXPR TEST_PASSED "${TEST_PASSED} + 1")
    else()
        message(STATUS "  ✗ FAIL: ${TEST_NAME}")
        message(STATUS "    Expected:")
        message(STATUS "      ${EXPECTED}")
        message(STATUS "    Actual:")
        message(STATUS "      ${ACTUAL}")
        math(EXPR TEST_FAILED "${TEST_FAILED} + 1")
    endif()
endmacro()

# Include the actual tests
include(${CMAKE_CURRENT_LIST_DIR}/test_dependency_mapping.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/test_dependency_provider.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/test_cpm_registry.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/test_mapping_scope.cmake)

# Print summary
message(STATUS "")
message(STATUS "=====================================")
message(STATUS "Test Summary:")
message(STATUS "  Total:  ${TEST_COUNT}")
message(STATUS "  Passed: ${TEST_PASSED}")
message(STATUS "  Failed: ${TEST_FAILED}")
message(STATUS "=====================================")

if(TEST_FAILED GREATER 0)
    message(FATAL_ERROR "Some tests failed!")
endif()

