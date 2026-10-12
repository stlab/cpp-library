# Repository instructions

## Repository purpose and architecture

`cpp-library` is a CMake infrastructure toolkit consumed by other C++ library
repositories through `CPMAddPackage`. Its implementation is CMake scripts and
consumer templates; C++ sources here are integration fixtures.

There are two entry points:

- `setup.cmake` runs in CMake script mode to scaffold a new consumer project,
  including its `CMakeLists.txt`, header, directory structure, and Git repository.
- `cpp-library.cmake` exposes the public functions used by consumers. It owns
  `cpp_library_setup()`, package/alias naming, version propagation, and test/example
  executable creation. `cmake/cpp-library-setup.cmake` supplies internal helpers
  for version discovery, library target creation, and template copying.

The consumer lifecycle is order-sensitive:

1. Load CPM and this toolkit, then call
   `cpp_library_enable_dependency_tracking()` **before `project()`**. It registers
   the provider through `CMAKE_PROJECT_TOP_LEVEL_INCLUDES`; CMake 3.24+ is required.
2. After `project()`, declare dependencies through `find_package()` or CPM.
   Call `include(CTest)` at directory scope before `cpp_library_setup()` when
   supplying `TESTS` or `EXAMPLES`. Setup requires `DESCRIPTION`, `NAMESPACE`,
   and `HEADERS`.
3. Setup creates the library target and optional installation rules. Only
   top-level projects proceed to template generation, tests, examples, and docs.
   `BUILD_TESTING` gates both tests and examples; `BUILD_DOCS` gates documentation.

`cmake/cpp-library-dependency-provider.cmake` records dependency versions and
components in `GLOBAL` properties. `cmake/cpp-library-install.cmake` uses this
state and target link interfaces to generate installed `find_dependency()` calls.
The install module is loaded inside public setup, after `project()`.
Installation defaults to `PROJECT_IS_TOP_LEVEL`, controlled by an explicit
`INSTALL_OPTION` or the legacy uppercase `<NAMESPACE>_INSTALL` cache option.
Use distinct `INSTALL_OPTION` names for independently installable packages that
share a namespace.

Install finalization is deferred until the target's directory has finished
declaring links. `_cpp_library_finish_install()` first generates the package
config, then registers dependency validation before export/config installation.
Preserve this ordering and the target-local install metadata: untracked
dependencies warn during configuration but fail installation.

`templates/` contains outputs for consumers. Static files are copied only when
missing unless `CPP_LIBRARY_FORCE_INIT` is enabled; `.in` files are configured.
`cmake/cpp-library-ci.cmake` generates consumer CI from
`templates/.github/workflows/ci.yml.in`, which is separate from this repository's
own `.github/workflows/ci.yml`. Documentation generation uses
`cmake/cpp-library-docs.cmake`, Doxygen, and doxygen-awesome-css.
`cmake/cpp-library-testing.cmake` provides the public runtime-DLL copy helper;
test/example target creation lives in the root module.

## Commands

Run script regressions from the repository root. PowerShell examples:

```powershell
cmake -P tests\install\CMakeLists.txt
cmake -P tests\install\test_provider_merge.cmake
cmake -P tests\install\test_nested_install.cmake
cmake -P tests\setup\test_target_type.cmake
cmake -P tests\setup\test_runtime_dlls.cmake
cmake -P tests\setup\test_setup_version_resolution.cmake
cmake -P tests\docs\test_docs.cmake
```

Each standalone script is an independently runnable regression; for example,
run only target-type coverage with
`cmake -P tests\setup\test_target_type.cmake`. The install `CMakeLists.txt` is a
script-mode harness that includes both dependency-mapping and provider tests;
those included files rely on its mocks and assertion helpers.

Use CMake 3.24+ for the regressions. Compiled integration fixtures require Ninja
and a configured C++ compiler; on Windows use an x64 Visual Studio developer
environment. Documentation rendering additionally requires Doxygen.
The nested-install regression performs build/install/downstream-consumer round
trips for static and shared libraries, including Windows DLL deployment.
The repository's CI also demonstrates a generated consumer's complete
CPM-to-install-to-`find_package()` round trip.

To exercise changes in an existing consumer without publishing a release:

```cmake
CPMAddPackage(
    NAME cpp-library
    SOURCE_DIR "${CMAKE_SOURCE_DIR}/../cpp-library"
)
```

In a consumer project, the generated presets provide build, test, and lint
commands:

```text
cmake --preset test
cmake --build --preset test
ctest --preset test
ctest --preset test -R "^<test-name>$"
cmake --preset clang-tidy
cmake --build --preset clang-tidy
cmake --preset docs
cmake --build --preset docs
```

The `clang-tidy` preset requires clang-tidy and runs analysis during compilation.
These presets come from `templates/CMakePresets.json` and apply to consumers.
`cmake --preset init` enables `CPP_LIBRARY_FORCE_INIT` and overwrites generated
consumer templates.

## Codebase conventions

- Consumer `HEADERS`, `SOURCES`, `TESTS`, and `EXAMPLES` arguments are filenames
  resolved under `include/<namespace>/`, `src/`, `tests/`, and `examples/`,
  respectively. Omitting `SOURCES` creates an `INTERFACE` target; compiled
  targets respect `BUILD_SHARED_LIBS`. Headers use CMake `FILE_SET headers`.
- `project(component)` with `NAMESPACE org` yields target `component`, alias
  `org::component`, and package `org-component`; the GitHub repository naming
  convention is `org/org-component`. If the project already has the namespace
  prefix, the alias strips it. Matching namespace and clean project name collapse
  to one package name rather than duplicating it.
- Consumer versions come from Git tags with a leading `v` removed.
  `CPP_LIBRARY_VERSION` overrides Git discovery for source archives and package
  managers; missing tags fall back to `0.0.0` with a warning.
- Non-namespaced dependency targets need explicit mappings such as
  `cpp_library_map_dependency(opencv_core "OpenCV 4.8")`. Keep dependency
  declarations after `project()` in the top-level consumer scope; explicit
  mappings also cover dependencies the provider cannot capture.
- Dependency unit tests use `run_test()`, `mock_target_links()`, the function
  under test, and `verify_output()`. Follow the actual harness in
  `tests/install/CMakeLists.txt` and cases in `test_dependency_mapping.cmake`.
  Provider functions load in test mode, and each case resets tracked/mapped
  `GLOBAL` state rather than creating real CMake targets.
- When updating pinned dependencies, search for `[DEPENDENCY]` markers across
  CMake, workflows, and docs. In Markdown, keep the marker inside an HTML comment.
  Changes to generated consumer behavior belong in the corresponding template
  and generation code, not just a generated consumer file.

README.md documents the public API and consumer workflows; CLAUDE.md provides
additional repository context. Check current implementation when their details
disagree, especially installation controls and deferred processing.
