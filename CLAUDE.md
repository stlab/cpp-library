# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

`cpp-library` is **not a C++ library itself** — it's a CMake infrastructure template/toolkit that other C++ library repositories consume (via `CPMAddPackage`) to get a standardized build, test, install, docs, and CI setup. There is no C++ source to compile in this repo; the "code" is CMake script (`.cmake` files) plus template files that get copied/configured into consumer projects.

Two ways consumers use this repo:
1. **`setup.cmake`** — a standalone script (`cmake -P setup.cmake`) that scaffolds a brand-new library project (directory structure, `CMakeLists.txt`, template header, git init).
2. **`cpp-library.cmake`** — included by a consumer's `CMakeLists.txt` via CPM; provides the `cpp_library_setup(...)` function and friends that an existing/generated project calls to wire up its library target, tests, docs, install rules, and CI.

## Commands

Run cpp-library's own test suite (pure CMake scripts, no C++ compilation involved):

```bash
cmake -P tests/install/CMakeLists.txt              # dependency mapping/merging unit tests
cmake -P tests/install/test_provider_merge.cmake   # dependency provider merge tests
cmake -P tests/setup/test_setup_version_resolution.cmake  # setup.cmake version-resolution integration test
```

These are the same commands CI (`.github/workflows/ci.yml`, job `unit-tests`) runs. There is no build step for cpp-library itself — `cmake -P` executes the scripts directly.

CI also runs an `integration-tests` job that generates a throwaway consumer project, configures/builds/installs it against this repo via `CPMAddPackage(... SOURCE_DIR ...)`, then verifies `find_package()` works against the installed package — this is the best reference for the full round-trip a downstream project goes through.

To exercise cpp-library manually against a local consumer project without publishing a release:

```cmake
CPMAddPackage(
    NAME cpp-library
    SOURCE_DIR "${CMAKE_SOURCE_DIR}/../cpp-library"
)
```

or pin to a specific commit: `CPMAddPackage("gh:stlab/cpp-library#<commit-sha>")`.

## Architecture

### Module structure (`cmake/`)

- **`cpp-library.cmake`** (root) — entry point; defines `cpp_library_set_version()` and `cpp_library_enable_dependency_tracking()`, then includes the modules below. `cpp_library_enable_dependency_tracking()` must be called *before* `project()` — it registers `cpp-library-dependency-provider.cmake` via `CMAKE_PROJECT_TOP_LEVEL_INCLUDES` so CMake's dependency-provider hook (3.24+) is active for the `project()` call that follows.
- **`cpp-library-setup.cmake`** — the core `cpp_library_setup(...)` function (called from `cpp-library.cmake`, which is why the module split doesn't map 1:1 to files: some logic that requires `project()` to already have run — install, docs, CI templating — is deferred and included lazily inside `cpp_library_setup()` rather than at top-level `include()` time).
- **`cpp-library-install.cmake`** — install rules, package `Config.cmake`/`ConfigVersion.cmake` generation, and the `find_dependency()` derivation logic. Only `include()`d inside `cpp_library_setup()` (needs `project()` for `GNUInstallDirs`).
- **`cpp-library-dependency-provider.cmake`** — implements the CMake dependency-provider callback (`SET_DEPENDENCY_PROVIDER`) that intercepts every `find_package()`/`FetchContent_MakeAvailable()` call to record the exact package/version/components used, so `Config.cmake` can regenerate accurate `find_dependency()` calls at install time. State is stored in `GLOBAL` properties (`_CPP_LIBRARY_TRACKED_DEP_*`, `_CPP_LIBRARY_PKG_KEYS`, etc.) — there's no other persistence mechanism, so tests reset these properties between cases (see `tests/install/CMakeLists.txt`).
- **`cpp-library-docs.cmake`** — Doxygen + doxygen-awesome-css target (`docs`).
- **`cpp-library-ci.cmake`** — generates `.github/workflows/ci.yml` for the *consumer* project from `templates/.github/workflows/ci.yml.in`, substituting the package name.
- **`cpp-library-testing.cmake`** — thin backward-compat wrapper; real test/example executable logic lives in `_cpp_library_setup_executables()` in `cpp-library.cmake`.

### Key control flow

1. Consumer calls `cpp_library_enable_dependency_tracking()` before `project()`.
2. Consumer calls `project(name)`, then `include(CTest)` if using TESTS/EXAMPLES, then `cpp_library_setup(NAMESPACE ... HEADERS ... [SOURCES ...] [TESTS ...] [EXAMPLES ...])`.
3. `cpp_library_setup()`:
   - Derives `PACKAGE_NAME` (namespace-prefixed, e.g. `stlab-enum-ops`) and `CLEAN_NAME` (namespace stripped from `PROJECT_NAME`).
   - Sets project version from git tags (`_cpp_library_get_git_version`, overridable via `CPP_LIBRARY_VERSION` cache var for package managers without git history).
   - Creates the library target (`INTERFACE` if no `SOURCES`, else a compiled target respecting `BUILD_SHARED_LIBS`) with `FILE_SET headers`, aliased as `NAMESPACE::CLEAN_NAME`.
   - Calls `_cpp_library_setup_install()`, which is gated by `${NAMESPACE}_INSTALL` (default `PROJECT_IS_TOP_LEVEL`) and uses `cmake_language(DEFER)` to generate `Config.cmake` and register install-time dependency validation *after* all `target_link_libraries()` calls in the consumer's `CMakeLists.txt` have executed (deferred calls run LIFO — validation is registered first so it executes last, right before config files are written).
   - If `PROJECT_IS_TOP_LEVEL`: also copies static template files (`.clang-format`, `.gitignore`, `CMakePresets.json`, etc. — skipped if already present unless `CPP_LIBRARY_FORCE_INIT` is set), configures the CI workflow, downloads doctest, and wires up `TESTS`/`EXAMPLES`/`docs`. When consumed as a subproject (not top-level), it returns early after target creation — "lightweight consumer mode".
4. At install time, if any dependency was linked but never went through a tracked `find_package()`/`CPMAddPackage()` call at the top-level scope (e.g. added in a subdirectory), the install step fails with a detailed error (`_cpp_library_setup_install_validation`) rather than silently emitting a broken `Config.cmake`. During plain `configure`/`build` (no install), the same situation is only a warning ("Untracked dependencies").

### Naming conventions consumers must follow

- `project(component-name)` + `NAMESPACE org` → target `component-name`, alias `org::component-name`, package `org-component-name`, GitHub repo must be `org/org-component-name`.
- Special case: `project(org)` + `NAMESPACE org` → package/target collapse to just `org` (no duplication).
- Non-namespaced link targets (e.g. `opencv_core`) can't be resolved automatically and require `cpp_library_map_dependency(target "Package Version")`.

### `templates/`

Static files copied verbatim (or via `configure_file()` for `.in` files) into a *consumer* project the first time it configures, or when `CPP_LIBRARY_FORCE_INIT`/`init` preset is used to regenerate them. Not used by cpp-library's own build — these are outputs, not inputs.

### `tests/`

Not C++ unit tests — these are `cmake -P` scripts that test the CMake functions themselves in isolation, using mocked `get_target_property()` and manually-reset `GLOBAL` properties between cases (see `run_test()` macro in `tests/install/CMakeLists.txt`). When adding a new dependency-mapping test case, follow the pattern in `tests/install/README.md` (`run_test()` → set up mock target/links → call the function under test → `verify_output()`).
