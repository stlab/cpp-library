# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-testing.cmake - Private test configuration and executable support
# 
# Provides cpp_library_copy_runtime_dlls for custom and toolkit-created executables.
# _cpp_library_setup_testing delegates to _cpp_library_setup_executables for compatibility.

# Adds a private, always-defined function-style testing configuration.
function(_cpp_library_setup_testing_config)
    cmake_parse_arguments(ARG "" "TARGET;ENABLED" "" ${ARGN})
    set(directory "${CMAKE_CURRENT_BINARY_DIR}/cpp-library/testing-${ARG_ENABLED}")
    file(CONFIGURE OUTPUT "${directory}/cpp-library/testing.hpp"
        CONTENT "#pragma once\n#define CPP_LIBRARY_TESTING() @ARG_ENABLED@\n" @ONLY)
    target_include_directories("${ARG_TARGET}" BEFORE PRIVATE "${directory}")
endfunction()

# Copies finalized build requirements without linking the production implementation.
function(_cpp_library_finish_test_target source destination)
    foreach(property SOURCES INCLUDE_DIRECTORIES COMPILE_DEFINITIONS COMPILE_OPTIONS
            COMPILE_FEATURES CXX_STANDARD CXX_STANDARD_REQUIRED CXX_EXTENSIONS
            CXX_VISIBILITY_PRESET VISIBILITY_INLINES_HIDDEN POSITION_INDEPENDENT_CODE
            CXX_CLANG_TIDY CXX_COMPILER_LAUNCHER LINK_OPTIONS LINK_DIRECTORIES
            INTERFACE_INCLUDE_DIRECTORIES INTERFACE_SYSTEM_INCLUDE_DIRECTORIES
            INTERFACE_COMPILE_DEFINITIONS INTERFACE_COMPILE_OPTIONS
            INTERFACE_COMPILE_FEATURES INTERFACE_LINK_OPTIONS INTERFACE_LINK_DIRECTORIES
            INTERFACE_LINK_LIBRARIES_DIRECT INTERFACE_LINK_LIBRARIES_DIRECT_EXCLUDE)
        get_property(is_set TARGET "${source}" PROPERTY "${property}" SET)
        if(is_set)
            get_target_property(value "${source}" "${property}")
            set_property(TARGET "${destination}" PROPERTY "${property}" "${value}")
        endif()
    endforeach()
    get_target_property(links "${source}" LINK_LIBRARIES)
    if(links)
        target_link_libraries("${destination}" PRIVATE ${links})
    endif()
    get_target_property(interface_links "${source}" INTERFACE_LINK_LIBRARIES)
    if(interface_links)
        target_link_libraries("${destination}" INTERFACE ${interface_links})
    endif()
    get_target_property(dependencies "${source}" MANUALLY_ADDED_DEPENDENCIES)
    if(dependencies)
        add_dependencies("${destination}" ${dependencies})
    endif()
endfunction()

# Selects a static implementation for existing per-file unit tests.
function(_cpp_library_setup_test_support)
    cmake_parse_arguments(ARG "" "TARGET" "" ${ARGN})
    get_target_property(type "${ARG_TARGET}" TYPE)
    set(test_target "${ARG_TARGET}")
    if(type STREQUAL "SHARED_LIBRARY")
        set(test_target "${ARG_TARGET}_static_tests")
        add_library("${test_target}" STATIC)
        cmake_language(EVAL CODE
            "cmake_language(DEFER CALL _cpp_library_finish_test_target
                [[${ARG_TARGET}]] [[${test_target}]])")
    endif()
    set_property(TARGET "${ARG_TARGET}" PROPERTY _CPP_LIBRARY_UNIT_TEST_TARGET "${test_target}")
endfunction()

# Deploys runtime DLLs beside a custom target on Windows; empty lists need no copy.
# Call in the directory that created the target, as required by POST_BUILD commands.
function(cpp_library_copy_runtime_dlls target)
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "cpp_library_copy_runtime_dlls: Target does not exist: ${target}")
    endif()
    if(WIN32)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND "${CMAKE_COMMAND}"
                "-DCPP_LIBRARY_RUNTIME_DLLS=$<TARGET_RUNTIME_DLLS:${target}>"
                "-DCPP_LIBRARY_RUNTIME_DESTINATION=$<TARGET_FILE_DIR:${target}>"
                -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cpp-library-copy-runtime-dlls.cmake"
            VERBATIM)
    endif()
endfunction()

# Delegates to _cpp_library_setup_executables for backward compatibility.
# - Postcondition: test executables configured via _cpp_library_setup_executables
function(_cpp_library_setup_testing)
    set(oneValueArgs
        NAME
        NAMESPACE
    )
    set(multiValueArgs
        TESTS
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Delegate to the consolidated implementation
    _cpp_library_setup_executables(
        NAME "${ARG_NAME}"
        NAMESPACE "${ARG_NAMESPACE}" 
        TYPE "tests"
        EXECUTABLES "${ARG_TESTS}"
    )
    
endfunction()
