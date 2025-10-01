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

# Shared function to handle examples and tests consistently
function(_cpp_library_setup_executables)
    set(oneValueArgs
        NAME
        NAMESPACE
        TYPE
    )
    set(multiValueArgs
        EXECUTABLES
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Extract the clean library name for linking
    string(REPLACE "${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
    
    # Download doctest dependency via CPM
    if(NOT TARGET doctest::doctest)
        # https://github.com/doctest/doctest
        CPMAddPackage("gh:doctest/doctest@2.4.12")
    endif()
    
    # Determine source directory based on type
    if(ARG_TYPE STREQUAL "examples")
        set(source_dir "examples")
    elseif(ARG_TYPE STREQUAL "tests")
        set(source_dir "tests")
    else()
        message(FATAL_ERROR "_cpp_library_setup_executables: TYPE must be 'examples' or 'tests'")
    endif()
    
    # Add executables
    foreach(executable IN LISTS ARG_EXECUTABLES)
        # Extract the base name without extension for target naming
        get_filename_component(executable_base "${executable}" NAME_WE)
        
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${source_dir}/${executable}")
            
            # Check if this is a compile-fail test (has "_fail" in the name)
            string(FIND "${executable_base}" "_fail" fail_pos)
            if(fail_pos GREATER -1)
                # Negative compile test: this executable must fail to compile
                add_executable(${executable_base} EXCLUDE_FROM_ALL "${source_dir}/${executable}")
                target_link_libraries(${executable_base} PRIVATE ${ARG_NAMESPACE}::${CLEAN_NAME})
                add_test(
                    NAME compile_${executable_base}
                    COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target ${executable_base}
                    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                )
                set_tests_properties(compile_${executable_base} PROPERTIES WILL_FAIL TRUE)
            else()
                # Regular executable - conditionally build based on preset
                add_executable(${executable_base} "${source_dir}/${executable}")
                target_link_libraries(${executable_base} PRIVATE ${ARG_NAMESPACE}::${CLEAN_NAME} doctest::doctest)
                
                # Only fully build (compile and link) in test preset
                # In clang-tidy preset, compile with clang-tidy but don't link
                if(CMAKE_CXX_CLANG_TIDY)
                    # In clang-tidy mode, exclude from all builds but still compile
                    set_target_properties(${executable_base} PROPERTIES EXCLUDE_FROM_ALL TRUE)
                    # Don't add as a test in clang-tidy mode since we're not linking
                else()
                    # In test mode, build normally and add as test
                    add_test(NAME ${executable_base} COMMAND ${executable_base})
                    
                    # Set test properties for better IDE integration (only for tests)
                    if(ARG_TYPE STREQUAL "tests")
                        set_tests_properties(${executable_base} PROPERTIES
                            LABELS "doctest"
                            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                        )
                    endif()
                endif()
            endif()
        else()
            message(WARNING "${ARG_TYPE} file ${source_dir}/${executable} not found")
        endif()
    endforeach()
    
endfunction()

# Main entry point function - users call this to set up their library
function(cpp_library_setup)
    # Parse arguments
    set(oneValueArgs
        DESCRIPTION             # Description string
        NAMESPACE               # Namespace (e.g., "stlab")
        REQUIRES_CPP_VERSION    # C++ version (default: 17)
    )
    set(multiValueArgs
        HEADERS                 # List of header filenames (e.g., "your_header.hpp")
        SOURCES                 # List of source filenames (e.g., "your_library.cpp")
        EXAMPLES                # Example source files to build (e.g., "example.cpp example_fail.cpp")
        TESTS                   # Test source files to build (e.g., "tests.cpp")
        DOCS_EXCLUDE_SYMBOLS    # Symbols to exclude from docs
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate required arguments
    if(NOT ARG_DESCRIPTION)
        message(FATAL_ERROR "cpp_library_setup: DESCRIPTION is required")
    endif()
    if(NOT ARG_NAMESPACE)
        message(FATAL_ERROR "cpp_library_setup: NAMESPACE is required")
    endif()
    if(NOT ARG_HEADERS)
        message(FATAL_ERROR "cpp_library_setup: HEADERS is required")
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
    
    # Get version from git tags
    _cpp_library_get_git_version(GIT_VERSION)
    set(ARG_VERSION "${GIT_VERSION}")
    
    # Parse version components
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
    
    # Update project version
    set(PROJECT_VERSION ${ARG_VERSION} PARENT_SCOPE)
    set(PROJECT_VERSION_MAJOR ${ARG_VERSION_MAJOR} PARENT_SCOPE)
    set(PROJECT_VERSION_MINOR ${ARG_VERSION_MINOR} PARENT_SCOPE)
    set(PROJECT_VERSION_PATCH ${ARG_VERSION_PATCH} PARENT_SCOPE)
    
    # Generate full paths for HEADERS and SOURCES based on conventions
    set(GENERATED_HEADERS "")
    foreach(header IN LISTS ARG_HEADERS)
        list(APPEND GENERATED_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/include/${ARG_NAMESPACE}/${header}")
    endforeach()
    
    set(GENERATED_SOURCES "")
    foreach(source IN LISTS ARG_SOURCES)
        list(APPEND GENERATED_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/${source}")
    endforeach()
    
    # Create the basic library target (always done)
    _cpp_library_setup_core(
        NAME "${ARG_NAME}"
        VERSION "${ARG_VERSION}" 
        DESCRIPTION "${ARG_DESCRIPTION}"
        NAMESPACE "${ARG_NAMESPACE}"
        HEADERS "${GENERATED_HEADERS}"
        SOURCES "${GENERATED_SOURCES}"
        REQUIRES_CPP_VERSION "${ARG_REQUIRES_CPP_VERSION}"
        TOP_LEVEL "${PROJECT_IS_TOP_LEVEL}"
    )
    
    # Only setup development infrastructure when building as top-level project
    if(NOT PROJECT_IS_TOP_LEVEL)
        return()  # Early return for lightweight consumer mode
    endif()
    
    # Create symlink to compile_commands.json for clangd (only when BUILD_TESTING is enabled)
    if(CMAKE_EXPORT_COMPILE_COMMANDS AND BUILD_TESTING)
        add_custom_target(clangd_compile_commands ALL
            COMMAND ${CMAKE_COMMAND} -E create_symlink 
                ${CMAKE_BINARY_DIR}/compile_commands.json
                ${CMAKE_SOURCE_DIR}/compile_commands.json
            COMMENT "Creating symlink to compile_commands.json for clangd"
        )
    endif()
    
    # Copy static template files (like .clang-format, .gitignore, CMakePresets.json, etc.)
    if(DEFINED CPP_LIBRARY_FORCE_INIT AND CPP_LIBRARY_FORCE_INIT)
        _cpp_library_copy_templates(FORCE_INIT)
    else()
        _cpp_library_copy_templates()
    endif()
    
    # Setup testing (if tests are specified)
    if(BUILD_TESTING AND ARG_TESTS)
        _cpp_library_setup_executables(
            NAME "${ARG_NAME}"
            NAMESPACE "${ARG_NAMESPACE}" 
            TYPE "tests"
            EXECUTABLES "${ARG_TESTS}"
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
    

    
    # Build examples if specified (only when BUILD_TESTING is enabled)
    if(BUILD_TESTING AND ARG_EXAMPLES)
        _cpp_library_setup_executables(
            NAME "${ARG_NAME}"
            NAMESPACE "${ARG_NAMESPACE}" 
            TYPE "examples"
            EXECUTABLES "${ARG_EXAMPLES}"
        )
    endif()
    
endfunction()
