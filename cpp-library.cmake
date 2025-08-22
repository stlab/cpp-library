# SPDX-License-Identifier: BSL-1.0
#
# cpp-library.cmake - Modern C++ Header-Only Library Template
# 
# This file provides common CMake infrastructure for stlab header-only libraries.
# Usage: include(cmake/cpp-library.cmake) then call cpp_library_setup(...)

# Determine the directory where this file is located
get_filename_component(CPP_LIBRARY_ROOT "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)

# Include CTest for testing support
include(CTest)

# Include all the component modules
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-setup.cmake")
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-testing.cmake")  
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-docs.cmake")
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-presets.cmake")
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-ci.cmake")

# Main entry point function - users call this to set up their library
function(cpp_library_setup)
    # Parse arguments
    set(options 
        CUSTOM_INSTALL          # Skip default installation
        NO_PRESETS             # Skip CMakePresets.json generation
        NO_CI                  # Skip CI generation (CI enabled by default)
    )
    set(oneValueArgs
        NAME                    # Project name (e.g., "stlab-enum-ops")
        VERSION                 # Version string (e.g., "1.0.0") 
        DESCRIPTION             # Description string
        NAMESPACE               # Namespace (e.g., "stlab")
        REQUIRES_CPP_VERSION    # C++ version (default: 17)
        HEADER_DIR              # Directory to install recursively
    )
    set(multiValueArgs
        HEADERS                 # List of header files
        EXAMPLES               # Example executables to build
        TESTS                  # Test executables to build  
        DOCS_EXCLUDE_SYMBOLS   # Symbols to exclude from docs
        ADDITIONAL_DEPS        # Extra CPM dependencies
    )
    
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Validate required arguments
    if(NOT ARG_NAME)
        message(FATAL_ERROR "cpp_library_setup: NAME is required")
    endif()
    if(NOT ARG_VERSION)
        message(FATAL_ERROR "cpp_library_setup: VERSION is required")
    endif()
    if(NOT ARG_DESCRIPTION)
        message(FATAL_ERROR "cpp_library_setup: DESCRIPTION is required")
    endif()
    if(NOT ARG_NAMESPACE)
        message(FATAL_ERROR "cpp_library_setup: NAMESPACE is required")
    endif()
    if(NOT ARG_HEADERS AND NOT ARG_HEADER_DIR)
        message(FATAL_ERROR "cpp_library_setup: Either HEADERS or HEADER_DIR is required")
    endif()
    
    # Set defaults
    if(NOT ARG_REQUIRES_CPP_VERSION)
        set(ARG_REQUIRES_CPP_VERSION 17)
    endif()
    
    # Create the basic library target (always done)
    _cpp_library_setup_core(
        NAME "${ARG_NAME}"
        VERSION "${ARG_VERSION}" 
        DESCRIPTION "${ARG_DESCRIPTION}"
        NAMESPACE "${ARG_NAMESPACE}"
        HEADERS "${ARG_HEADERS}"
        HEADER_DIR "${ARG_HEADER_DIR}"
        REQUIRES_CPP_VERSION "${ARG_REQUIRES_CPP_VERSION}"
        TOP_LEVEL "${PROJECT_IS_TOP_LEVEL}"
    )
    
    # Only setup development infrastructure when building as top-level project
    if(NOT PROJECT_IS_TOP_LEVEL)
        return()  # Early return for lightweight consumer mode
    endif()
    
    # Generate CMakePresets.json (unless disabled)
    if(NOT ARG_NO_PRESETS)
        _cpp_library_generate_presets()
    endif()
    
    # Setup testing (if tests are specified)
    if(BUILD_TESTING AND ARG_TESTS)
        _cpp_library_setup_testing(
            NAME "${ARG_NAME}"
            NAMESPACE "${ARG_NAMESPACE}" 
            TESTS "${ARG_TESTS}"
        )
    endif()
    
    # Setup documentation (always for top-level)
    if(BUILD_DOCS)
        _cpp_library_setup_docs(
            NAME "${ARG_NAME}"
            VERSION "${ARG_VERSION}"
            DESCRIPTION "${ARG_DESCRIPTION}"
            DOCS_EXCLUDE_SYMBOLS "${ARG_DOCS_EXCLUDE_SYMBOLS}"
        )
    endif()
    
    # Setup CI (unless disabled)
    if(NOT ARG_NO_CI)
        _cpp_library_setup_ci(
            NAME "${ARG_NAME}"
            VERSION "${ARG_VERSION}"
            DESCRIPTION "${ARG_DESCRIPTION}"
        )
    endif()
    
    # Build examples if specified  
    if(ARG_EXAMPLES)
        foreach(example IN LISTS ARG_EXAMPLES)
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/examples/${example}.cpp")
                string(REPLACE "${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
                
                # Check if this is a compile-fail test (has "_fail" in the name)
                string(FIND "${example}" "_fail" fail_pos)
                if(fail_pos GREATER -1)
                    # Negative compile test: this example must fail to compile
                    add_executable(${example} EXCLUDE_FROM_ALL "examples/${example}.cpp")
                    target_link_libraries(${example} PRIVATE ${ARG_NAMESPACE}::${CLEAN_NAME})
                    add_test(
                        NAME compile_${example}
                        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target ${example}
                        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                    )
                    set_tests_properties(compile_${example} PROPERTIES WILL_FAIL TRUE)
                else()
                    # Regular example
                    add_executable(${example} "examples/${example}.cpp")
                    target_link_libraries(${example} PRIVATE ${ARG_NAMESPACE}::${CLEAN_NAME})
                    add_test(NAME ${example} COMMAND ${example})
                endif()
            else()
                message(WARNING "Example file examples/${example}.cpp not found")
            endif()
        endforeach()
    endif()
    
endfunction()
