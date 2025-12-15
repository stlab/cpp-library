#!/usr/bin/env -S cmake -P
# SPDX-License-Identifier: BSL-1.0
#
# setup.cmake - Interactive project setup script for cpp-library
#
# Usage:
#   cmake -P setup.cmake
#   cmake -P setup.cmake -- --name=my-lib --namespace=myns --description="My library"

cmake_minimum_required(VERSION 3.20)

# Parse command line arguments
set(CMD_LINE_ARGS "")
if(CMAKE_ARGV3)
    # Arguments after -- are available starting from CMAKE_ARGV3
    math(EXPR ARGC "${CMAKE_ARGC} - 3")
    foreach(i RANGE ${ARGC})
        math(EXPR idx "${i} + 3")
        if(CMAKE_ARGV${idx})
            list(APPEND CMD_LINE_ARGS "${CMAKE_ARGV${idx}}")
        endif()
    endforeach()
endif()

# Parse named arguments
set(ARG_NAME "")
set(ARG_NAMESPACE "")
set(ARG_DESCRIPTION "")
set(ARG_HEADER_ONLY "")
set(ARG_EXAMPLES "")
set(ARG_TESTS "")

foreach(arg IN LISTS CMD_LINE_ARGS)
    if(arg MATCHES "^--name=(.+)$")
        set(ARG_NAME "${CMAKE_MATCH_1}")
    elseif(arg MATCHES "^--namespace=(.+)$")
        set(ARG_NAMESPACE "${CMAKE_MATCH_1}")
    elseif(arg MATCHES "^--description=(.+)$")
        set(ARG_DESCRIPTION "${CMAKE_MATCH_1}")
    elseif(arg MATCHES "^--header-only=(yes|no|true|false|1|0)$")
        string(TOLOWER "${CMAKE_MATCH_1}" val)
        if(val MATCHES "^(yes|true|1)$")
            set(ARG_HEADER_ONLY YES)
        else()
            set(ARG_HEADER_ONLY NO)
        endif()
    elseif(arg MATCHES "^--examples=(yes|no|true|false|1|0)$")
        string(TOLOWER "${CMAKE_MATCH_1}" val)
        if(val MATCHES "^(yes|true|1)$")
            set(ARG_EXAMPLES YES)
        else()
            set(ARG_EXAMPLES NO)
        endif()
    elseif(arg MATCHES "^--tests=(yes|no|true|false|1|0)$")
        string(TOLOWER "${CMAKE_MATCH_1}" val)
        if(val MATCHES "^(yes|true|1)$")
            set(ARG_TESTS YES)
        else()
            set(ARG_TESTS NO)
        endif()
    elseif(arg MATCHES "^--help$")
        message([[
Usage: cmake -P setup.cmake [OPTIONS]

Interactive setup script for cpp-library projects.

OPTIONS:
  --name=NAME              Library name (e.g., my-library)
  --namespace=NAMESPACE    Namespace (e.g., mycompany)
  --description=DESC       Brief description
  --header-only=yes|no     Header-only library (default: yes)
  --examples=yes|no        Include examples (default: yes)
  --tests=yes|no           Include tests (default: yes)
  --help                   Show this help message

If options are not provided, the script will prompt interactively.

Examples:
  cmake -P setup.cmake
  cmake -P setup.cmake -- --name=my-lib --namespace=myns --description="My library"
]])
        return()
    endif()
endforeach()

# Helper function to prompt user for input
function(prompt_user PROMPT_TEXT OUTPUT_VAR DEFAULT_VALUE)
    # Display prompt using CMake message (goes to console)
    execute_process(COMMAND ${CMAKE_COMMAND} -E echo_append "${PROMPT_TEXT}")
    
    if(CMAKE_HOST_WIN32)
        # Windows: Use PowerShell for input
        execute_process(
            COMMAND powershell -NoProfile -Command "$Host.UI.ReadLine()"
            OUTPUT_VARIABLE USER_INPUT
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    else()
        # Unix: Read from stdin using shell
        execute_process(
            COMMAND sh -c "read input && printf '%s' \"$input\""
            OUTPUT_VARIABLE USER_INPUT
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    endif()
    
    if(USER_INPUT STREQUAL "" AND NOT DEFAULT_VALUE STREQUAL "")
        set(${OUTPUT_VAR} "${DEFAULT_VALUE}" PARENT_SCOPE)
    else()
        set(${OUTPUT_VAR} "${USER_INPUT}" PARENT_SCOPE)
    endif()
endfunction()

# Helper function to prompt for yes/no
function(prompt_yes_no PROMPT_TEXT OUTPUT_VAR DEFAULT_VALUE)
    if(DEFAULT_VALUE)
        set(prompt_suffix " [Y/n]: ")
        set(default_result YES)
    else()
        set(prompt_suffix " [y/N]: ")
        set(default_result NO)
    endif()
    
    prompt_user("${PROMPT_TEXT}${prompt_suffix}" USER_INPUT "")
    
    string(TOLOWER "${USER_INPUT}" USER_INPUT_LOWER)
    if(USER_INPUT_LOWER STREQUAL "y" OR USER_INPUT_LOWER STREQUAL "yes")
        set(${OUTPUT_VAR} YES PARENT_SCOPE)
    elseif(USER_INPUT_LOWER STREQUAL "n" OR USER_INPUT_LOWER STREQUAL "no")
        set(${OUTPUT_VAR} NO PARENT_SCOPE)
    elseif(USER_INPUT STREQUAL "")
        set(${OUTPUT_VAR} ${default_result} PARENT_SCOPE)
    else()
        set(${OUTPUT_VAR} ${default_result} PARENT_SCOPE)
    endif()
endfunction()

message("=== cpp-library Project Setup ===\n")

# Collect information interactively if not provided
if(ARG_NAME STREQUAL "")
    prompt_user("Library name (e.g., my-library): " ARG_NAME "")
    if(ARG_NAME STREQUAL "")
        message(FATAL_ERROR "Library name is required")
    endif()
endif()

if(ARG_NAMESPACE STREQUAL "")
    prompt_user("Namespace (e.g., mycompany): " ARG_NAMESPACE "")
    if(ARG_NAMESPACE STREQUAL "")
        message(FATAL_ERROR "Namespace is required")
    endif()
endif()

if(ARG_DESCRIPTION STREQUAL "")
    prompt_user("Description: " ARG_DESCRIPTION "A C++ library")
endif()

if(ARG_HEADER_ONLY STREQUAL "")
    prompt_yes_no("Header-only library?" ARG_HEADER_ONLY YES)
endif()

if(ARG_EXAMPLES STREQUAL "")
    prompt_yes_no("Include examples?" ARG_EXAMPLES YES)
endif()

if(ARG_TESTS STREQUAL "")
    prompt_yes_no("Include tests?" ARG_TESTS YES)
endif()

# Display summary
message("\n=== Configuration Summary ===")
message("Library name:    ${ARG_NAME}")
message("Namespace:       ${ARG_NAMESPACE}")
message("Description:     ${ARG_DESCRIPTION}")
message("Header-only:     ${ARG_HEADER_ONLY}")
message("Include examples: ${ARG_EXAMPLES}")
message("Include tests:    ${ARG_TESTS}")
message("")

# Get current working directory
if(CMAKE_HOST_WIN32)
    execute_process(
        COMMAND powershell -NoProfile -Command "Get-Location | Select-Object -ExpandProperty Path"
        OUTPUT_VARIABLE CURRENT_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
else()
    execute_process(
        COMMAND pwd
        OUTPUT_VARIABLE CURRENT_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
endif()

# Create project directory in current working directory
set(PROJECT_DIR "${CURRENT_DIR}/${ARG_NAME}")
if(EXISTS "${PROJECT_DIR}")
    message(FATAL_ERROR "Directory '${ARG_NAME}' already exists!")
endif()

message("Creating project structure in: ${ARG_NAME}/")
file(MAKE_DIRECTORY "${PROJECT_DIR}")

# Create directory structure
file(MAKE_DIRECTORY "${PROJECT_DIR}/include/${ARG_NAMESPACE}")
file(MAKE_DIRECTORY "${PROJECT_DIR}/cmake")

if(NOT ARG_HEADER_ONLY)
    file(MAKE_DIRECTORY "${PROJECT_DIR}/src")
endif()

if(ARG_EXAMPLES)
    file(MAKE_DIRECTORY "${PROJECT_DIR}/examples")
endif()

if(ARG_TESTS)
    file(MAKE_DIRECTORY "${PROJECT_DIR}/tests")
endif()

# Download CPM.cmake
message("Downloading CPM.cmake...")
file(DOWNLOAD
    "https://github.com/cpm-cmake/CPM.cmake/releases/latest/download/get_cpm.cmake"
    "${PROJECT_DIR}/cmake/CPM.cmake"
    STATUS DOWNLOAD_STATUS
    TIMEOUT 30
)

list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
if(NOT STATUS_CODE EQUAL 0)
    list(GET DOWNLOAD_STATUS 1 ERROR_MESSAGE)
    message(WARNING "Failed to download CPM.cmake: ${ERROR_MESSAGE}")
    message(WARNING "You'll need to download it manually from https://github.com/cpm-cmake/CPM.cmake")
endif()

# Create main header file
set(HEADER_FILE "${ARG_NAME}.hpp")
# Sanitize name for use in header guards (replace hyphens with underscores and convert to uppercase)
string(REPLACE "-" "_" HEADER_GUARD_NAME "${ARG_NAME}")
string(TOUPPER "${ARG_NAMESPACE}_${HEADER_GUARD_NAME}_HPP" HEADER_GUARD_NAME)
file(WRITE "${PROJECT_DIR}/include/${ARG_NAMESPACE}/${HEADER_FILE}"
"// SPDX-License-Identifier: BSL-1.0

#ifndef ${HEADER_GUARD_NAME}
#define ${HEADER_GUARD_NAME}

namespace ${ARG_NAMESPACE} {

// Your library code here

} // namespace ${ARG_NAMESPACE}

#endif // ${HEADER_GUARD_NAME}
")

# Create source file if not header-only
set(SOURCE_FILES "")
if(NOT ARG_HEADER_ONLY)
    set(SOURCE_FILENAME "${ARG_NAME}.cpp")
    set(SOURCE_FILES "SOURCES ${SOURCE_FILENAME}")
    file(WRITE "${PROJECT_DIR}/src/${SOURCE_FILENAME}"
"// SPDX-License-Identifier: BSL-1.0

#include <${ARG_NAMESPACE}/${HEADER_FILE}>

namespace ${ARG_NAMESPACE} {

// Implementation here

} // namespace ${ARG_NAMESPACE}
")
endif()

# Create example file
set(EXAMPLE_FILES "")
if(ARG_EXAMPLES)
    set(EXAMPLE_FILES "EXAMPLES example.cpp")
    file(WRITE "${PROJECT_DIR}/examples/example.cpp"
"// SPDX-License-Identifier: BSL-1.0

#include <${ARG_NAMESPACE}/${HEADER_FILE}>

#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

TEST_CASE(\"example test\") {
    // Your example code here
    CHECK(true);
}
")
endif()

# Create test file
set(TEST_FILES "")
if(ARG_TESTS)
    set(TEST_FILES "TESTS tests.cpp")
    file(WRITE "${PROJECT_DIR}/tests/tests.cpp"
"// SPDX-License-Identifier: BSL-1.0

#include <${ARG_NAMESPACE}/${HEADER_FILE}>

#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

TEST_CASE(\"basic test\") {
    // Your tests here
    CHECK(true);
}
")
endif()

# Generate CMakeLists.txt
file(WRITE "${PROJECT_DIR}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.24)

# Setup CPM cache before project()
if(PROJECT_IS_TOP_LEVEL AND NOT CPM_SOURCE_CACHE AND NOT DEFINED ENV{CPM_SOURCE_CACHE})
    set(CPM_SOURCE_CACHE "${CMAKE_SOURCE_DIR}/.cache/cpm" CACHE PATH "CPM source cache")
    message(STATUS "Setting cpm cache dir to: ${CPM_SOURCE_CACHE}")
endif()
include(cmake/CPM.cmake)

# Fetch cpp-library before project()
CPMAddPackage(\"gh:stlab/cpp-library@5.0.0\")
include(\${cpp-library_SOURCE_DIR}/cpp-library.cmake)

# Enable dependency tracking before project()
cpp_library_enable_dependency_tracking()

# Now declare project
project(${ARG_NAME})

# Setup library
cpp_library_setup(
    DESCRIPTION \"${ARG_DESCRIPTION}\"
    NAMESPACE ${ARG_NAMESPACE}
    HEADERS ${HEADER_FILE}
    ${SOURCE_FILES}
    ${EXAMPLE_FILES}
    ${TEST_FILES}
)
")

# Create .gitignore
file(WRITE "${PROJECT_DIR}/.gitignore"
"build/
.cache/
compile_commands.json
.DS_Store
*.swp
*.swo
*~
")

# Initialize git repository
message("\nInitializing git repository...")
execute_process(
    COMMAND git init
    WORKING_DIRECTORY "${PROJECT_DIR}"
    OUTPUT_QUIET
    ERROR_QUIET
)

execute_process(
    COMMAND git add .
    WORKING_DIRECTORY "${PROJECT_DIR}"
    OUTPUT_QUIET
    ERROR_QUIET
)

execute_process(
    COMMAND git commit -m "Initial commit"
    WORKING_DIRECTORY "${PROJECT_DIR}"
    OUTPUT_QUIET
    ERROR_QUIET
    RESULT_VARIABLE GIT_COMMIT_RESULT
)

if(GIT_COMMIT_RESULT EQUAL 0)
    message("✓ Git repository initialized with initial commit")
else()
    message("✓ Git repository initialized (commit manually)")
endif()

# Success message
message("\n=== Setup Complete! ===\n")
message("Your library has been created in: ${ARG_NAME}/")
message("\nNext steps:")
message("  cd ${ARG_NAME}")
message("\n  # Generate template files (CMakePresets.json, CI workflows, etc.)")
message("  cmake -B build -DCPP_LIBRARY_FORCE_INIT=ON")
message("\n  # Now you can use the presets:")
message("  cmake --preset=test")
message("  cmake --build --preset=test")
message("  ctest --preset=test")
message("\nTo regenerate template files later:")
message("  cmake --preset=init")
message("  cmake --build --preset=init")
message("\nFor more information, visit: https://github.com/stlab/cpp-library")
