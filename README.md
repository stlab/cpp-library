# cpp-library

[![License][license-badge]][license-link]

Modern CMake template for C++ header-only libraries with common infrastructure.

[license-badge]: https://img.shields.io/badge/license-BSL%201.0-blue.svg
[license-link]: https://github.com/stlab/cpp-library/blob/main/LICENSE

## Overview

`cpp-library` provides a standardized CMake infrastructure template for header-only C++ libraries. It eliminates boilerplate and provides consistent patterns for:

- **Library Setup**: INTERFACE targets with proper installation
- **Testing**: Integrated doctest with CTest
- **Documentation**: Doxygen with doxygen-awesome-css theme
- **Development Tools**: clangd integration, CMakePresets.json
- **Dependency Management**: CPM.cmake integration

## Usage

Use CPMAddPackage to fetch cpp-library directly in your CMakeLists.txt:

```cmake
cmake_minimum_required(VERSION 3.20)
project(your-library VERSION 1.0.0 DESCRIPTION "Your library description" LANGUAGES CXX)

# Only setup full infrastructure when building as top-level project
if(PROJECT_IS_TOP_LEVEL)
    set(CPM_SOURCE_CACHE ${CMAKE_SOURCE_DIR}/.cpm-cache CACHE PATH "CPM cache")
    include(cmake/CPM.cmake)
    
    # Fetch cpp-library via CPM
    CPMAddPackage("gh:stlab/cpp-library@1.0.0")
    include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)
    
    cpp_library_setup(
        NAME your-library
        VERSION ${PROJECT_VERSION}
        DESCRIPTION "${PROJECT_DESCRIPTION}"
        NAMESPACE your_namespace
        HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/include/your_namespace/your_header.hpp
        EXAMPLES your_example
        TESTS your_tests
        DOCS_EXCLUDE_SYMBOLS "your_namespace::implementation"
    )
else()
    # Lightweight consumer mode - just create the library target
    add_library(your-library INTERFACE)
    add_library(your_namespace::your-library ALIAS your-library)
    target_include_directories(your-library INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>)
    target_compile_features(your-library INTERFACE cxx_std_17)
endif()
```

### Prerequisites

- **CPM.cmake**: Must be included before using cpp-library
- **CMake 3.20+**: Required for modern CMake features
- **C++17+**: Default requirement (configurable)

## API Reference

### `cpp_library_setup`

```cmake
cpp_library_setup(
    # Required parameters
    NAME project_name              # e.g., "stlab-enum-ops"
    VERSION version_string         # e.g., "1.0.0" 
    DESCRIPTION description        # e.g., "Type-safe operators for enums"
    NAMESPACE namespace            # e.g., "stlab"
    
    # Header specification (one required)
    HEADERS header_list            # List of header files
    HEADER_DIR directory           # Directory to install recursively
    
    # Optional features
    [EXAMPLES example_list]        # Example executables to build
    [TESTS test_list]             # Test executables to build  
    [DOCS_EXCLUDE_SYMBOLS symbols] # Symbols to exclude from docs
    [REQUIRES_CPP_VERSION 17|20|23] # C++ version (default: 17)
    [ADDITIONAL_DEPS dep_list]     # Extra CPM dependencies
    [CUSTOM_INSTALL]              # Skip default installation
    [NO_PRESETS]                  # Skip CMakePresets.json generation
)
```

## Features

### Automated Infrastructure

- **CMakePresets.json**: Generates standard presets (default, test, docs)
- **Installation**: Modern CMake package config with FILE_SET headers
- **Testing**: doctest integration with CTest
- **Documentation**: Doxygen with doxygen-awesome-css theme
- **Development**: clangd compile_commands.json symlink
- **Compile-fail tests**: Automatic detection for examples with `_fail` suffix

### Smart Defaults

- **C++17** standard requirement (configurable)
- **Ninja** generator in presets  
- **Debug** builds for testing, **Release** for default
- **Build isolation** with separate build directories
- **Two-mode operation**: Full infrastructure when top-level, lightweight when consumed

### Dependency Management

- **CPM.cmake** integration for seamless fetching
- **Automatic caching** via CPM's built-in mechanisms
- **doctest@2.4.12** for testing
- **doxygen-awesome-css@2.3.4** for documentation
- **Git tag versioning** for reliable updates

## Example Projects

This template is used by:

- [stlab/enum-ops](https://github.com/stlab/enum-ops) - Type-safe operators for enums
- [stlab/copy-on-write](https://github.com/stlab/copy-on-write) - Copy-on-write wrapper

### Real Usage Example (enum-ops)

```cmake
cmake_minimum_required(VERSION 3.20)
project(stlab-enum-ops VERSION 1.0.0 DESCRIPTION "Type-safe operators for enums" LANGUAGES CXX)

if(PROJECT_IS_TOP_LEVEL)
    set(CPM_SOURCE_CACHE ${CMAKE_SOURCE_DIR}/.cpm-cache CACHE PATH "CPM cache")
    include(cmake/CPM.cmake)
    
    CPMAddPackage("gh:stlab/cpp-library@1.0.0")
    include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)
    
    cpp_library_setup(
        NAME stlab-enum-ops
        VERSION ${PROJECT_VERSION}
        DESCRIPTION "${PROJECT_DESCRIPTION}"
        NAMESPACE stlab
        HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/include/stlab/enum_ops.hpp
        EXAMPLES enum_ops_example enum_ops_example_fail
        TESTS enum_ops_all_tests
        DOCS_EXCLUDE_SYMBOLS "stlab::implementation"
    )
else()
    add_library(stlab-enum-ops INTERFACE)
    add_library(stlab::enum-ops ALIAS stlab-enum-ops)
    target_include_directories(stlab-enum-ops INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>)
    target_compile_features(stlab-enum-ops INTERFACE cxx_std_17)
endif()
```

**Result**: 76 lines of CMake boilerplate reduced to 24 lines (68% reduction)!

## License

Distributed under the Boost Software License, Version 1.0. See `LICENSE`.
