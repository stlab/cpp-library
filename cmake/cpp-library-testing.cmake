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
    get_target_property(sources "${source}" SOURCES)
    target_sources("${destination}" PRIVATE ${sources})
    get_target_property(type "${destination}" TYPE)
    set(compile_usage INCLUDE_DIRECTORIES COMPILE_DEFINITIONS COMPILE_OPTIONS COMPILE_FEATURES)
    foreach(property INCLUDE_DIRECTORIES COMPILE_DEFINITIONS COMPILE_OPTIONS
            COMPILE_FEATURES CXX_STANDARD CXX_STANDARD_REQUIRED CXX_EXTENSIONS
            CXX_VISIBILITY_PRESET VISIBILITY_INLINES_HIDDEN POSITION_INDEPENDENT_CODE
            CXX_CLANG_TIDY CXX_COMPILER_LAUNCHER LINK_OPTIONS LINK_DIRECTORIES
            INTERFACE_SYSTEM_INCLUDE_DIRECTORIES
            INTERFACE_LINK_OPTIONS INTERFACE_LINK_DIRECTORIES
            INTERFACE_LINK_LIBRARIES_DIRECT INTERFACE_LINK_LIBRARIES_DIRECT_EXCLUDE)
        get_property(is_set TARGET "${source}" PROPERTY "${property}" SET)
        if(is_set)
            get_target_property(value "${source}" "${property}")
            set_property(TARGET "${destination}" PROPERTY "${property}" "${value}")
            if(type STREQUAL "STATIC_LIBRARY" AND property IN_LIST compile_usage)
                # Unit tests consume implementation settings, not DLL-import definitions.
                set_property(TARGET "${destination}" PROPERTY "INTERFACE_${property}" "${value}")
            endif()
        endif()
    endforeach()
    get_target_property(links "${source}" LINK_LIBRARIES)
    if(links)
        if(type STREQUAL "STATIC_LIBRARY")
            target_link_libraries("${destination}" PUBLIC ${links})
        else()
            target_link_libraries("${destination}" PRIVATE ${links})
        endif()
    endif()
    get_target_property(standard "${source}" CXX_STANDARD)
    if(type STREQUAL "STATIC_LIBRARY" AND standard)
        target_compile_features("${destination}" INTERFACE "cxx_std_${standard}")
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

# Configures the separate runner after all implementation requirements are known.
function(_cpp_library_finish_in_source_tests source destination)
    _cpp_library_finish_test_target("${source}" "${destination}")
    _cpp_library_setup_testing_config(TARGET "${destination}" ENABLED 1)
    target_link_libraries("${destination}" PRIVATE doctest::doctest)
endfunction()

# Creates static per-file test support and a separate in-source runner.
function(_cpp_library_setup_test_support)
    cmake_parse_arguments(ARG "" "TARGET" "" ${ARGN})
    get_target_property(type "${ARG_TARGET}" TYPE)
    set(test_target "${ARG_TARGET}")
    if(NOT type STREQUAL "INTERFACE_LIBRARY")
        set(test_target "${ARG_TARGET}_static_tests")
        add_library("${test_target}" STATIC EXCLUDE_FROM_ALL)
        cmake_language(EVAL CODE
            "cmake_language(DEFER CALL _cpp_library_finish_test_target
                [[${ARG_TARGET}]] [[${test_target}]])")
    endif()
    set_property(TARGET "${ARG_TARGET}" PROPERTY _CPP_LIBRARY_UNIT_TEST_TARGET "${test_target}")
    if(NOT type STREQUAL "INTERFACE_LIBRARY")
        set(runner "${ARG_TARGET}_in_source_tests")
        set(main "${CMAKE_CURRENT_BINARY_DIR}/cpp-library/${runner}.cpp")
        file(CONFIGURE OUTPUT "${main}" CONTENT
            "#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN\n#include <doctest/doctest.h>\n")
        add_executable("${runner}" "${main}")
        cmake_language(EVAL CODE
            "cmake_language(DEFER CALL _cpp_library_finish_in_source_tests
                [[${ARG_TARGET}]] [[${runner}]])")
        cpp_library_copy_runtime_dlls("${runner}")
        add_test(NAME "${runner}" COMMAND "${runner}")
        set_tests_properties("${runner}" PROPERTIES LABELS doctest
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
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
