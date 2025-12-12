# SPDX-License-Identifier: BSL-1.0
#
# Unit tests for cpp-library-install.cmake
#
# Run as: cmake -P tests/install/CMakeLists.txt

cmake_minimum_required(VERSION 3.20)

# Include the module we're testing
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/cpp-library-install.cmake)

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
    else()
        # For other properties, return NOTFOUND since we're only mocking INTERFACE_LINK_LIBRARIES
        set(${OUTPUT_VAR} "NOTFOUND" PARENT_SCOPE)
    endif()
endfunction()

# Helper macro to run a test
macro(run_test TEST_NAME)
    math(EXPR TEST_COUNT "${TEST_COUNT} + 1")
    message(STATUS "Running test ${TEST_COUNT}: ${TEST_NAME}")
    
    # Clear global state before each test
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_PKG_KEYS "")
    get_property(ALL_PKG_KEYS GLOBAL PROPERTY _CPP_LIBRARY_PKG_KEYS)
    foreach(prop IN LISTS ALL_PKG_KEYS)
        set_property(GLOBAL PROPERTY "_CPP_LIBRARY_PKG_COMPONENTS_${prop}")
    endforeach()
    
    # Clear all dependency mappings from previous tests
    get_property(ALL_MAPPED_TARGETS GLOBAL PROPERTY _CPP_LIBRARY_ALL_MAPPED_TARGETS)
    foreach(target IN LISTS ALL_MAPPED_TARGETS)
        set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEPENDENCY_MAP_${target})
    endforeach()
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_ALL_MAPPED_TARGETS "")
    
    # Clear dependency provider tracking state
    get_property(ALL_TRACKED_DEPS GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS)
    foreach(dep IN LISTS ALL_TRACKED_DEPS)
        set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_${dep}")
    endforeach()
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "")
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

