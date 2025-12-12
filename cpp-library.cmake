# SPDX-License-Identifier: BSL-1.0
#
# cpp-library.cmake - Modern C++ Library Template
# 
# This file provides common CMake infrastructure for C++ libraries (header-only and compiled).
# Usage: include(cmake/cpp-library.cmake) then call cpp_library_setup(...)

# Determine the directory where this file is located
get_filename_component(CPP_LIBRARY_ROOT "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)

# Enable dependency tracking for accurate find_dependency() generation
# This function should be called BEFORE project() to install the dependency provider.
# Requires CMake 3.24+.
#
# Usage:
#   cmake_minimum_required(VERSION 3.24)
#   include(cmake/CPM.cmake)
#   CPMAddPackage("gh:stlab/cpp-library@5.0.0")
#   include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)
#   
#   cpp_library_enable_dependency_tracking()  # Must be before project()
#   
#   project(my-library)
#   # Now all find_package/CPM calls are tracked
function(cpp_library_enable_dependency_tracking)
    # Add the dependency provider to CMAKE_PROJECT_TOP_LEVEL_INCLUDES
    # This will be processed during the next project() call
    list(APPEND CMAKE_PROJECT_TOP_LEVEL_INCLUDES 
        "${CPP_LIBRARY_ROOT}/cmake/cpp-library-dependency-provider.cmake")
    
    # Propagate to parent scope so project() sees it
    set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES "${CMAKE_PROJECT_TOP_LEVEL_INCLUDES}" PARENT_SCOPE)
    
    message(STATUS "cpp-library: Dependency tracking will be enabled during project() call")
endfunction()

# Include all the component modules
# Note: CTest is NOT included here because it requires project() to be called first.
# It will be included in cpp_library_setup() which is called after project().
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-setup.cmake")
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-testing.cmake")  
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-docs.cmake")
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-install.cmake")
include("${CPP_LIBRARY_ROOT}/cmake/cpp-library-ci.cmake")

# Creates test or example executables and registers them with CTest.
# - Precondition: doctest target available via CPM, source files exist in TYPE directory
# - Postcondition: executables created and added as tests (unless in clang-tidy mode)
# - Executables with "_fail" suffix are added as negative compilation tests
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
    
    # Extract the clean library name for linking (strip namespace prefix if present)
    string(REGEX REPLACE "^${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
    
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

# Sets up a C++ header-only or compiled library with testing, docs, and install support.
# - Precondition: PROJECT_NAME defined via project(), at least one HEADERS specified
# - Postcondition: library target created, version set from git tags, optional tests/docs/examples configured
# - When PROJECT_IS_TOP_LEVEL: also configures templates, testing, docs, and installation
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
    
    # Include CTest for testing support (must be after project())
    include(CTest)
    
    # Calculate clean name (without namespace prefix) for target alias
    # If PROJECT_NAME starts with NAMESPACE-, strip it; otherwise use PROJECT_NAME as-is
    string(REGEX REPLACE "^${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
    
    # Always prefix package name with namespace for collision prevention
    # Special case: if namespace equals clean name, don't duplicate (e.g., stlab::stlab → stlab)
    if(ARG_NAMESPACE STREQUAL CLEAN_NAME)
        set(PACKAGE_NAME "${ARG_NAMESPACE}")
    else()
        set(PACKAGE_NAME "${ARG_NAMESPACE}-${CLEAN_NAME}")
    endif()
    
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
        PACKAGE_NAME "${PACKAGE_NAME}"
        CLEAN_NAME "${CLEAN_NAME}"
        HEADERS "${GENERATED_HEADERS}"
        SOURCES "${GENERATED_SOURCES}"
        REQUIRES_CPP_VERSION "${ARG_REQUIRES_CPP_VERSION}"
        TOP_LEVEL "${PROJECT_IS_TOP_LEVEL}"
    )
    
    # Only setup development infrastructure when building as top-level project
    if(NOT PROJECT_IS_TOP_LEVEL)
        return()  # Early return for lightweight consumer mode
    endif()

    # Copy static template files (like .clang-format, .gitignore, CMakePresets.json, etc.)
    if(DEFINED CPP_LIBRARY_FORCE_INIT AND CPP_LIBRARY_FORCE_INIT)
        _cpp_library_copy_templates("${PACKAGE_NAME}" FORCE_INIT)
    else()
        _cpp_library_copy_templates("${PACKAGE_NAME}")
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
