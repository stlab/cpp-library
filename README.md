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
cmake_minimum_required(VERSION 3.24)

include(cmake/CPM.cmake)

# Fetch cpp-library before project()
# Check https://github.com/stlab/cpp-library/releases for the latest version
CPMAddPackage("gh:stlab/cpp-library@X.Y.Z")
include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)

# Enable dependency tracking before project()
cpp_library_enable_dependency_tracking()

# Now declare project
project(your-library)

# Enable testing infrastructure (required for TESTS and EXAMPLES)
include(CTest)

# Setup library
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

**Requirements:** CMake 3.24+, C++17+ compiler (GCC 7+, Clang 5+, MSVC 2017+, or Apple Clang 9+)

### Consuming Libraries Built with cpp-library

#### Using CPMAddPackage (recommended)

The preferred way to consume a library built with cpp-library is via [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake):

```cmake
cmake_minimum_required(VERSION 3.24)
project(my-app)

include(cmake/CPM.cmake)

# Fetch the library directly from GitHub
# Note: Repository name must match the package name (including namespace prefix)
CPMAddPackage("gh:stlab/stlab-enum-ops@1.0.0")

add_executable(my-app main.cpp)
target_link_libraries(my-app PRIVATE stlab::enum-ops)
```

The library will be automatically fetched and built as part of your project.

**Repository Naming:** Your GitHub repository name must match the package name for CPM compatibility (see [Target Naming](#target-naming) for details).

#### Installation (optional)

Installation is optional and typically not required when using CPM. If you need to install your library (e.g., for system-wide deployment or use with a package manager):

```bash
# Build and install to default system location
cmake --preset=install
cmake --build --preset=install
cmake --install build/install

# Install to custom prefix
cmake --install build/install --prefix /opt/mylib
```
The `install` preset enables `CPM_USE_LOCAL_PACKAGES`, which verifies your generated Config.cmake works correctly. See the [CPM.cmake documentation](https://github.com/cpm-cmake/CPM.cmake#cpm_use_local_packages) for more about using installed packages.

**Controlling installation**: The `${NAMESPACE}_INSTALL` option controls whether installation is enabled (defaults to `PROJECT_IS_TOP_LEVEL`). Use `-D${NAMESPACE}_INSTALL=ON/OFF` to override:

```bash
cmake -DSTLAB_INSTALL=OFF -B build  # Disable install for top-level project
cmake -DSTLAB_INSTALL=ON -B build   # Enable install for non-top-level (e.g., via CPM)
```

**Re-exporting CPM dependencies:** When re-exporting dependencies from `CPMAddPackage`, wrap them in `BUILD_INTERFACE` to avoid export errors (CPM creates non-IMPORTED targets that can't be exported):

```cmake
CPMAddPackage("gh:other-org/some-package@1.0.0")
target_link_libraries(my-library INTERFACE $<BUILD_INTERFACE:other::package>)
```

cpp-library automatically extracts these and generates appropriate `find_dependency()` calls. Dependencies from `find_package()` and system libraries don't need `BUILD_INTERFACE`.

#### Dependency Handling in Installed Packages

cpp-library automatically generates `find_dependency()` calls in the installed CMake package configuration. Call `cpp_library_enable_dependency_tracking()` before `project()`:

```cmake
cmake_minimum_required(VERSION 3.24)
include(cmake/CPM.cmake)

CPMAddPackage("gh:stlab/cpp-library@X.Y.Z")
include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)

cpp_library_enable_dependency_tracking()
project(my-library)

include(CTest)  # Required if you have TESTS or EXAMPLES

cpp_library_setup(
    DESCRIPTION "My library"
    NAMESPACE mylib
    HEADERS mylib.hpp
    TESTS my_tests.cpp        # Optional
    EXAMPLES my_example.cpp   # Optional
)

# Add dependencies - automatically tracked and included in Config.cmake
CPMAddPackage("gh:stlab/stlab-enum-ops@1.0.0")
find_package(Boost 1.79 COMPONENTS filesystem)

target_link_libraries(my-library INTERFACE
    stlab::enum-ops
    Boost::filesystem
)
```

**Non-namespaced targets:** For targets like `opencv_core` where the package name cannot be inferred, add explicit mapping:

```cmake
find_package(OpenCV 4.5.0 REQUIRED)
cpp_library_map_dependency("opencv_core" "OpenCV 4.5.0")
target_link_libraries(my-library INTERFACE opencv_core)
```

### Updating cpp-library

To update to a newer version:

1. Change the version in your `CPMAddPackage` call: `CPMAddPackage("gh:stlab/cpp-library@X.Y.Z")`
2. Regenerate template files: `cmake --preset=init && cmake --build --preset=init`

### Setting Up GitHub Repository

#### Repository Naming

**Critical:** Your GitHub repository name must match your package name for CPM compatibility. When using `project(enum-ops)` with `NAMESPACE stlab`, the package name is `stlab-enum-ops`, so your repository must be `stlab/stlab-enum-ops`. This prevents collisions and ensures `CPMAddPackage("gh:stlab/stlab-enum-ops@1.0.0")` works with both source builds and `CPM_USE_LOCAL_PACKAGES`.

#### Version Tagging

cpp-library automatically detects your library version from git tags following [semantic versioning](https://semver.org/):

```bash
git tag v1.0.0
git push origin v1.0.0
```

See [Version Management](#version-management) for override options.

#### GitHub Pages Deployment

To enable automatic documentation deployment to GitHub Pages:

1. Go to your repository **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**
3. Publish a release to trigger documentation build

Your documentation will be automatically built and deployed to `https://your-org.github.io/your-library/` when you publish a GitHub release.

## API Reference

### `cpp_library_set_version`

```cmake
cpp_library_set_version()
```

Updates the project version from git tags after `project()` has been called. This is useful for projects that need custom setup and can't use `cpp_library_setup()` but still want automatic git-based versioning.

**Usage:**

```cmake
project(my-library)  # No VERSION specified
cpp_library_set_version()
# Now PROJECT_VERSION, PROJECT_VERSION_MAJOR, PROJECT_VERSION_MINOR, 
# and PROJECT_VERSION_PATCH are set from git tags
```

The function:
- Queries git tags using `git describe --tags --abbrev=0`
- Strips the 'v' prefix if present (e.g., `v1.2.3` → `1.2.3`)
- Respects `CPP_LIBRARY_VERSION` cache variable if set (for package managers)
- Falls back to `0.0.0` if no tag found
- Updates all `PROJECT_VERSION*` variables in parent scope

**When to use:**
- You have a custom library setup that doesn't use `cpp_library_setup()`
- You want to remove hardcoded versions from your `project()` declaration
- You're migrating to cpp-library incrementally

**Example for stlab/stlab:**

```cmake
cmake_minimum_required(VERSION 3.24)
include(cmake/CPM.cmake)

CPMAddPackage("gh:stlab/cpp-library@5.1.1")
include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)

cpp_library_enable_dependency_tracking()

project(stlab LANGUAGES CXX)  # No hardcoded version

# Set version from git tags
cpp_library_set_version()

# Custom library setup continues...
add_library(stlab)
# ... rest of CMakeLists.txt
```

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
- **If you specify `TESTS` or `EXAMPLES`**, call `include(CTest)` after `project()` and before `cpp_library_setup()`.
- Version is automatically detected from git tags (see [Version Management](#version-management) for overrides).
- Installation is controlled by the `${NAMESPACE}_INSTALL` option, which defaults to `PROJECT_IS_TOP_LEVEL`.

### Target Naming

Use the component name as your project name, and specify the organizational namespace separately:

```cmake
project(enum-ops)  # Component name only

cpp_library_setup(
    NAMESPACE stlab  # Organizational namespace
    # ...
)
```

This produces:

- **Target name**: `enum-ops`
- **Package name**: `stlab-enum-ops` (used in `find_package(stlab-enum-ops)`)
- **Target alias**: `stlab::enum-ops` (used in `target_link_libraries()`)
- **Repository name**: `stlab/stlab-enum-ops` (must match package name)

**Special case** — single-component namespace (e.g., `project(stlab)` with `NAMESPACE stlab`):

- Target name: `stlab`
- Package name: `stlab`
- Target alias: `stlab::stlab`
- Repository name: `stlab/stlab`

### `cpp_library_map_dependency`

```cmake
cpp_library_map_dependency(target find_dependency_call)
```

Maps non-namespaced targets to their package. Required only for targets like `opencv_core` where the package name cannot be inferred. Call this after `find_package()` or `CPMAddPackage()`:

```cmake
find_package(OpenCV 4.5.0 REQUIRED)
cpp_library_map_dependency("opencv_core" "OpenCV 4.5.0")
target_link_libraries(my-target INTERFACE opencv_core)
```

Namespaced targets like `Qt6::Core` and `Boost::filesystem` are tracked automatically.

### Path Conventions

All file specifications use filenames only, automatically placed in standard directories:

- **HEADERS**: `include/<namespace>/` (e.g., `your_header.hpp` → `include/your_namespace/your_header.hpp`)
- **SOURCES**: `src/` (e.g., `your_library.cpp` → `src/your_library.cpp`; omit for header-only)
- **EXAMPLES**: `examples/` (e.g., `example.cpp`, `example_fail.cpp`)
- **TESTS**: `tests/` (e.g., `tests.cpp`, `unit_tests.cpp`)

### Library Types

- **Header-only**: Specify only `HEADERS`, omit `SOURCES`
- **Compiled**: Specify both `HEADERS` and `SOURCES` (builds as static by default, set `BUILD_SHARED_LIBS=ON` for shared)

## Reference

### CMake Presets

cpp-library generates a `CMakePresets.json` file with configurations for: `default` (release), `test` (debug), `docs`, `clang-tidy`, `install`, and `init`.

All presets configure `CPM_SOURCE_CACHE` to `${sourceDir}/.cache/cpm` for faster builds. Override via environment variable if needed (avoid setting in CMakeLists.txt to preserve parent project settings).

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

Uses [doctest](https://github.com/doctest/doctest) with CTest integration. Compile-fail tests are automatically detected via `_fail` suffix in filenames.

### Template Files

cpp-library automatically generates infrastructure files on first configuration and when using the `init` preset:

- **CMakePresets.json**: Build configurations (default, test, docs, clang-tidy, install, init)
- **.github/workflows/ci.yml**: Multi-platform CI/CD pipeline with testing and documentation deployment
- **.gitignore**, **.vscode/extensions.json**: Development environment configuration
- **Package config files**: `<Package>Config.cmake` for CMake integration

Regenerate with `cmake --preset=init` after updating cpp-library versions.

## Example Projects

See these projects using cpp-library:

- [stlab/stlab-enum-ops](https://github.com/stlab/stlab-enum-ops) - Type-safe operators for enums
- [stlab/stlab-copy-on-write](https://github.com/stlab/stlab-copy-on-write) - Copy-on-write wrapper

## Troubleshooting

### Non-Namespaced Target Error

**Problem**: Error about non-namespaced dependency like `opencv_core`

**Solution**: Map the target to its package after `find_package()`:
```cmake
find_package(OpenCV 4.5.0 REQUIRED)
cpp_library_map_dependency("opencv_core" "OpenCV 4.5.0")
target_link_libraries(my-library INTERFACE opencv_core)
```

### Untracked Dependencies

During configuration, you may see messages like:

```
-- cpp-library: Untracked dependencies (see: https://github.com/stlab/cpp-library#untracked-dependencies)
-- cpp-library: Dependency stlab::copy-on-write (package: stlab-copy-on-write) was not tracked.
-- cpp-library: Dependency stlab::enum-ops (package: stlab-enum-ops) was not tracked.
```

**This is expected behavior** when:
- Building for development (not installing)
- Using dependencies added from subdirectories (via `CPMAddPackage` in downstream packages)
- Testing locally without installation

**What it means:**
- These dependencies were not captured by the dependency provider (usually because they were added in a subdirectory)
- cpp-library uses a fallback `find_dependency()` call for these dependencies
- Your build will work correctly
- If you attempt to install, validation will fail to prevent broken package configs

**When it matters:**
- **Installing the package**: Installation will fail with a detailed error, preventing broken configs
- **Not installing**: Messages are informational only - your local development builds work fine

**Solutions** (if you need to install):

1. **Move dependencies to top-level** (preferred):
   ```cmake
   # In your top-level CMakeLists.txt (after project())
   CPMAddPackage("gh:stlab/stlab-copy-on-write@1.1.0")
   target_link_libraries(my-library INTERFACE $<BUILD_INTERFACE:stlab::copy-on-write>)
   ```

2. **Manually register dependencies**:
   ```cmake
   # After adding the dependency
   CPMAddPackage("gh:stlab/stlab-copy-on-write@1.1.0")
   cpp_library_map_dependency("stlab::copy-on-write" "stlab-copy-on-write 1.1.0")
   target_link_libraries(my-library INTERFACE $<BUILD_INTERFACE:stlab::copy-on-write>)
   ```

3. **Use CPM_USE_LOCAL_PACKAGES**: Install dependencies first, then build with local packages:
   ```bash
   cmake -DCPM_USE_LOCAL_PACKAGES=ON -B build
   ```

**Why this happens:**
The dependency provider (CMake 3.24+) tracks `find_package()` and `CPMAddPackage()` calls at the project scope. When dependencies are added in subdirectories (common with transitive CPM dependencies), they aren't captured at your project's scope.

**Important:** Ensure `cpp_library_enable_dependency_tracking()` is called before `project()` - this is required for any dependency tracking to work.

### CPM Repository Name Mismatch

**Problem**: `CPMAddPackage()` fails with `CPM_USE_LOCAL_PACKAGES`

**Solution**: Repository name must match package name. See [Repository Naming](#repository-naming) for details.

### Clang-Tidy on Windows/MSVC

**Problem**: Clang-tidy reports "exceptions are disabled" when analyzing code on Windows with MSVC

**Solution**: This is a known clang-tidy issue ([CMake #22979](https://gitlab.kitware.com/cmake/cmake/-/issues/22979)) where clang-tidy doesn't properly recognize MSVC's `/EHsc` exception handling flag. cpp-library automatically detects this scenario and adds `--extra-arg=/EHsc` to `CMAKE_CXX_CLANG_TIDY` when both MSVC and clang-tidy are enabled. This workaround is applied transparently and only on MSVC platforms.

## Development

To run cpp-library's unit tests for dependency mapping and installation:

```bash
cmake -P tests/install/CMakeLists.txt
```

See `tests/install/README.md` for details.

## License

Distributed under the Boost Software License, Version 1.0. See `LICENSE`.
