# SPDX-License-Identifier: BSL-1.0
#
# cpp-library.cmake - Modern C++ Header-Only Library Template
# 
# This file provides common CMake infrastructure for stlab header-only libraries.
# Usage: include(cmake/cpp-library.cmake) then call cpp_library_setup(...)

# Determine the directory where this file is located
get_filename_component(CPP_LIBRARY_ROOT "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)

# Include all the component modules
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-setup.cmake")
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-testing.cmake")  
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-docs.cmake")
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-presets.cmake")

# Main entry point function - users call this to set up their library
function(cpp_library_setup)
    # Parse arguments
    set(options 
        CUSTOM_INSTALL          # Skip default installation
        NO_PRESETS             # Skip CMakePresets.json generation
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
    
    # Call component setup functions
    _cpp_library_setup_core(
        NAME "${ARG_NAME}"
        VERSION "${ARG_VERSION}" 
        DESCRIPTION "${ARG_DESCRIPTION}"
        NAMESPACE "${ARG_NAMESPACE}"
        HEADERS "${ARG_HEADERS}"
        HEADER_DIR "${ARG_HEADER_DIR}"
        REQUIRES_CPP_VERSION "${ARG_REQUIRES_CPP_VERSION}"
    )
    
    if(NOT ARG_NO_PRESETS AND PROJECT_IS_TOP_LEVEL)
        _cpp_library_generate_presets()
    endif()
    
    if(BUILD_TESTING AND PROJECT_IS_TOP_LEVEL AND ARG_TESTS)
        _cpp_library_setup_testing(
            NAME "${ARG_NAME}"
            NAMESPACE "${ARG_NAMESPACE}" 
            TESTS "${ARG_TESTS}"
        )
    endif()
    
    if(BUILD_DOCS AND PROJECT_IS_TOP_LEVEL)
        _cpp_library_setup_docs(
            NAME "${ARG_NAME}"
            VERSION "${ARG_VERSION}"
            DESCRIPTION "${ARG_DESCRIPTION}"
            DOCS_EXCLUDE_SYMBOLS "${ARG_DOCS_EXCLUDE_SYMBOLS}"
        )
    endif()
    
    # Build examples if specified
    if(PROJECT_IS_TOP_LEVEL AND ARG_EXAMPLES)
        foreach(example IN LISTS ARG_EXAMPLES)
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/example/${example}.cpp")
                add_executable(${example} "example/${example}.cpp")
                target_link_libraries(${example} PRIVATE ${ARG_NAMESPACE}::${ARG_NAME})
                
                # Add as test unless it's marked as EXCLUDE_FROM_ALL or expected to fail
                get_target_property(excluded ${example} EXCLUDE_FROM_ALL)
                if(NOT excluded)
                    add_test(NAME ${example} COMMAND ${example})
                endif()
            else()
                message(WARNING "Example file example/${example}.cpp not found")
            endif()
        endforeach()
    endif()
    
endfunction()
