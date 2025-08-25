# cpp-library

[![License][license-badge]][license-link]

Modern CMake template for C++ header-only libraries with comprehensive infrastructure.

[license-badge]: https://img.shields.io/badge/license-BSL%201.0-blue.svg
[license-link]: https://github.com/stlab/cpp-library/blob/main/LICENSE

## Overview

`cpp-library` provides a standardized CMake infrastructure template for header-only C++ libraries. It eliminates boilerplate and provides consistent patterns for:

- **Library Setup**: INTERFACE targets with proper installation and package config
- **Testing**: Integrated doctest with CTest and compile-fail test support
- **Documentation**: Doxygen with doxygen-awesome-css theme
- **Development Tools**: clangd integration, CMakePresets.json, clang-tidy support
- **CI/CD**: GitHub Actions workflows with multi-platform testing
- **Dependency Management**: CPM.cmake integration

## Usage

Use CPMAddPackage to fetch cpp-library directly in your CMakeLists.txt:

```cmake
cmake_minimum_required(VERSION 3.20)
project(your-library VERSION 1.0.0 DESCRIPTION "Your library description" LANGUAGES CXX)

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
    # Optional: add SOURCES for non-header-only libraries
    SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/your_library.cpp
    EXAMPLES your_example your_example_fail
    TESTS your_tests
    DOCS_EXCLUDE_SYMBOLS "your_namespace::implementation"
)
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

    # Optional: source specification for non-header-only libraries
    SOURCES source_list            # List of source files (e.g., src/*.cpp)

    # Optional features
    [EXAMPLES example_list]        # Example executables to build
    [TESTS test_list]              # Test executables to build  
    [DOCS_EXCLUDE_SYMBOLS symbols] # Symbols to exclude from docs
    [REQUIRES_CPP_VERSION 17|20|23] # C++ version (default: 17)
    [ADDITIONAL_DEPS dep_list]     # Extra CPM dependencies

    # Optional flags
    [CUSTOM_INSTALL]              # Skip default installation
    [NO_PRESETS]                  # Skip CMakePresets.json generation
    [NO_CI]                       # Skip CI generation (enabled by default)
    [FORCE_INIT]                  # Force regeneration of template files
)
```

## Features
### Non-Header-Only Library Support

- **Automatic detection of sources in `src/`**: If source files are present in `src/`, the template will build a regular (static) library instead of header-only INTERFACE target.
    Specify sources manually with the `SOURCES` argument, or let the template auto-detect files in `src/`.
    Both header-only and compiled libraries are supported seamlessly.

### Automated Infrastructure

- **CMakePresets.json**: Generates standard presets (default, test, docs, clang-tidy, init)
- **Installation**: Modern CMake package config with FILE_SET headers
- **Testing**: doctest integration with CTest and compile-fail test support
- **Documentation**: Doxygen with doxygen-awesome-css theme
- **Development**: clangd compile_commands.json symlink
- **CI/CD**: GitHub Actions workflows with multi-platform testing and documentation deployment

### Smart Defaults

- **C++17** standard requirement (configurable)
- **Ninja** generator in presets  
- **Debug** builds for testing, **Release** for default
- **Build isolation** with separate build directories
- **Two-mode operation**: Full infrastructure when top-level, lightweight when consumed

### Testing Features

- **doctest@2.4.12** for unit testing
- **Compile-fail tests**: Automatic detection for examples with `_fail` suffix
- **CTest integration**: Proper test registration and labeling
- **Multi-directory support**: Checks both `tests/` directories

### Documentation Features

- **Doxygen integration** with modern configuration
- **doxygen-awesome-css@2.3.4** theme for beautiful output
- **Symbol exclusion** support for implementation details
- **GitHub Pages deployment** via CI
- **Custom Doxyfile support** (falls back to template)

### Development Tools

- **clang-tidy integration** via CMakePresets.json
- **clangd support** with compile_commands.json symlink
- **CMakePresets.json** with multiple configurations:
  - `default`: Release build
  - `test`: Debug build with testing
  - `docs`: Documentation generation
  - `clang-tidy`: Static analysis
  - `init`: Template regeneration

### CI/CD Features

- **Multi-platform testing**: Ubuntu, macOS, Windows
- **Multi-compiler support**: GCC, Clang, MSVC
- **Static analysis**: clang-tidy integration
- **Documentation deployment**: Automatic GitHub Pages deployment
- **Template generation**: CI workflow generation

### Dependency Management

- **CPM.cmake** integration for seamless fetching
- **Automatic caching** via CPM's built-in mechanisms
- **Version pinning** for reliable builds
- **Git tag versioning** for reliable updates

## Example Projects

This template is used by:

- [stlab/enum-ops](https://github.com/stlab/enum-ops) - Type-safe operators for enums
- [stlab/copy-on-write](https://github.com/stlab/copy-on-write) - Copy-on-write wrapper

### Real Usage Example (enum-ops)

```cmake
cmake_minimum_required(VERSION 3.20)
project(stlab-enum-ops VERSION 1.0.0 DESCRIPTION "Type-safe operators for enums" LANGUAGES CXX)

# Setup cpp-library infrastructure
set(CPM_SOURCE_CACHE ${CMAKE_SOURCE_DIR}/.cpm-cache CACHE PATH "CPM cache" FORCE)
include(cmake/CPM.cmake)

# Fetch cpp-library via CPM (using local path for development)
CPMAddPackage(
    URI gh:stlab/cpp-library@1.0.0
    DOWNLOAD_ONLY YES
)
include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)

# Configure library (handles both lightweight and full modes automatically)
cpp_library_setup(
    NAME stlab-enum-ops
    VERSION ${PROJECT_VERSION}
    DESCRIPTION "${PROJECT_DESCRIPTION}"
    NAMESPACE stlab
    HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/include/stlab/enum_ops.hpp
    EXAMPLES enum_ops_example enum_ops_example_fail
    TESTS enum_ops_tests
    DOCS_EXCLUDE_SYMBOLS "stlab::implementation"
)
```

## Quick Start

1. **Initialize a new project**:
   ```bash
   # Clone or create your project
   mkdir my-library && cd my-library
   
    # Create basic structure
    mkdir -p include/your_namespace src examples tests cmake
   
   # Add CPM.cmake
   curl -L https://github.com/cpm-cmake/CPM.cmake/releases/latest/download/get_cpm.cmake -o cmake/CPM.cmake
   ```

2. **Create CMakeLists.txt** with the usage example above

3. **Add your headers** to `include/your_namespace/`

4. **Add examples** to `examples/` (use `_fail` suffix for compile-fail tests)

5. **Add tests** to `tests/`

6. **Build and test**:
   ```bash
   cmake --preset=test
   cmake --build --preset=test
   ctest --preset=test
   ```

## Template Files Generated

The template automatically generates:

 - **CMakePresets.json**: Build configurations for different purposes
 - **.github/workflows/ci.yml**: Multi-platform CI/CD pipeline
 - **.gitignore**: Standard ignores for C++ projects
 - **src/**: Source directory for non-header-only libraries (auto-detected)
 - **Package config files**: For proper CMake integration

## License

Distributed under the Boost Software License, Version 1.0. See `LICENSE`.
