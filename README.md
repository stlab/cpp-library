# cpp-library

[![License][license-badge]][license-link]

Modern CMake template for C++ libraries with comprehensive infrastructure.

[license-badge]: https://img.shields.io/badge/license-BSL%201.0-blue.svg
[license-link]: https://github.com/stlab/cpp-library/blob/main/LICENSE

## Overview

`cpp-library` provides a standardized CMake infrastructure template for C++ libraries. It eliminates boilerplate and provides consistent patterns for:

- **Project Declaration**: Uses existing `project()` declaration with automatic git tag-based versioning
- **Library Setup**: INTERFACE targets for header-only libraries, static/shared libraries for compiled libraries
- **Installation**: CMake package config generation with proper header and library installation
- **Testing**: Integrated [doctest](https://github.com/doctest/doctest) with CTest and compile-fail test support
- **Documentation**: [Doxygen](https://www.doxygen.nl/) with [doxygen-awesome-css](https://github.com/jothepro/doxygen-awesome-css) theme
- **Development Tools**: [clangd](https://clangd.llvm.org/) integration, CMakePresets.json, [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) support
- **CI/CD**: [GitHub Actions](https://docs.github.com/en/actions) workflows with multi-platform testing and installation verification
- **Dependency Management**: [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake) integration

## Quick Start

The easiest way to create a new library project using cpp-library is with the `setup.cmake` script. This interactive script will guide you through creating a new project with the correct structure, downloading dependencies, and generating all necessary files.

### Using setup.cmake

**Interactive mode:**

```bash
cmake -P <(curl -sSL https://raw.githubusercontent.com/stlab/cpp-library/main/setup.cmake)
```

Or download and run:

```bash
curl -O https://raw.githubusercontent.com/stlab/cpp-library/main/setup.cmake
cmake -P setup.cmake
```

The script will prompt you for:

- **Library name** (e.g., `my-library`)
- **Namespace** (e.g., `mycompany`)
- **Description**
- **Header-only library?** (yes/no)
- **Include examples?** (yes/no)
- **Include tests?** (yes/no)

**Non-interactive mode:**

```bash
cmake -P setup.cmake -- \
  --name=my-library \
  --namespace=mycompany \
  --description="My awesome library" \
  --header-only=yes \
  --examples=yes \
  --tests=yes
```

The script will:

1. Create the project directory structure
2. Download CPM.cmake
3. Generate CMakeLists.txt with correct configuration
4. Create template header files
5. Create example and test files (if requested)
6. Initialize a git repository

After setup completes:

```bash
cd my-library

# Generate template files (CMakePresets.json, CI workflows, etc.)
cmake -B build -DCPP_LIBRARY_FORCE_INIT=ON

# Now you can use the presets
cmake --preset=test
cmake --build --preset=test
ctest --preset=test
```

To regenerate template files later:

```bash
cmake --preset=init
cmake --build --preset=init
```

## Manual Setup

If you prefer to set up your project manually, or need to integrate cpp-library into an existing project, follow these steps.

### Usage

Use `CPMAddPackage` to fetch cpp-library directly in your `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.20)

# Project declaration - cpp_library_setup will use this name and detect version from git tags
project(your-library)

# Setup CPM
if(PROJECT_IS_TOP_LEVEL AND NOT CPM_SOURCE_CACHE AND NOT DEFINED ENV{CPM_SOURCE_CACHE})
    set(CPM_SOURCE_CACHE "${CMAKE_SOURCE_DIR}/.cache/cpm" CACHE PATH "CPM source cache")
    message(STATUS "Setting cpm cache dir to: ${CPM_SOURCE_CACHE}")
endif()
include(cmake/CPM.cmake)

# Fetch cpp-library via CPM
CPMAddPackage("gh:stlab/cpp-library@4.0.3")
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

### Getting Started

Before using cpp-library, you'll need:

- **CMake 3.20+** - [Download here](https://cmake.org/download/)
- **A C++17+ compiler** - GCC 7+, Clang 5+, MSVC 2017+, or Apple Clang 9+

#### Step 1: Install CPM.cmake

[CPM.cmake](https://github.com/cpm-cmake/CPM.cmake) is required for dependency management. [Add it to your project](https://github.com/cpm-cmake/CPM.cmake?tab=readme-ov-file#adding-cpm):

```bash
mkdir -p cmake
wget -O cmake/CPM.cmake https://github.com/cpm-cmake/CPM.cmake/releases/latest/download/get_cpm.cmake
```

Create the standard directory structure:

```bash
mkdir -p include/your_namespace examples tests
```

#### Step 2: Create your CMakeLists.txt

Create a `CMakeLists.txt` file following the example shown at the [beginning of the Usage section](#usage).

#### Step 3: Build and test

```bash
cmake --preset=test
cmake --build --preset=test
ctest --preset=test
```

### Consuming Libraries Built with cpp-library

#### Using CPMAddPackage (recommended)

The preferred way to consume a library built with cpp-library is via [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake):

```cmake
cmake_minimum_required(VERSION 3.20)
project(my-app)

include(cmake/CPM.cmake)

# Fetch the library directly from GitHub
# Note: Repository name must match the package name (including namespace prefix)
CPMAddPackage("gh:stlab/stlab-enum-ops@1.0.0")

add_executable(my-app main.cpp)
target_link_libraries(my-app PRIVATE stlab::enum-ops)
```

The library will be automatically fetched and built as part of your project.

**Important:** For CPM compatibility, especially with `CPM_USE_LOCAL_PACKAGES`, your GitHub repository name should match the package name. For a library with package name `stlab-enum-ops`, name your repository `stlab/stlab-enum-ops`, not `stlab/enum-ops`. This ensures CPM's abbreviated syntax works correctly with both source fetching and local package finding.

#### Installation (optional)

Installation is optional and typically not required when using CPM. If you need to install your library (e.g., for system-wide deployment or use with a package manager) use:

```bash
# Build and install to default system location
cmake --preset=default
cmake --build --preset=default
cmake --install build/default

# Install to custom prefix
cmake --install build/default --prefix /opt/mylib
```

For information about using installed packages with `find_package()`, see the [CPM.cmake documentation](https://github.com/cpm-cmake/CPM.cmake) about [controlling how dependencies are found](https://github.com/cpm-cmake/CPM.cmake#cpm_use_local_packages).

#### Dependency Handling in Installed Packages

cpp-library automatically generates correct `find_dependency()` calls in the installed CMake package configuration files by introspecting your target's `INTERFACE_LINK_LIBRARIES`. This ensures downstream users can find and link all required dependencies.

**How it works:**

When you link dependencies to your target using `target_link_libraries()`, cpp-library analyzes these links during installation and generates appropriate `find_dependency()` calls. For example:

```cmake
# In your library's CMakeLists.txt
add_library(my-lib INTERFACE)

# Link dependencies - these will be automatically handled during installation
target_link_libraries(my-lib INTERFACE
    stlab::copy-on-write    # Internal CPM dependency
    stlab::enum-ops         # Internal CPM dependency
    Threads::Threads        # System dependency
)
```

When installed, the generated `my-libConfig.cmake` will include:

```cmake
include(CMakeFindDependencyMacro)

# Find dependencies required by this package
find_dependency(stlab-copy-on-write)
find_dependency(stlab-enum-ops)
find_dependency(Threads)

include("${CMAKE_CURRENT_LIST_DIR}/my-libTargets.cmake")
```

**Default dependency handling:**

- **cpp-library dependencies** (matching your project's `NAMESPACE`):
  - When namespace and component match: `namespace::namespace` → `find_dependency(namespace)`
  - When they differ: `namespace::component` → `find_dependency(namespace-component)`
  - Example: `stlab::copy-on-write` → `find_dependency(stlab-copy-on-write)`
- **Other packages**: Uses the package name only by default
  - Example: `Threads::Threads` → `find_dependency(Threads)`
  - Example: `Boost::filesystem` → `find_dependency(Boost)`

**Custom dependency mappings:**

For dependencies that require special `find_dependency()` syntax (e.g., Qt with COMPONENTS), use `cpp_library_map_dependency()` to specify the exact call:

```cmake
# Map Qt components to use COMPONENTS syntax
cpp_library_map_dependency("Qt5::Core" "Qt5 COMPONENTS Core")
cpp_library_map_dependency("Qt5::Widgets" "Qt5 COMPONENTS Widgets")

# Then link as usual
target_link_libraries(my-lib INTERFACE
    Qt5::Core
    Qt5::Widgets
    Threads::Threads  # Works automatically, no mapping needed
)
```

The generated config file will use your custom mappings where specified:

```cmake
find_dependency(Qt5 COMPONENTS Core)
find_dependency(Qt5 COMPONENTS Widgets)
find_dependency(Threads)  # Automatic from Threads::Threads
```

### Updating cpp-library

To update to the latest version of cpp-library in your project:

#### Step 1: Update the version in CMakeLists.txt

Change the version tag in your `CPMAddPackage` call:

```cmake
CPMAddPackage("gh:stlab/cpp-library@4.1.0")  # Update version here
```

#### Step 2: Regenerate template files

Use the `init` preset to regenerate `CMakePresets.json` and CI workflows with the latest templates:

```bash
cmake --preset=init
cmake --build --preset=init
```

This ensures your project uses the latest presets and CI configurations from the updated cpp-library version.

### Setting Up GitHub Repository

#### Repository Naming

**Critical:** Your GitHub repository name must match your package name for CPM compatibility.

For the recommended pattern (`project(enum-ops)` with `NAMESPACE stlab`):

- Package name will be: `stlab-enum-ops`
- Repository should be: `github.com/stlab/stlab-enum-ops`

This ensures `CPMAddPackage("gh:stlab/stlab-enum-ops@1.0.0")` works correctly with both source builds and `CPM_USE_LOCAL_PACKAGES`.

#### Version Tagging

cpp-library automatically detects your library version from git tags. To version your library:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Tags should follow [semantic versioning](https://semver.org/) (e.g., `v1.0.0`, `v2.1.3`).

Alternatively, you can override the version using `-DCPP_LIBRARY_VERSION=x.y.z` (useful for package managers). See [Version Management](#version-management) for details.

#### GitHub Pages Deployment

To enable automatic documentation deployment to GitHub Pages:

1. Go to your repository **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**
3. Push a commit to trigger the CI workflow

Your documentation will be automatically built and deployed to `https://your-org.github.io/your-library/` on every push to the main branch.

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

**Notes:**

- The project name is automatically taken from `PROJECT_NAME` (set by the `project()` command). You must call `project(your-library)` before `cpp_library_setup()`.
- Version is automatically detected from git tags, or can be overridden with `-DCPP_LIBRARY_VERSION=x.y.z` (see [Version Management](#version-management)).
- Examples using doctest should include `test` in the filename to be visible in the [C++ TestMate](https://marketplace.visualstudio.com/items?itemName=matepek.vscode-catch2-test-adapter) extension for VS Code test explorer.

### Target Naming

**Recommended Pattern** (collision-safe):

Use the component name as your project name, and specify the organizational namespace separately:

```cmake
project(enum-ops)  # Component name only

cpp_library_setup(
    NAMESPACE stlab  # Organizational namespace
    # ...
)
```

This produces:

- Target name: `enum-ops`
- Package name: `stlab-enum-ops` (used in `find_package(stlab-enum-ops)`)
- Target alias: `stlab::enum-ops` (used in `target_link_libraries()`)
- GitHub repository should be named: `stlab/stlab-enum-ops` (for CPM compatibility)

**Alternative Patterns:**

You can also use `project(namespace-component)` - the namespace prefix will be detected and stripped from the target alias:

```cmake
project(stlab-enum-ops)  # Includes namespace prefix

cpp_library_setup(
    NAMESPACE stlab
    # ...
)
```

Produces the same result as above.

**Single-component namespace** (e.g., `project(stlab)` with `NAMESPACE stlab`):

- Target name: `stlab`
- Package name: `stlab` (used in `find_package(stlab)`)
- Target alias: `stlab::stlab` (used in `target_link_libraries()`)

All package names include the namespace prefix for collision prevention.

### `cpp_library_map_dependency`

```cmake
cpp_library_map_dependency(target find_dependency_call)
```

Registers a custom dependency mapping for `find_dependency()` generation in installed CMake package config files.

**Parameters:**

- `target`: The namespaced target (e.g., `"Qt5::Core"`, `"Threads::Threads"`)
- `find_dependency_call`: The exact arguments to pass to `find_dependency()` (e.g., `"Qt5 COMPONENTS Core"`, `"Threads"`)

**When to use:**

- Dependencies requiring `COMPONENTS` syntax (e.g., Qt)
- Dependencies requiring `OPTIONAL_COMPONENTS` or other special arguments
- Dependencies where the target name pattern doesn't match the desired `find_dependency()` call

**Note:** Most common dependencies like `Threads::Threads`, `Boost::filesystem`, etc. work automatically with the default behavior and don't need mapping.

**Example:**

```cmake
# Register mappings for dependencies needing special syntax
cpp_library_map_dependency("Qt5::Core" "Qt5 COMPONENTS Core")
cpp_library_map_dependency("Qt5::Widgets" "Qt5 COMPONENTS Widgets")

# Then link normally
target_link_libraries(my-target INTERFACE
    Qt5::Core
    Qt5::Widgets
    Threads::Threads  # No mapping needed
)
```

See [Dependency Handling in Installed Packages](#dependency-handling-in-installed-packages) for more details.

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

Libraries with sources build as static libraries by default. Set `BUILD_SHARED_LIBS=ON` to build shared libraries instead.

## Reference

### CMake Presets

cpp-library generates a `CMakePresets.json` file with the following configurations:

- **`default`**: Release build for production use
- **`test`**: Debug build with testing enabled
- **`docs`**: Documentation generation with Doxygen
- **`clang-tidy`**: Static analysis build
- **`install`**: Local installation test (installs to `build/install/prefix`)
- **`init`**: Template regeneration (regenerates CMakePresets.json, CI workflows, etc.)

### Version Management

Version is automatically detected from git tags:

- Supports `v1.2.3` and `1.2.3` tag formats
- Falls back to `0.0.0` if no tag is found (with warning)
- Version used in CMake package config files

For package managers or CI systems building from source archives without git history, you can override the version using the `CPP_LIBRARY_VERSION` cache variable:

```bash
cmake -DCPP_LIBRARY_VERSION=1.2.3 -B build
cmake --build build
```

This is particularly useful for vcpkg, Conan, or other package managers that don't have access to git tags.

### Testing

- **Test framework**: [doctest](https://github.com/doctest/doctest)
- **Compile-fail tests**: Automatically detected via `_fail` suffix in filenames
- **Test discovery**: Scans `tests/` and `examples/` directories
- **CTest integration**: All tests registered with CTest for IDE integration

## Template Files Generated

cpp-library automatically generates infrastructure files on first configuration and when using the `init` preset:

- **CMakePresets.json**: Build configurations (default, test, docs, clang-tidy, install, init)
- **.github/workflows/ci.yml**: Multi-platform CI/CD pipeline with testing and documentation deployment
- **.gitignore**: Standard C++ project ignores
- **.vscode/extensions.json**: Recommended VS Code extensions
- **Package config files**: `<Package>Config.cmake` for CMake integration (when building as top-level project)

These files are generated automatically. To regenerate with the latest templates, use `cmake --preset=init`.

## Example Projects

See these projects using cpp-library:

- [stlab/stlab-enum-ops](https://github.com/stlab/stlab-enum-ops) - Type-safe operators for enums
- [stlab/stlab-copy-on-write](https://github.com/stlab/stlab-copy-on-write) - Copy-on-write wrapper

Note: Repository names include the namespace prefix for CPM compatibility and collision prevention.

## License

Distributed under the Boost Software License, Version 1.0. See `LICENSE`.
