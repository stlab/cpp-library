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
- **CI/CD**: [GitHub Actions](https://docs.github.com/en/actions) workflows with multi-platform source builds and testing
- **Dependency Management**: [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake) integration

## Quick reference

Requires CMake 3.24 or newer. The minimum C++ version defaults to 20;
[`REQUIRES_CPP_VERSION`](#cpp_library_setup) also supports 17 and 23.

Use this order in your top-level `CMakeLists.txt`:

| Order | Action |
| --- | --- |
| 1 | Load CPM and cpp-library, as shown in [Manual Setup](#manual-setup). |
| 2 | Call [`cpp_library_enable_dependency_tracking()`](#cpp_library_enable_dependency_tracking) **before `project()`**. |
| 3 | Call `project(... LANGUAGES CXX)`. |
| 4 | Call `include(CTest)` at directory scope to define `BUILD_TESTING`. |
| 5 | Call [`cpp_library_setup()`](#cpp_library_setup), using the [file-resolution conventions](#path-conventions). |
| 6 | Declare dependencies with `CPMAddPackage()` or `find_package()`, then link them to your library. |

Declare dependencies after `cpp_library_setup()`.

For custom target setup, see [`cpp_library_set_version()`](#cpp_library_set_version).
For non-namespaced dependency targets, see [dependency mapping](#non-namespaced-target-error).
For automatic standalone header checks, see [public-header compilation](#public-header-compilation).

## Quick Start

The easiest way to create a new library project using cpp-library is with the `setup.cmake` script. This interactive script will guide you through creating a new project with the correct structure, downloading dependencies, and generating all necessary files.

Before you begin, install CMake 3.24 or newer, Git, Ninja, and a C++ compiler
supporting your chosen standard. On Windows with MSVC, run build commands in an
x64 Visual Studio developer environment.

### Using setup.cmake

**Bash, interactive mode:**

```bash
cmake -P <(curl -sSL https://raw.githubusercontent.com/stlab/cpp-library/main/setup.cmake)
```

Or download and run:

```bash
curl -O https://raw.githubusercontent.com/stlab/cpp-library/main/setup.cmake
cmake -P setup.cmake
```

In PowerShell, download and run the script:

```powershell
$setupUrl = "https://raw.githubusercontent.com/stlab/cpp-library/main/setup.cmake"
Invoke-WebRequest -UseBasicParsing -Uri $setupUrl -OutFile setup.cmake
cmake -P setup.cmake
```

The script will prompt you for:

- **Library name** (e.g., `my-library`)
- **Namespace** (e.g., `mycompany`)
- **Description**
- **Header-only library?** (yes/no)
- **Include examples?** (yes/no)
- **Include tests?** (yes/no)

**Bash, non-interactive mode:**

```bash
cmake -P setup.cmake -- \
  --name=my-library \
  --namespace=mycompany \
  --description="My awesome library" \
  --header-only=yes \
  --examples=yes \
  --tests=yes
```

In PowerShell, use backticks for line continuation:

```powershell
cmake -P setup.cmake -- `
  --name=my-library `
  --namespace=mycompany `
  --description="My awesome library" `
  --header-only=yes `
  --examples=yes `
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

If you prefer to set up your project manually or need to integrate the cpp-library into an existing project, follow these steps.

### Usage

Install [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake):

```bash
mkdir -p cmake
curl -L -o cmake/CPM.cmake "https://github.com/cpm-cmake/CPM.cmake/releases/latest/download/get_cpm.cmake"
```

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
project(your-library LANGUAGES CXX)

# Enable testing infrastructure (required for SOURCES, TESTS, and EXAMPLES)
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

`HEADERS`, `SOURCES`, `TESTS`, and `EXAMPLES` are filenames under their
[standard directories](#path-conventions), not paths from the project root.

These examples are for C++-only projects. If your project also contains C
sources, use `project(your-library LANGUAGES C CXX)`.

### Consuming Libraries Built with cpp-library

#### Using CPMAddPackage (recommended)

The preferred way to consume a library built with cpp-library is via [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake):

```cmake
cmake_minimum_required(VERSION 3.24)
project(my-app LANGUAGES CXX)

include(cmake/CPM.cmake)

# Fetch the library directly from GitHub
# Note: Repository name must match the package name (including namespace prefix)
CPMAddPackage("gh:stlab/stlab-enum-ops@1.0.0")

add_executable(my-app main.cpp)
target_link_libraries(my-app PRIVATE stlab::enum-ops)
```

The library will be automatically fetched and built as part of your project.

**Repository Naming:** Your GitHub repository name must match the package name for CPM compatibility (see [Target Naming](#target-naming) for details).

#### Installation (strongly discouraged)

Consume libraries from source through [CPMAddPackage](#using-cpmaddpackage-recommended).
Installation is strongly discouraged: an installed package's dependencies might not be
installed or available to a downstream consumer, so its `find_dependency()` calls can fail.
cpp-library does not automatically install dependencies.

For installation, install required dependencies separately before configuring the
component, and configure CPM to use those installed packages. Installing a component
against dependencies fetched from source in the same build is not supported.
Source consumption requires no special build/install-interface wrappers.
CMake checks installation exports during configuration/generation, before
`cmake --install` runs. For source-only builds without installed dependencies,
disable the component's installation option. The generated `default`, `test`,
`docs`, `clang-tidy`, and `init` presets do this automatically; the `install`
preset enables it. Presets use your package's installation-option name, including
a custom `INSTALL_OPTION`. Configuring without a preset preserves the
`PROJECT_IS_TOP_LEVEL` default.

If system-wide deployment or a package manager requires installation, use:

```bash
# Build and install to default system location
cmake --preset=install
cmake --build --preset=install
cmake --install build/install

# Install to custom prefix
cmake --install build/install --prefix /opt/mylib
```

The `install` preset enables `CPM_USE_LOCAL_PACKAGES`, which makes CPM look for
locally installed dependencies before fetching them from source. This setting is a
preference, not a guarantee: ensure CPM resolves the required installed packages
rather than falling back to source. It does not verify your project's installed
package config or dependency closure. See the
[CPM.cmake documentation](https://github.com/cpm-cmake/CPM.cmake#cpm_use_local_packages).

Generated CI builds and tests from source; it does not test installation.
If you want installation testing, provide a separate workflow that prepares
dependencies and installs your package. No installation-specific changes to your
`CMakeLists.txt` are required. See [Test installation in your own workflow](docs/installation-testing.md)
for a cel-euclid example with GLM and the CEL packages.

cpp-library generates `cpp-library-test-package.cmake` in your build directory
for optional artifact checking. It checks that the root package's `Config.cmake`,
`ConfigVersion.cmake`, and `Targets.cmake` files exist and appear in the install
manifest. It does not load the package or check its dependency closure.
To update existing generated CI and presets, use the
[template regeneration procedure](#updating-cpp-library).

**Controlling installation**: The uppercase `${NAMESPACE}_INSTALL` option controls whether installation is enabled (defaults to `PROJECT_IS_TOP_LEVEL`). Use `-D${NAMESPACE}_INSTALL=ON/OFF` to override:

```bash
cmake -DSTLAB_INSTALL=OFF -B build  # Disable install for top-level project
cmake -DSTLAB_INSTALL=ON -B build   # Enable install for non-top-level (e.g., via CPM)
```

Libraries must not predeclare or assign their own default to the shared
`${NAMESPACE}_INSTALL` option, including before adding dependencies. Leave its
declaration and default to cpp-library, and preserve the client's chosen value.
Packages within a namespace share this cache option: the first declaration
establishes its default for the build, so a library-specific default can
unintentionally enable or disable installation for other packages in that namespace.

Omit `INSTALL_OPTION` when installing each package in a separate build, including
dependencies. Each package is then a top-level project, so installation defaults on.

`INSTALL_OPTION` is an advanced escape hatch for selectively installing packages
within one combined source build. Packages sharing a namespace otherwise share the
same installation switch, so enabling it can select multiple packages. Only when
you need independent switches in that build, give a package its own option name:

```cmake
cpp_library_setup(
    DESCRIPTION "Execution primitives"
    NAMESPACE stlab
    HEADERS execution.hpp
    INSTALL_OPTION STLAB_EXECUTION_INSTALL
)
```

This package then uses `STLAB_EXECUTION_INSTALL`, independently of `STLAB_INSTALL` or other
packages' custom options. Each custom option defaults to that project's `PROJECT_IS_TOP_LEVEL`.
Specifying `INSTALL_OPTION` names the switch; it does not enable installation,
install dependencies, or change dependency requirements.
Specifying `INSTALL_OPTION` without a value is an error.

When installation is enabled, cpp-library installs an existing `${PROJECT_SOURCE_DIR}/LICENSE`
under `${CMAKE_INSTALL_DATADIR}/licenses/<package-name>`. A missing conventional `LICENSE`
is allowed. To include additional license or notice files, use `LICENSE_FILES`:

```cmake
cpp_library_setup(
    DESCRIPTION "Execution primitives"
    NAMESPACE stlab
    HEADERS execution.hpp
    LICENSE_FILES licenses/CPM-MIT.txt NOTICE
)
```

Relative `LICENSE_FILES` paths are relative to the declaring project's source root;
absolute paths are also accepted. Files keep their basenames in the package's license
directory, including when you customize `CMAKE_INSTALL_DATADIR`. Distinct files must have
distinct basenames; a collision is a configuration error rather than an overwrite.
With installation enabled,
a missing explicitly listed file is a configuration error. `LICENSE_FILES` without a value
is also an error. Disabled installation adds no license install rules. Only the current
package's files are installed; cpp-library does not discover dependency licenses.

#### Dependency Handling in Installed Packages

Declare public dependencies with ordinary `target_link_libraries()` calls, using
`INTERFACE` for header-only libraries or `PUBLIC` for compiled libraries. Do not add
build/install-interface wrappers to make source-built dependencies installable.
For installation, clients must
resolve dependencies from their separately installed packages, as described in
[installation guidance](#installation-strongly-discouraged).

cpp-library automatically generates `find_dependency()` calls in the installed CMake
package configuration. Build-only links do not generate installed requirements.
Call `cpp_library_enable_dependency_tracking()` before `project()`:

```cmake
cmake_minimum_required(VERSION 3.24)
include(cmake/CPM.cmake)

CPMAddPackage("gh:stlab/cpp-library@X.Y.Z")
include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)

cpp_library_enable_dependency_tracking()
project(my-library LANGUAGES CXX)

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

Mappings apply only to libraries declared in the same CMake project, including
subdirectories that do not call `project()`. They override automatic tracking within
that project, but do not affect parent, nested, or sibling projects. Declare a mapping
in each project that needs it.

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

### `cpp_library_enable_dependency_tracking`

Registers the dependency provider used to record dependency versions and
components for installed package requirements. Requires CMake 3.24 or newer.

After loading cpp-library, call it in your top-level `CMakeLists.txt` **before
the literal `project()` call**:

```cmake
cpp_library_enable_dependency_tracking()
project(my-library LANGUAGES CXX)
```

Declare library dependencies after `project()`. Calling the function afterward
doesn't activate the provider retroactively. See [Manual Setup](#manual-setup)
for the complete loading sequence and [Untracked Dependencies](#untracked-dependencies)
for dependency-recording failures.

### `cpp_library_set_version`

```cmake
cpp_library_set_version()
```

Updates the project version from git tags after `project()` has been called. This is useful for projects that need custom setup and can't use `cpp_library_setup()` but still want automatic git-based versioning.

**Usage:**

```cmake
project(my-library LANGUAGES CXX)  # No VERSION specified
cpp_library_set_version()
# Now PROJECT_VERSION, PROJECT_VERSION_MAJOR, PROJECT_VERSION_MINOR,
# and PROJECT_VERSION_PATCH are set from git tags
```

The function:

- Queries git tags using `git describe --tags --abbrev=0`
- Strips the 'v' prefix if present (e.g., `v1.2.3` → `1.2.3`)
- Respects project-scoped version overrides; the legacy override applies only
  to the top-level project (see [Version Management](#version-management))
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
    [DOCS_INPUTS input_list]       # Additional documentation files/directories
    [DOCS_OPTIONS setting_list]    # Additive single-line Doxygen assignments
    [REQUIRES_CPP_VERSION 17|20|23] # C++ version (default: 20)
    [INSTALL_OPTION option_name]   # Independent installation control (default: uppercase NAMESPACE_INSTALL)
    [LICENSE_FILES file_list]      # Additional project-relative or absolute license/notice files
)
```

**Notes:**

- The project name is automatically taken from `PROJECT_NAME` (set by the `project()` command). You must call `project(your-library)` before `cpp_library_setup()`.
- Call `include(CTest)` at directory scope after `project()` and before
  `cpp_library_setup()` to define `BUILD_TESTING`. It is required if you specify
  `TESTS` or `EXAMPLES`.
- Top-level builds with `BUILD_TESTING=ON` automatically perform
  [independent public-header compilation](#public-header-compilation).
- Version is automatically detected from git tags (see [Version Management](#version-management) for overrides).
- Installation is controlled by `INSTALL_OPTION`, or the uppercase `${NAMESPACE}_INSTALL` option
  when omitted. Options default to `PROJECT_IS_TOP_LEVEL`.
- Enabled installation includes the project-root `LICENSE` when present and any
  `LICENSE_FILES`. See [installation guidance](#installation-strongly-discouraged)
  for destinations and missing-file behavior.
- `cpp_library_setup()` makes the effective `GNUInstallDirs` directory variables
  available to subsequent caller install rules, including when installation is disabled.
- `REQUIRES_CPP_VERSION` sets the minimum C++ standard. Compiled library, test,
  and example targets default to `CXX_EXTENSIONS OFF` unless
  `CMAKE_CXX_EXTENSIONS` is set by the caller. This does not impose a dialect on
  consumers or enable pedantic diagnostics.

### Documentation configuration

Keep the toolkit's Doxyfile template instead of copying it into your project.
`DOCS_INPUTS` adds files or directories to the default `include` input. Relative
paths are resolved against the directory calling `cpp_library_setup`; absolute
paths and paths containing spaces are supported. Missing inputs fail configuration.

`DOCS_OPTIONS` applies project-specific Doxygen assignments after the shared
template. Each quoted CMake argument must be a single `TAG = value` or
`TAG += value` assignment, with Doxygen quoting inside the value when needed.
Use spaces, not CMake semicolons, to separate Doxygen list values. The toolkit
validates assignment syntax and rejects line-continuation backslashes, including
those followed by whitespace; Doxygen validates tag names and values. Settings
are literal, not `configure_file` templates: use `${...}` for CMake variables.

```cmake
cpp_library_setup(
    DESCRIPTION "My library"
    NAMESPACE mylib
    HEADERS api.hpp
    DOCS_INPUTS docs/doxygen "${PROJECT_BINARY_DIR}/generated docs"
    DOCS_EXCLUDE_SYMBOLS "mylib::detail"
    DOCS_OPTIONS
        "WARN_IF_UNDOCUMENTED = NO"
        "INCLUDE_PATH = \"${PROJECT_BINARY_DIR}/include\""
        "MACRO_EXPANSION = YES"
        "PREDEFINED = MYLIB_API= MYLIB_NAMESPACE_BEGIN()= MYLIB_NAMESPACE_END()="
)
```

Existing `docs/Doxyfile` overrides remain supported. Additional inputs and options
are applied after that configuration too, but a full override does not inherit
future toolkit-template changes. Prefer the shared template with only the
project-specific deltas above. Documentation is configured only for top-level
projects with `BUILD_DOCS` enabled.

The shared template uses the stlab-derived `templates/DoxygenLayout.xml` for
tutorial-first navigation: **Tutorials** contains the main page and authored
guides, grouped APIs appear under **Reference**, and namespace, class, file,
example, and other lookup pages appear under **Index**. Supply tutorial pages
through `DOCS_INPUTS` and organize APIs with Doxygen `\defgroup` and `\ingroup`.
Tutorials and Index are expandable headings, not landing pages. Doxygen hides
lookup sections without documented contents.
Reference appears when the project defines groups. Group descriptions precede member lists,
and group briefs remain visible even with `REPEAT_BRIEF = NO`. The compact
version-2 layout inherits unspecified page sections from Doxygen, avoiding a
version-specific copy of its entire default layout. Documentation generation
therefore requires **Doxygen 1.13.1 or newer**; non-documentation builds do not
require Doxygen.

To add a program to the Examples index, put a `\example example.cpp` documentation
block in a `DOCS_INPUTS` file. The shared template searches the project's
`examples` directory. Building a source through `EXAMPLES` or displaying it with
`\include` does not create an example page.

`WARN_LAYOUT_FILE = NO` suppresses warnings about intentionally inherited layout
entries. It also suppresses other layout diagnostics, including malformed XML;
normal documentation builds therefore do not validate layout edits. Other
documentation warnings remain errors.

**Whenever the layout is updated**, temporarily enable layout warnings and review
all of them. Use these review-only overrides to see the complete warning list
rather than stopping at the first inherited-entry warning:

```cmake
DOCS_OPTIONS
    "WARN_LAYOUT_FILE = YES"
    "WARN_AS_ERROR = NO"
```

Reconfigure and build the `docs` target. Accept missing-entry warnings only for
sections intentionally inherited from Doxygen's defaults; fix malformed XML,
unknown entries, and other unexpected diagnostics. Then remove the review-only
overrides to restore `WARN_LAYOUT_FILE = NO` and `WARN_AS_ERROR = YES`.

The layout stays in the toolkit rather than being copied into each project.
Override it through the existing options when needed (quote paths containing
spaces):

```cmake
DOCS_OPTIONS
    "LAYOUT_FILE = \"${CMAKE_CURRENT_SOURCE_DIR}/docs/doxygen/DoxygenLayout.xml\""
```

A project's custom `docs/Doxyfile` retains its own layout configuration; the shared
layout is not appended to or imposed on that override.

### `cpp_library_copy_runtime_dlls`

```cmake
add_executable(custom-test main.cpp support.cpp)
target_link_libraries(custom-test PRIVATE mylib::my-library)
cpp_library_copy_runtime_dlls(custom-test)
```

Call this helper in the directory that created the target. On Windows, it deploys
`TARGET_RUNTIME_DLLS` beside the target after building, including transitive
runtime DLLs. Static targets with no runtime DLLs require no copy; on other
platforms the helper does nothing. It uses CMake 3.24-compatible copy operations
and handles DLLs already in the destination. Toolkit-created test/example
executables use the same helper automatically.

### Target Naming

Use the component name as your project name, and specify the organizational namespace separately:

```cmake
project(enum-ops LANGUAGES CXX)  # Component name only

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

Maps a dependency target to custom `find_dependency()` arguments for the declaring
CMake project only. Mappings override automatic tracking in that project, including
non-project subdirectories; independent projects do not share mappings.
Use this for non-namespaced targets like `opencv_core` where the package name cannot
be inferred, or when automatic tracking needs an override. Call this after
`find_package()` or `CPMAddPackage()`:

```cmake
find_package(OpenCV 4.5.0 REQUIRED)
cpp_library_map_dependency("opencv_core" "OpenCV 4.5.0")
target_link_libraries(my-target INTERFACE opencv_core)
```

Namespaced targets like `Qt6::Core` and `Boost::filesystem` are tracked automatically.

### Path Conventions

Library and executable file specifications use filenames resolved under standard directories:

- **HEADERS**: `include/<namespace>/` (e.g., `your_header.hpp` → `include/your_namespace/your_header.hpp`)
- **SOURCES**: `src/` (e.g., `your_library.cpp` → `src/your_library.cpp`; omit for header-only)
- **EXAMPLES**: `examples/` (e.g., `example.cpp`, `example_fail.cpp`)
- **TESTS**: `tests/` (e.g., `tests.cpp`, `unit_tests.cpp`)

`LICENSE_FILES` accepts paths relative to `${PROJECT_SOURCE_DIR}` or absolute paths.

### Library Types

- **Header-only**: Specify only `HEADERS`, omit `SOURCES`
- **Compiled**: Specify both `HEADERS` and `SOURCES`. The target respects
  `BUILD_SHARED_LIBS` (static by default; shared when `ON`), leaving the choice
  to the library consumer.

### Windows DLLs and ABI boundaries

Static linking is the default. When consumers require a Windows DLL, follow the
[stlab-execution](https://github.com/stlab/stlab-execution) pattern: put the
compiled runtime behind a small, explicitly versioned C ABI and list its exports
in a checked-in module-definition (`.def`) file. Keep the C++ convenience layer in
headers rather than exporting C++ implementation symbols. Execution's
`src/execution.def` is the model for this export list.

For example, after `cpp_library_setup(...)` creates `my-library`:

```cmake
get_target_property(library_type my-library TYPE)
if(WIN32 AND library_type STREQUAL "SHARED_LIBRARY")
    target_sources(my-library PRIVATE src/my-library.def)
    target_compile_definitions(my-library INTERFACE MY_LIBRARY_USING_DLL)
endif()
```

The `.def` file names only the intended ABI entry points:

```text
EXPORTS
    my_library_v1_initialize
    my_library_v1_shutdown
```

Public declarations use `extern "C"` and `__declspec(dllimport)` when consuming the
DLL. In this example, the target's `MY_LIBRARY_USING_DLL` interface definition
selects imports for shared consumers, including installed consumers, but is absent
when compiling the library itself or consuming a static build:

```cpp
#if defined(_WIN32) && defined(MY_LIBRARY_USING_DLL)
#define MY_LIBRARY_API __declspec(dllimport)
#else
#define MY_LIBRARY_API
#endif

extern "C" {
MY_LIBRARY_API int my_library_v1_initialize(void);
MY_LIBRARY_API void my_library_v1_shutdown(void);
}
```

The `.def` file controls exports when building the DLL; `dllexport` is not needed
for these entry points. Do not enable `WINDOWS_EXPORT_ALL_SYMBOLS` or broadly mark
implementation classes `dllexport`. A `.def` file and C linkage do not by themselves
guarantee ABI stability: preserve calling conventions, argument layouts, ownership
and lifetime rules, and version incompatible entry points. Do not expose standard
library types or let C++ exceptions cross this boundary. Allocate and release
owned resources on the same side of the boundary.

cpp-library installs DLLs in `CMAKE_INSTALL_BINDIR` and import/static libraries in
`CMAKE_INSTALL_LIBDIR`. Consumers should link the exported CMake target so that
include paths, import definitions, and transitive dependencies are preserved;
`BUILD_SHARED_LIBS` does not change the type of an already installed library.

For the tests and examples created through `TESTS` and `EXAMPLES`, cpp-library
automatically copies runtime DLL dependencies beside each executable after linking
on Windows, including DLLs from installed packages. Dependencies must provide
proper CMake shared-library targets with their DLL locations. Static builds with
no runtime DLL dependencies need no copies. Deploying downstream applications and
their DLLs remains the application's responsibility; this convenience does not
add application installation rules or deploy the compiler runtime.

## Reference

### CMake Presets

cpp-library generates a `CMakePresets.json` file with configurations for: `default` (release), `test` (debug), `docs`, `clang-tidy`, `install`, and `init`.

All presets configure `CPM_SOURCE_CACHE` to `${sourceDir}/.cache/cpm` for faster builds. Override via environment variable if needed (avoid setting in CMakeLists.txt to preserve parent project settings).

### Version Management

Version is automatically detected from git tags:

- Supports `v1.2.3` and `1.2.3` tag formats
- Falls back to `0.0.0` if no tag is found (with warning)
- Version used in CMake package config files

For package managers or CI systems building from source archives without Git
history, set `CPP_LIBRARY_VERSION_<PROJECT_NAME>` to override one project's
version. Replace `<PROJECT_NAME>` with the exact, case-sensitive name supplied to
that project's `project()` call, including any hyphens. This is the CMake project
name, not the namespace or derived package name.

Both `cpp_library_setup()` and `cpp_library_set_version()` use this precedence:

1. A non-empty `CPP_LIBRARY_VERSION_<PROJECT_NAME>` override for that project.
2. A non-empty legacy `CPP_LIBRARY_VERSION` override, only when
   `PROJECT_IS_TOP_LEVEL` is true.
3. The project's Git tag, with a leading `v` removed.
4. `0.0.0` with a warning when no tag is found.

Pass overrides as CMake cache entries when configuring the build. Empty override
values are ignored. Overriding one project's version does not change independently
named nested projects.

Existing top-level builds using `CPP_LIBRARY_VERSION` continue to work. To override
a nested project, migrate to `CPP_LIBRARY_VERSION_<PROJECT_NAME>`; the legacy
variable no longer overrides subprojects. A matching project-scoped override takes
precedence over the legacy variable.

### Testing

Tests use [doctest](https://github.com/doctest/doctest) with CTest integration.
Call `include(CTest)` at directory scope before `cpp_library_setup()`.
Development tests are enabled for top-level projects with `BUILD_TESTING=ON`.
Filenames containing `_fail` register compile-fail tests.

Each `TESTS` file remains a separate executable with its own main.
Unit tests link a separate static implementation, even when the production
library uses `BUILD_SHARED_LIBS=ON`. They inherit the implementation's private
build requirements rather than consumer-only DLL-import definitions. Dependencies
retain the client's selected linkage, so a test can still require third-party
DLLs. Examples continue to link the production library.

The library implementation and unit tests have a private `src/` include root.
Place private headers in `src/private/` and include them as
`#include "private/header.hpp"`. This path isn't added to the production
library's public interface or to the independent public-header checks.

#### In-source tests

Put tests for unnamed-namespace components in the same `.cpp` file as the
implementation. Include the generated private configuration header and guard
both the doctest include and test cases:

```cpp
#include <cpp-library/testing.hpp>

namespace {
/// Reports whether value is even.
constexpr bool is_even(unsigned value) noexcept {
    return value % 2 == 0;
}
}

#if CPP_LIBRARY_TESTING()
#include <doctest/doctest.h>

TEST_CASE("even values") {
    CHECK(is_even(0));
    CHECK(is_even(4));
    CHECK_FALSE(is_even(3));
}
#endif
```

After you include the configuration header, `CPP_LIBRARY_TESTING()` is always
defined as `0` or `1`. Use `#if CPP_LIBRARY_TESTING()`, not `#ifdef`, and don't
define it yourself. Production compilation and the static implementation used
by existing per-file tests use `0`; the in-source runner and the per-file test
sources use `1`. Keep this header private; don't include it from installed
public headers. Production compilation doesn't need doctest headers or libraries.

For compiled libraries, cpp-library adds `<project>_in_source_tests` to the normal
build and CTest, even if you omit `TESTS`. This separate executable compiles the
implementation with testing enabled and includes every source directly, so
registration-only translation units aren't lost inside a static archive.
cpp-library supplies its doctest main: don't define
`DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN` in implementation sources. Keep the existing
mains in your `TESTS` files unchanged. Embedded tests run only in the separate
runner, not again in each per-file executable.

Test variants require additional implementation compilation. They use the
library's finalized build settings, including dependencies and generated-header
ordering declared after `cpp_library_setup()`, and its configured C++ standard.
No in-source runner is added for header-only libraries, subprojects, or
`BUILD_TESTING=OFF`.

#### Public-header compilation

In top-level projects with `BUILD_TESTING=ON`, the normal build compiles each
header in the library's `PUBLIC` and `INTERFACE` CMake header file sets in a
separate translation unit. This includes generated headers and file sets added
after `cpp_library_setup()`. No separate option or duplicate header list is
needed. These checks aren't added when a client consumes your library as a
subproject.

Each check uses the library's public usage requirements and configured C++
standard, supporting C++17, C++20, and C++23. It doesn't force every library to
compile in all three modes. Unlike [clangd indexing](#clangd-and-vscode), this
checks that headers compile independently of include order. The checks run
during `cmake --build`, not during configuration or `ctest`.

Keep every public header self-contained. If a header doesn't apply to the
configured target, guard its platform-specific contents with the C++
preprocessor. On unsupported targets, the header must be a no-op, apart from
optionally including a configuration header. Don't maintain platform-specific
header exclusions.

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
-- cpp-library: Dependency acme::widgets (package: acme-widgets) was not tracked.
```

cpp-library derives each `find_dependency()` call from two sources:

- **`CPMAddPackage()`**: CPM's package registry records every package and its version, whether
  CPM fetches it, reuses it from `CPM_SOURCE_CACHE`, or adds it from a subdirectory.
- **`find_package()` and `FetchContent_MakeAvailable()`**: The dependency provider records calls
  made after `project()`, including versions and components.

The message means neither source accounts for the package that provides a linked target, for
example because the package comes from `add_subdirectory()` or from a `find_package()` call made
before `project()`.

**What it means:**

- cpp-library uses a fallback `find_dependency(<package>)` call without a version.
- Development builds work.
- Installation fails with a detailed error, preventing a broken package config.

**Solution:** Add the dependency with `CPMAddPackage()` or `find_package()` after `project()`, or
map the target explicitly:

```cmake
cpp_library_map_dependency("acme::widgets" "acme-widgets 2.1.0")
```

**Important:** Call `cpp_library_enable_dependency_tracking()` before `project()`; the dependency
provider must be active for `find_package()` tracking.

### CPM Repository Name Mismatch

**Problem**: `CPMAddPackage()` fails with `CPM_USE_LOCAL_PACKAGES`

**Solution**: Repository name must match package name. See [Repository Naming](#repository-naming) for details.

### Clang-Tidy on Windows/MSVC

**Problem**: Clang-tidy reports "exceptions are disabled" when analyzing code on Windows with MSVC

**Solution**: This is a known clang-tidy issue ([CMake #22979](https://gitlab.kitware.com/cmake/cmake/-/issues/22979)) where clang-tidy doesn't properly recognize MSVC's `/EHsc` exception handling flag. cpp-library automatically detects this scenario and adds `--extra-arg=/EHsc` to `CMAKE_CXX_CLANG_TIDY` when both MSVC and clang-tidy are enabled. This workaround is applied transparently and only on MSVC platforms.

## clangd and VSCode

With `CMAKE_EXPORT_COMPILE_COMMANDS=ON` (already enabled by the supplied Ninja
presets), `cpp_library_setup()` registers each public header with an exact C++
consumer command in CMake's ordinary `compile_commands.json`. This also works for
header-only and nested dependency libraries without tests or implementation
sources. Commands use the owner's public/transitive usage requirements, including
requirements added after setup; private implementation flags and DLL-export
definitions are not copied. Dependencies never consume their downstream owners.

Indexing OBJECT targets are excluded from normal builds and are not installed or
exported. They do not change the production target's sources or public-header
FILE_SET. No database postprocessor or configure-time clangd dependency is needed.
Set `CPP_LIBRARY_ENABLE_CLANGD=OFF` to opt out. With database export disabled,
registration still validates ownership but creates no indexing targets or warnings.

For manually created local INTERFACE, STATIC or SHARED libraries, register explicit
absolute paths (a local alias is also accepted):

```cmake
cpp_library_add_clangd_headers(
    TARGET my_library
    HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/include/my_library/api.hpp"
)
```

Repeated registration with one owner is idempotent; additional headers extend its
registration. Registering a header with two different owners fails with both names
and the path, rather than leaving clangd to choose an arbitrary command. Imported
targets and generator expressions in header paths are not supported. Explicit
generated headers can be registered before they exist, provided they are declared
`GENERATED`; headers needed immediately by the editor must actually be generated
during configure (for example with `configure_file()`). Registering a build-time
header does not run its generator or add default-build prerequisites.

### Editor setup and migration

Install CMake 3.24+, Ninja, the selected compiler/SDK, clangd, VSCode CMake Tools,
and the clangd extension. Dependencies must be available and configuration must
succeed. Select a configure preset with **CMake: Select Configure Preset**, then
run **CMake: Configure**. No build or previously opened includer is required:
restart clangd if necessary and open a registered public header first.

New projects receive `.vscode/settings.json` with:

```json
{
    "cmake.useCMakePresets": "always",
    "cmake.configureOnOpen": true,
    "cmake.copyCompileCommands": "${workspaceFolder}/compile_commands.json"
}
```

CMake Tools copies the selected build tree's unmodified database to the workspace
root after successful configuration. Selecting another preset and configuring
refreshes that copy. No `cmake.postConfigureTask` is added, and clangd is not pinned
to any preset directory. CLI-only `cmake --preset ...` configuration generates the
build-tree database but does **not** invoke CMake Tools' root-copy action.

Ordinary configuration preserves an existing settings file byte-for-byte, including
custom copy destinations, post-configure hooks, and unrelated settings. For an
existing workspace, add the three keys above manually, reconciling your current
copy destination/hook rather than adding a competing database writer. The `init`
preset / `CPP_LIBRARY_FORCE_INIT=ON` intentionally regenerates templates, **including
settings.json**; back up custom settings before using it.

### Supported boundaries

Use a single-configuration Ninja or Makefile generator. Visual Studio and Xcode
generators are not supported for database export. Active multi-configuration
generators (including Ninja Multi-Config) are rejected: their duplicate per-header
configuration entries do not select clangd's active variant. Use single-config
Ninja or disable this feature instead.

Normal configuration-dependent usage requirements are evaluated by CMake at
generation time. Target-context-sensitive expressions evaluate in the private
indexing **consumer** context, not the producer's: custom consumer properties are
not automatically copied from the library. This is not a compilation-database
merger or a standalone-header validation build.

The focused CI regression covers Windows/MSVC, Linux/GCC and macOS/Apple Clang.
Local evidence from this change is Windows/MSVC; the other platforms require their
CI runs. Protocol checks use fresh clangd processes and require Python only for the
test harness, never for consuming projects.

## Development

To update cpp-library dependencies search for `[DEPENDENCY]`. Embed the marker in an HTML
comment (e.g. `<!-- [DEPENDENCY] -->`) rather than as visible text, so it doesn't render in
rendered docs.

To use a local copy of cpp-library:

```
CPMAddPackage(
    NAME cpp-library
    SOURCE_DIR "${CMAKE_SOURCE_DIR}/../cpp-library"
)
```

To use cpp-library from a specific commit:

```
CPMAddPackage("gh:stlab/cpp-library#65dbed9fff9a0331355bd51dc1e8156262390154")
```

To run cpp-library's script regressions (C++ fixtures require Ninja and a configured compiler;
on Windows, use a Visual Studio developer environment):

```bash
cmake -P tests/install/CMakeLists.txt
cmake -P tests/install/test_provider_merge.cmake
cmake -P tests/install/test_nested_install.cmake
cmake -P tests/setup/test_target_type.cmake
cmake -P tests/setup/test_clangd.cmake
cmake -P tests/setup/test_setup_version_resolution.cmake
```

To require fresh-clangd protocol checks as CI does, run
`cmake -DCPP_LIBRARY_TEST_CLANGD=ON -P tests/setup/test_clangd.cmake`.
This requires clangd on `PATH` and a Python 3 interpreter; otherwise the default
script reports unavailable protocol checks as skipped.

The nested-install regression configures, builds, installs, and runs a downstream consumer,
checks independent and legacy installation controls, and verifies package-local dependency validation.
The consumer links only the parent target and calls its API, which requires a compiled static
leaf library, so missing installed transitive linkage causes a link failure.

See `tests/install/README.md` for details.

## License

Distributed under the Boost Software License, Version 1.0. See `LICENSE`.
