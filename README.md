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

Include in your project similar to how CPM.cmake is included:

### Option 1: Download and Cache (Recommended)

Create `cmake/cpp-library.cmake` in your project:

```cmake
# SPDX-License-Identifier: BSL-1.0

set(CPP_LIBRARY_VERSION 1.0.0)
set(CPP_LIBRARY_HASH_SUM "...")  # SHA256 of the release

if(CPP_LIBRARY_CACHE)
  set(CPP_LIBRARY_LOCATION "${CPP_LIBRARY_CACHE}/cpp-library/cpp-library_${CPP_LIBRARY_VERSION}.cmake")
elseif(DEFINED ENV{CPP_LIBRARY_CACHE})
  set(CPP_LIBRARY_LOCATION "$ENV{CPP_LIBRARY_CACHE}/cpp-library/cpp-library_${CPP_LIBRARY_VERSION}.cmake")
else()
  set(CPP_LIBRARY_LOCATION "${CMAKE_BINARY_DIR}/cmake/cpp-library_${CPP_LIBRARY_VERSION}.cmake")
endif()

get_filename_component(CPP_LIBRARY_LOCATION ${CPP_LIBRARY_LOCATION} ABSOLUTE)

file(DOWNLOAD
     https://github.com/stlab/cpp-library/releases/download/v${CPP_LIBRARY_VERSION}/cpp-library.cmake
     ${CPP_LIBRARY_LOCATION} EXPECTED_HASH SHA256=${CPP_LIBRARY_HASH_SUM}
)

include(${CPP_LIBRARY_LOCATION})
```

### Then in your CMakeLists.txt:

```cmake
cmake_minimum_required(VERSION 3.20)
project(your-library VERSION 1.0.0 DESCRIPTION "Your library description" LANGUAGES CXX)

# Only setup full infrastructure when building as top-level project
if(PROJECT_IS_TOP_LEVEL)
    set(CPP_LIBRARY_CACHE ${CMAKE_SOURCE_DIR}/.cpp-library-cache CACHE PATH "Directory to cache cpp-library packages" FORCE)
    include(cmake/cpp-library.cmake)
    
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

### Smart Defaults

- **C++17** standard requirement (configurable)
- **Ninja** generator in presets  
- **Debug** builds for testing, **Release** for default
- **Build isolation** with separate build directories

### Dependency Management

- **CPM.cmake** for dependency management
- **Caching** to avoid re-downloading dependencies
- **doctest@2.4.12** for testing
- **doxygen-awesome-css@2.3.4** for documentation

## Example Projects

This template is used by:

- [stlab/enum-ops](https://github.com/stlab/enum-ops)
- [stlab/copy-on-write](https://github.com/stlab/copy-on-write)

## License

Distributed under the Boost Software License, Version 1.0. See `LICENSE`.
