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
        FORCE_INIT             # Force regeneration of template files
    )
    set(oneValueArgs
        VERSION                 # Version string (e.g., "1.0.0") 
        DESCRIPTION             # Description string
        NAMESPACE               # Namespace (e.g., "stlab")
        REQUIRES_CPP_VERSION    # C++ version (default: 17)
        HEADER_DIR              # Directory to install recursively
    )
    set(multiValueArgs
        HEADERS                 # List of header files
        SOURCES                 # List of source files (optional, for non-header-only)
        EXAMPLES                # Example executables to build
        TESTS                   # Test executables to build  
        DOCS_EXCLUDE_SYMBOLS    # Symbols to exclude from docs
        ADDITIONAL_DEPS         # Extra CPM dependencies
    )
    
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Detect sources in <root>/src if SOURCES not provided
    if(NOT ARG_SOURCES)
        file(GLOB_RECURSE DETECTED_SOURCES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "src/*.cpp" "src/*.c" "src/*.cc" "src/*.cxx")
        if(DETECTED_SOURCES)
            set(ARG_SOURCES ${DETECTED_SOURCES})
        endif()
    endif()
    
    # Validate required arguments
    if(NOT ARG_DESCRIPTION)
        message(FATAL_ERROR "cpp_library_setup: DESCRIPTION is required")
    endif()
    if(NOT ARG_NAMESPACE)
        message(FATAL_ERROR "cpp_library_setup: NAMESPACE is required")
    endif()
    if(NOT ARG_HEADERS AND NOT ARG_HEADER_DIR)
        message(FATAL_ERROR "cpp_library_setup: Either HEADERS or HEADER_DIR is required")
    endif()
    
    # Use PROJECT_NAME as the library name
    if(NOT DEFINED PROJECT_NAME)
        message(FATAL_ERROR "cpp_library_setup: PROJECT_NAME must be defined. Call project() before cpp_library_setup()")
    endif()
    set(ARG_NAME "${PROJECT_NAME}")
    
    # Set defaults
    if(NOT ARG_REQUIRES_CPP_VERSION)
        set(ARG_REQUIRES_CPP_VERSION 17)
    endif()
    
    # Check for global FORCE_INIT option (can be set via -DCPP_LIBRARY_FORCE_INIT=ON)
    if(CPP_LIBRARY_FORCE_INIT)
        set(ARG_FORCE_INIT TRUE)
    endif()
    
    # Get version from git tags if not provided
    if(NOT ARG_VERSION)
        _cpp_library_get_git_version(GIT_VERSION)
        set(ARG_VERSION "${GIT_VERSION}")
    endif()
    
    # Parse version components for manual setting
    string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" VERSION_MATCH "${ARG_VERSION}")
    if(VERSION_MATCH)
        set(ARG_VERSION_MAJOR ${CMAKE_MATCH_1})
        set(ARG_VERSION_MINOR ${CMAKE_MATCH_2})
        set(ARG_VERSION_PATCH ${CMAKE_MATCH_3})
    else()
        set(ARG_VERSION_MAJOR 0)
        set(ARG_VERSION_MINOR 0)
        set(ARG_VERSION_PATCH 0)
    endif()
    
    # Update project version if it was detected from git
    if(NOT DEFINED PROJECT_VERSION OR PROJECT_VERSION STREQUAL "")
        set(PROJECT_VERSION ${ARG_VERSION} PARENT_SCOPE)
        set(PROJECT_VERSION_MAJOR ${ARG_VERSION_MAJOR} PARENT_SCOPE)
        set(PROJECT_VERSION_MINOR ${ARG_VERSION_MINOR} PARENT_SCOPE)
        set(PROJECT_VERSION_PATCH ${ARG_VERSION_PATCH} PARENT_SCOPE)
    endif()
    
    # Create the basic library target (always done)
    _cpp_library_setup_core(
        NAME "${ARG_NAME}"
        VERSION "${ARG_VERSION}" 
        DESCRIPTION "${ARG_DESCRIPTION}"
        NAMESPACE "${ARG_NAMESPACE}"
        HEADERS "${ARG_HEADERS}"
        SOURCES "${ARG_SOURCES}"
        HEADER_DIR "${ARG_HEADER_DIR}"
        REQUIRES_CPP_VERSION "${ARG_REQUIRES_CPP_VERSION}"
        TOP_LEVEL "${PROJECT_IS_TOP_LEVEL}"
    )
    
    # Only setup development infrastructure when building as top-level project
    if(NOT PROJECT_IS_TOP_LEVEL)
        return()  # Early return for lightweight consumer mode
    endif()
    
    # Create symlink to compile_commands.json for clangd
    if(CMAKE_EXPORT_COMPILE_COMMANDS)
        add_custom_target(clangd_compile_commands ALL
            COMMAND ${CMAKE_COMMAND} -E create_symlink 
                ${CMAKE_BINARY_DIR}/compile_commands.json
                ${CMAKE_SOURCE_DIR}/compile_commands.json
            COMMENT "Creating symlink to compile_commands.json for clangd"
        )
    endif()
    
    # Generate CMakePresets.json (unless disabled)
    if(NOT ARG_NO_PRESETS)
        _cpp_library_generate_presets(FORCE_INIT ${ARG_FORCE_INIT})
    endif()

    # Copy static template files (like .clang-format, .gitignore, etc.)
    _cpp_library_copy_templates(FORCE_INIT ${ARG_FORCE_INIT})
    
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
            FORCE_INIT ${ARG_FORCE_INIT}
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
