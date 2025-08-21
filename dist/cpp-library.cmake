# SPDX-License-Identifier: BSL-1.0
#
# cpp-library.cmake - Modern C++ Header-Only Library Template (Single File Distribution)
# Generated from: https://github.com/stlab/cpp-library
#
# Usage: Download and include this file, then call cpp_library_setup(...)

cmake_minimum_required(VERSION 3.20)
include(CTest)

# Embedded templates
set(CPP_LIBRARY_PRESETS_TEMPLATE "{
  \"version\": 2,
  \"configurePresets\": [
    {
      \"name\": \"default\",
      \"displayName\": \"Default Configuration\",
      \"description\": \"Default configuration for building the library\",
      \"binaryDir\": \"${sourceDir}/build/default\",
      \"generator\": \"Ninja\",
      \"cacheVariables\": {
        \"CMAKE_BUILD_TYPE\": \"Release\",
        \"CMAKE_EXPORT_COMPILE_COMMANDS\": \"ON\"
      }
    },
    {
      \"name\": \"test\",
      \"displayName\": \"Test Configuration\",
      \"description\": \"Configuration for building and running tests\",
      \"binaryDir\": \"${sourceDir}/build/test\",
      \"generator\": \"Ninja\",
      \"cacheVariables\": {
        \"CMAKE_BUILD_TYPE\": \"Debug\",
        \"BUILD_TESTING\": \"ON\",
        \"CMAKE_EXPORT_COMPILE_COMMANDS\": \"ON\"
      }
    },
    {
      \"name\": \"docs\",
      \"displayName\": \"Documentation Configuration\",
      \"description\": \"Configuration for building documentation\",
      \"binaryDir\": \"${sourceDir}/build/docs\",
      \"inherits\": \"test\",
      \"cacheVariables\": {
        \"BUILD_DOCS\": \"ON\"
      }
    }
  ],
  \"buildPresets\": [
    { \"name\": \"default\", \"displayName\": \"Default Build\", \"configurePreset\": \"default\" },
    { \"name\": \"test\", \"displayName\": \"Build Tests\", \"configurePreset\": \"test\" },
    { \"name\": \"docs\", \"displayName\": \"Build Docs\", \"configurePreset\": \"docs\", \"targets\": [\"docs\"] }
  ],
  \"testPresets\": [
    { \"name\": \"test\", \"displayName\": \"Run All Tests\", \"configurePreset\": \"test\", \"output\": { \"outputOnFailure\": true } }
  ]
}
")
set(CPP_LIBRARY_CONFIG_TEMPLATE "include(CMakeFindDependencyMacro)

include(\"${CMAKE_CURRENT_LIST_DIR}/@ARG_NAME@Targets.cmake\")
")  
set(CPP_LIBRARY_DOXYFILE_TEMPLATE "PROJECT_NAME           = \"@PROJECT_NAME@\"
PROJECT_BRIEF          = \"@PROJECT_BRIEF@\"
PROJECT_NUMBER         = @PROJECT_VERSION@
OUTPUT_DIRECTORY       = @OUTPUT_DIR@
GENERATE_LATEX         = NO
QUIET                  = YES
WARN_IF_UNDOCUMENTED   = YES
INPUT                  = @INPUT_DIR@
RECURSIVE              = YES
EXCLUDE_SYMBOLS        = @EXCLUDE_SYMBOLS@
EXAMPLE_PATH           = @EXAMPLE_PATH@
HTML_EXTRA_STYLESHEET  = @AWESOME_CSS_PATH@/doxygen-awesome.css \\
                         @AWESOME_CSS_PATH@/doxygen-awesome-sidebar-only.css \\
                         @AWESOME_CSS_PATH@/doxygen-awesome-sidebar-only-darkmode-toggle.css
HTML_COLORSTYLE        = LIGHT
GENERATE_TREEVIEW      = YES
DISABLE_INDEX          = NO
FULL_SIDEBAR           = NO
HTML_EXTRA_FILES       = @AWESOME_CSS_PATH@/doxygen-awesome-darkmode-toggle.js \\
                         @AWESOME_CSS_PATH@/doxygen-awesome-fragment-copy-button.js \\
                         @AWESOME_CSS_PATH@/doxygen-awesome-paragraph-link.js
HTML_HEADER            = 
USE_MDFILE_AS_MAINPAGE = README.md
")
set(CPP_LIBRARY_CI_TEMPLATE "name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        compiler: [gcc, clang, msvc]
        exclude:
          - os: ubuntu-latest
            compiler: msvc
          - os: macos-latest
            compiler: msvc
          - os: macos-latest
            compiler: gcc
          - os: windows-latest
            compiler: gcc
          - os: windows-latest
            compiler: clang

    runs-on: ${{ matrix.os }}

    steps:
    - uses: actions/checkout@v4

    - name: Setup Ninja
      uses: ashutoshvarma/setup-ninja@master

    - name: Setup GCC
      if: matrix.compiler == 'gcc'
      uses: egor-tensin/setup-gcc@v1
      with:
        version: latest

    - name: Setup Clang
      if: matrix.compiler == 'clang' && matrix.os == 'ubuntu-latest'
      uses: egor-tensin/setup-clang@v1
      with:
        version: latest

    - name: Setup MSVC
      if: matrix.compiler == 'msvc'
      uses: ilammy/msvc-dev-cmd@v1

    - name: Configure CMake
      run: cmake --preset=test

    - name: Build
      run: cmake --build --preset=test

    - name: Test
      run: ctest --preset=test

  docs:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Ninja
      uses: ashutoshvarma/setup-ninja@master
      
    - name: Install Doxygen
      run: sudo apt-get update && sudo apt-get install -y doxygen graphviz
    
    - name: Configure CMake
      run: cmake --preset=docs
    
    - name: Build Documentation
      run: cmake --build --preset=docs
    
    - name: Deploy to GitHub Pages
      if: success() && '@ENABLE_DOCS_DEPLOYMENT@' == 'true'
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./build/docs/html
        destination_dir: @PROJECT_NAME@
")

# === cpp-library-setup.cmake ===
function(_cpp_library_setup_core)
    # Write embedded template to temporary file
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/cpp-library-config.cmake.in" "${CPP_LIBRARY_CONFIG_TEMPLATE}")
    set(oneValueArgs
        NAME
        VERSION 
        DESCRIPTION
        NAMESPACE
        HEADER_DIR
        REQUIRES_CPP_VERSION
    )
    set(multiValueArgs
        HEADERS
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Extract the library name without namespace prefix for target naming
    string(REPLACE "${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
    
    # Create the INTERFACE library target
    add_library(${ARG_NAME} INTERFACE)
    add_library(${ARG_NAMESPACE}::${CLEAN_NAME} ALIAS ${ARG_NAME})
    
    # Set include directories
    target_include_directories(${ARG_NAME} INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    )
    
    # Set C++ standard requirement  
    target_compile_features(${ARG_NAME} INTERFACE cxx_std_${ARG_REQUIRES_CPP_VERSION})
    
    # Set up installation if headers are specified
    if(ARG_HEADERS)
        # Use FILE_SET for modern CMake header installation
        target_sources(${ARG_NAME} INTERFACE
            FILE_SET headers
            TYPE HEADERS
            BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/include
            FILES ${ARG_HEADERS}
        )
    endif()
    
    # Only set up full installation when building as top-level project
    if(PROJECT_IS_TOP_LEVEL)
        include(GNUInstallDirs)
        include(CMakePackageConfigHelpers)
        
        # Install the target
        install(TARGETS ${ARG_NAME}
            EXPORT ${ARG_NAME}Targets
            FILE_SET headers DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        )
        
        # Install header directory if specified (fallback for older CMake)
        if(ARG_HEADER_DIR)
            install(DIRECTORY ${ARG_HEADER_DIR}/
                DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                FILES_MATCHING PATTERN "*.hpp" PATTERN "*.h"
            )
        endif()
        
        # Generate package config files
        write_basic_package_version_file(
            "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}ConfigVersion.cmake"
            VERSION ${ARG_VERSION}
            COMPATIBILITY SameMajorVersion
        )
        
        configure_file(
            "${CMAKE_CURRENT_BINARY_DIR}/cpp-library-config.cmake.in"
            "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}Config.cmake"
            @ONLY
        )
        
        # Install export targets
        install(EXPORT ${ARG_NAME}Targets
            FILE ${ARG_NAME}Targets.cmake
            NAMESPACE ${ARG_NAMESPACE}::
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${ARG_NAME}
        )
        
        # Install config files
        install(FILES
            "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}Config.cmake"
            "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}ConfigVersion.cmake"
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${ARG_NAME}
        )
    endif()
    
endfunction()


# === cpp-library-testing.cmake ===
function(_cpp_library_setup_testing)
    set(oneValueArgs
        NAME
        NAMESPACE
    )
    set(multiValueArgs
        TESTS
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Extract the clean library name for linking
    string(REPLACE "${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
    
    # Download doctest dependency via CPM
    if(NOT TARGET doctest::doctest)
        CPMAddPackage("gh:doctest/doctest@2.4.12")
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
    
    # Add test executables
    foreach(test IN LISTS ARG_TESTS)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/${test}.cpp" OR 
           EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/test/${test}.cpp")
           
            # Check both tests/ and test/ directories (projects use different conventions)
            set(test_file "")
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/${test}.cpp")
                set(test_file "tests/${test}.cpp")
            elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/test/${test}.cpp")
                set(test_file "test/${test}.cpp")
            endif()
            
            add_executable(${test} ${test_file})
            target_link_libraries(${test} PRIVATE ${ARG_NAMESPACE}::${CLEAN_NAME} doctest::doctest)
            
            # Register the test with CTest
            add_test(NAME ${test} COMMAND ${test})
            
            # Set test properties for better IDE integration
            set_tests_properties(${test} PROPERTIES
                LABELS "doctest"
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            )
        else()
            message(WARNING "Test file for ${test} not found in tests/ or test/ directories")
        endif()
    endforeach()
    
endfunction()


# === cpp-library-docs.cmake ===
function(_cpp_library_setup_docs)
    # Write embedded template to temporary file
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/cpp-library-doxyfile.in" "${CPP_LIBRARY_DOXYFILE_TEMPLATE}")
    set(oneValueArgs
        NAME
        VERSION
        DESCRIPTION
    )
    set(multiValueArgs
        DOCS_EXCLUDE_SYMBOLS
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    find_package(Doxygen REQUIRED)
    if(NOT DOXYGEN_FOUND)
        message(WARNING "Doxygen not found. Documentation will not be built.")
        return()
    endif()
    
    # Download doxygen-awesome-css theme via CPM
    CPMAddPackage(
        NAME doxygen-awesome-css
        GIT_REPOSITORY https://github.com/jothepro/doxygen-awesome-css
        GIT_TAG v2.3.4
        DOWNLOAD_ONLY YES
    )
    
    # Set the CSS directory path
    set(AWESOME_CSS_DIR ${doxygen-awesome-css_SOURCE_DIR})
    
    # Configure Doxyfile from template
    set(DOXYFILE_IN ${CMAKE_CURRENT_BINARY_DIR}/cpp-library-doxyfile.in)
    set(DOXYFILE_OUT ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile)
    
    # Set variables for Doxyfile template
    set(PROJECT_NAME "${ARG_NAME}")
    set(PROJECT_BRIEF "${ARG_DESCRIPTION}")
    set(PROJECT_VERSION "${ARG_VERSION}")
    set(INPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
    set(OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    set(AWESOME_CSS_PATH "${AWESOME_CSS_DIR}")
    set(EXAMPLE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/example")
    
    # Convert exclude symbols list to space-separated string
    if(ARG_DOCS_EXCLUDE_SYMBOLS)
        string(REPLACE ";" " " EXCLUDE_SYMBOLS_STR "${ARG_DOCS_EXCLUDE_SYMBOLS}")
        set(EXCLUDE_SYMBOLS "${EXCLUDE_SYMBOLS_STR}")
    else()
        set(EXCLUDE_SYMBOLS "")
    endif()
    
    # Check if we have a custom Doxyfile, otherwise use template
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/docs/Doxyfile")
        configure_file("${CMAKE_CURRENT_SOURCE_DIR}/docs/Doxyfile" ${DOXYFILE_OUT} @ONLY)
    else()
        configure_file(${DOXYFILE_IN} ${DOXYFILE_OUT} @ONLY)
    endif()
    
    # Add custom target for documentation
    add_custom_target(docs
        COMMAND ${DOXYGEN_EXECUTABLE} ${DOXYFILE_OUT}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Generating API documentation with Doxygen"
        VERBATIM
    )
    
    # Ensure the output directory exists
    file(MAKE_DIRECTORY ${OUTPUT_DIR})
    
    message(STATUS "Documentation target 'docs' configured")
    message(STATUS "Run 'cmake --build . --target docs' to generate documentation")
    
endfunction()


# === cpp-library-presets.cmake ===
function(_cpp_library_generate_presets)
    # Write embedded template to temporary file
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/cpp-library-presets.json.in" "${CPP_LIBRARY_PRESETS_TEMPLATE}")
    # Only generate if CMakePresets.json doesn't already exist
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CMakePresets.json")
        return()
    endif()
    
    set(PRESETS_TEMPLATE ${CMAKE_CURRENT_BINARY_DIR}/cpp-library-presets.json.in)
    set(PRESETS_OUT ${CMAKE_CURRENT_SOURCE_DIR}/CMakePresets.json)
    
    # Configure the presets template
    configure_file(${PRESETS_TEMPLATE} ${PRESETS_OUT} @ONLY)
    
    message(STATUS "Generated CMakePresets.json from template")
    
endfunction()


# === cpp-library-ci.cmake ===
function(_cpp_library_setup_ci)
    set(options
        CI_DEPLOY_DOCS
    )
    set(oneValueArgs
        NAME
        VERSION
        DESCRIPTION
    )
    set(multiValueArgs
        CI_PLATFORMS
        CI_COMPILERS
    )
    
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Set defaults
    if(NOT ARG_CI_PLATFORMS)
        set(ARG_CI_PLATFORMS "ubuntu-latest" "macos-latest" "windows-latest")
    endif()
    if(NOT ARG_CI_COMPILERS)
        set(ARG_CI_COMPILERS "gcc" "clang" "msvc")
    endif()
    
    # Only generate CI files if they don't exist
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.github/workflows/ci.yml")
        # Create .github/workflows directory
        file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.github/workflows")
        
        # Determine template source
        if(DEFINED CPP_LIBRARY_CI_TEMPLATE)
            # Embedded template (packaged version)
            file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/cpp-library-ci.yml.in" "${CPP_LIBRARY_CI_TEMPLATE}")
            set(TEMPLATE_FILE "${CMAKE_CURRENT_BINARY_DIR}/cpp-library-ci.yml.in")
        else()
            # External template file (development version)
            set(TEMPLATE_FILE "${CPP_LIBRARY_ROOT}/templates/.github/workflows/ci.yml.in")
        endif()
        
        # Configure template variables
        set(PROJECT_NAME "${ARG_NAME}")
        set(PROJECT_VERSION "${ARG_VERSION}")
        set(PROJECT_DESCRIPTION "${ARG_DESCRIPTION}")
        if(ARG_CI_DEPLOY_DOCS)
            set(ENABLE_DOCS_DEPLOYMENT "true")
        else()
            set(ENABLE_DOCS_DEPLOYMENT "false")
        endif()
        
        configure_file(
            "${TEMPLATE_FILE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/.github/workflows/ci.yml"
            @ONLY
        )
        
        message(STATUS "Generated .github/workflows/ci.yml for ${ARG_NAME}")
    endif()
    
endfunction()


# === Main cpp_library_setup function ===
# Main entry point function - users call this to set up their library
function(cpp_library_setup)
    # Parse arguments
    set(options 
        CUSTOM_INSTALL          # Skip default installation
        NO_PRESETS             # Skip CMakePresets.json generation
        ENABLE_CI              # Generate CI files
        CI_DEPLOY_DOCS         # Enable docs deployment in CI
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
        CI_PLATFORMS           # CI platforms (default: ubuntu-latest, macos-latest, windows-latest)
        CI_COMPILERS           # CI compilers (default: gcc, clang, msvc)
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
    
    if(ARG_ENABLE_CI AND PROJECT_IS_TOP_LEVEL)
        _cpp_library_setup_ci(
            NAME "${ARG_NAME}"
            VERSION "${ARG_VERSION}"
            DESCRIPTION "${ARG_DESCRIPTION}"
            CI_PLATFORMS "${ARG_CI_PLATFORMS}"
            CI_COMPILERS "${ARG_CI_COMPILERS}"
            CI_DEPLOY_DOCS "${ARG_CI_DEPLOY_DOCS}"
        )
    endif()
    
    # Build examples if specified
    if(PROJECT_IS_TOP_LEVEL AND ARG_EXAMPLES)
        foreach(example IN LISTS ARG_EXAMPLES)
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/example/${example}.cpp")
                string(REPLACE "${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
                
                # Check if this is a compile-fail test (has "_fail" in the name)
                string(FIND "${example}" "_fail" fail_pos)
                if(fail_pos GREATER -1)
                    # Negative compile test: this example must fail to compile
                    add_executable(${example} EXCLUDE_FROM_ALL "example/${example}.cpp")
                    target_link_libraries(${example} PRIVATE ${ARG_NAMESPACE}::${CLEAN_NAME})
                    add_test(
                        NAME compile_${example}
                        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target ${example}
                        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                    )
                    set_tests_properties(compile_${example} PROPERTIES WILL_FAIL TRUE)
                else()
                    # Regular example
                    add_executable(${example} "example/${example}.cpp")
                    target_link_libraries(${example} PRIVATE ${ARG_NAMESPACE}::${CLEAN_NAME})
                    add_test(NAME ${example} COMMAND ${example})
                endif()
            else()
                message(WARNING "Example file example/${example}.cpp not found")
            endif()
        endforeach()
    endif()
    
endfunction()
