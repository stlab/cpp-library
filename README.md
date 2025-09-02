# cpp-library

[![License][license-badge]][license-link]

Modern CMake template for C++ libraries with comprehensive infrastructure.

[license-badge]: https://img.shields.io/badge/license-BSL%201.0-blue.svg
[license-link]: https://github.com/stlab/cpp-library/blob/main/LICENSE

## Overview

`cpp-library` provides a standardized CMake infrastructure template for C++ libraries. It eliminates boilerplate and provides consistent patterns for:

- **Project Declaration**: Uses existing `project()` declaration with automatic git tag-based versioning
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

# Project declaration - cpp_library_setup will use this name and detect version from git tags
project(your-library)

set(CPM_SOURCE_CACHE ${CMAKE_SOURCE_DIR}/.cache/cpm CACHE PATH "CPM cache")
include(cmake/CPM.cmake)

# Fetch cpp-library via CPM
CPMAddPackage("gh:stlab/cpp-library@4.0.1")
include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)

cpp_library_setup(
    DESCRIPTION "Your library description"
    NAMESPACE your_namespace
    HEADERS your_header.hpp
    # Add SOURCES for non-header-only libraries (omit for header-only)
    SOURCES your_library.cpp
    EXAMPLES your_example.cpp your_example_fail.cpp
    TESTS your_tests.cpp
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
    DESCRIPTION description        # e.g., "Type-safe operators for enums"
    NAMESPACE namespace            # e.g., "stlab"
    HEADERS header_list            # List of header filenames (e.g., "your_header.hpp")
    
    # Source specification for non-header-only libraries
    SOURCES source_list            # List of source filenames (e.g., "your_library.cpp", omit for header-only libraries)

    # Optional features
    [EXAMPLES example_list]        # Example source files to build (e.g., "example.cpp example_fail.cpp")
    [TESTS test_list]              # Test source files to build (e.g., "tests.cpp")  
    [DOCS_EXCLUDE_SYMBOLS symbols] # Symbols to exclude from docs
    [REQUIRES_CPP_VERSION 17|20|23] # C++ version (default: 17)
)
```

**Note**: The project name is automatically taken from `PROJECT_NAME` (set by the `project()`
command). You must call `project(your-library)` before `cpp_library_setup()`. Version is
automatically detected from git tags.

**NOTE**: Examples using doctest should have `test` in the name if you want them to be visible in
the TestMate test explorer.

### Template Regeneration

To force regeneration of template files (CMakePresets.json, CI workflows, etc.), you can use the `init` preset:

```bash
cmake --preset=init
cmake --build --preset=init
```

Alternatively, you can set the CMake variable `CPP_LIBRARY_FORCE_INIT` to `ON`:

```bash
cmake -DCPP_LIBRARY_FORCE_INIT=ON -B build/init
```

This will regenerate all template files, overwriting any existing ones.

### Path Conventions

The template uses consistent path conventions for all file specifications:

- **HEADERS**: Filenames only, automatically placed in `include/<namespace>/` directory
  - Examples: `your_header.hpp`, `enum_ops.hpp` (automatically becomes `include/your_namespace/your_header.hpp`)
- **SOURCES**: Filenames only, automatically placed in `src/` directory (omit for header-only libraries)
  - Examples: `your_library.cpp`, `implementation.cpp` (automatically becomes `src/your_library.cpp`)
- **EXAMPLES**: Source files with `.cpp` extension, located in `examples/` directory
  - Examples: `example.cpp`, `example_fail.cpp`
- **TESTS**: Source files with `.cpp` extension, located in `tests/` directory
  - Examples: `tests.cpp`, `unit_tests.cpp`

The template automatically generates the full paths based on these conventions. HEADERS are placed in `include/<namespace>/` and SOURCES are placed in `src/`.

### Library Types

**Header-only libraries**: Specify only `HEADERS`, omit `SOURCES`
```cmake
cpp_library_setup(
    DESCRIPTION "Header-only library"
    NAMESPACE my_lib
    HEADERS my_header.hpp
    # No SOURCES needed for header-only
)
```

**Non-header-only libraries**: Specify both `HEADERS` and `SOURCES`
```cmake
cpp_library_setup(
    DESCRIPTION "Library with implementation"
    NAMESPACE my_lib
    HEADERS my_header.hpp
    SOURCES my_library.cpp implementation.cpp
)
```

## Features
### Non-Header-Only Library Support

- **Non-header-only library support**: For libraries with source files, specify them explicitly with the `SOURCES` argument as filenames (e.g., `"your_library.cpp"`).
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
- **Automatic version detection**: Version is automatically extracted from git tags (e.g., `v1.2.3` becomes `1.2.3`)
- **Always-enabled features**: CI/CD, CMakePresets.json, and proper installation are always generated

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
  - `init`: Template regeneration (forces regeneration of CMakePresets.json, CI workflows, etc.)

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

### Version Management

- **Automatic git tag detection**: Version is automatically extracted from the latest git tag
- **Fallback versioning**: Uses `0.0.0` if no git tag is found (with warning)
- **Tag format support**: Supports both `v1.2.3` and `1.2.3` tag formats

## Example Projects

This template is used by:

- [stlab/enum-ops](https://github.com/stlab/enum-ops) - Type-safe operators for enums
- [stlab/copy-on-write](https://github.com/stlab/copy-on-write) - Copy-on-write wrapper

### Real Usage Example (enum-ops)

```cmake
cmake_minimum_required(VERSION 3.20)
project(enum-ops)

# Setup cpp-library infrastructure
set(CPM_SOURCE_CACHE ${CMAKE_SOURCE_DIR}/.cache/cpm CACHE PATH "CPM cache" FORCE)
include(cmake/CPM.cmake)

# Fetch cpp-library via CPM
CPMAddPackage("gh:stlab/cpp-library@4.0.1")
include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)

# Configure library (handles both lightweight and full modes automatically)
cpp_library_setup(
    DESCRIPTION "Type-safe operators for enums"
    NAMESPACE stlab
    HEADERS enum_ops.hpp
    EXAMPLES enum_ops_example_test.cpp enum_ops_example_fail.cpp
    TESTS enum_ops_tests.cpp
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

4. **Add examples** to `examples/` (use `_fail` suffix for compile-fail tests, e.g., `example.cpp`, `example_fail.cpp`)

5. **Add tests** to `tests/` (use `_fail` suffix for compile-fail tests, e.g., `tests.cpp`, `tests_fail.cpp`)

6. **Build and test**:
   ```bash
   cmake --preset=test
   cmake --build --preset=test
   ctest --preset=test
   ```

7. **Regenerate templates** (if needed):
   ```bash
   cmake --preset=init
   cmake --build --preset=init
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
