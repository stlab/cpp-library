# Release Notes - Version 4.1.0 (Unreleased)

## Overview

This release represents a major enhancement to cpp-library's installation and dependency management infrastructure. The primary focus is on introducing a CMake dependency provider system that accurately tracks and generates installation dependencies, along with numerous improvements to the setup process, testing infrastructure, and developer experience.

## Breaking Changes

### CMake Version Requirement
- **Removed support for CMake < 3.24**: The library now requires CMake 3.24 or later due to the use of the dependency provider feature.
- **Rationale**: This allows for more accurate and reliable dependency tracking during installation.

### Setup Function Order Changes
- **Updated required order for CMake setup**: Projects must now call functions in this order:
  1. `cpp_library_enable_dependency_tracking()` (before `project()`)
  2. `project()` declaration
  3. `cpp_library_setup()` (after `project()`)
  4. `include(CTest)` (explicitly, if tests/examples are used)

- **Install module deferred**: The install module inclusion now happens after `project()` to avoid requiring language/architecture information too early.
- **Impact**: Existing projects will need to update their CMakeLists.txt to follow the new order.

### CMake Presets Changes
- **Removed 'install' preset**: The install preset has been removed from CMakePresets.json and documentation.
- **CPM_SOURCE_CACHE moved to presets**: CPM cache configuration moved from CMakeLists.txt to CMakePresets.json for automatic setup.

## New Features

### Installation Support (PR #12)
The most significant addition in this release is comprehensive installation support with accurate dependency tracking:

- **CMake Dependency Provider**: Implemented a custom dependency provider that tracks all `find_package()` calls during configuration and automatically generates proper `find_dependency()` calls in the installed CMake config files.
  
- **Component Merging**: Multiple `find_package()` calls for the same package with different components are now correctly merged, preventing duplicates and preserving optional components.

- **Custom Dependency Mapping**: Added support for custom dependency mapping to handle cases where the installed package name differs from the find_package name (e.g., Qt6 components).

- **QUIET Dependency Handling**: The dependency provider now correctly filters out dependencies from `find_package()` calls with the QUIET flag when the package is not found.

- **Version Override Support**: Projects can override dependency versions in the generated config files.

### Interactive Setup Script
- **setup.cmake**: New interactive setup script that guides users through creating a new library project with the correct structure.
  - Auto-detects the current cpp-library version from git tags
  - Prompts for library name, namespace, description, and options
  - Generates all necessary files with proper structure
  - Downloads dependencies automatically
  
### CI/CD Improvements
- **Template-based CI workflow**: The CI workflow file is now generated from a template (`ci.yml.in`) during project setup, allowing for customization.
- **Conditional CMake steps**: CI workflow now conditionally runs CMake steps based on project configuration.
- **Dependency mapping tests**: Added comprehensive tests for dependency mapping and provider functionality.
- **Provider merging tests**: Added tests to verify component merging behavior.

## Improvements

### Documentation
- **README simplification**: Removed design rationale and redundant examples for clarity.
- **Version standardization**: Replaced hardcoded version numbers with placeholders (X.Y.Z) in documentation and templates, encouraging users to check for the latest release.
- **Usage clarification**: Improved documentation about required setup order and dependency tracking.
- **Troubleshooting added**: Added troubleshooting section for common issues.
- **CPM cache documentation**: Updated docs to reflect CPM_SOURCE_CACHE configuration in presets.

### CMake Infrastructure
- **Header guard generation**: Enhanced to sanitize names by replacing hyphens with underscores and converting to uppercase.
- **Error messaging**: Improved error messages throughout to clarify common issues and provide guidance.
- **Regex safety**: Enhanced regex handling for special characters in package names, versions, and components.
- **Property handling**: Improved global property handling for tracking dependencies and packages.
- **CONFIG flag preservation**: Fixed bug where CONFIG flag was lost when merging dependency calls without components.
- **Keyword filtering**: Keywords (CONFIG, NO_MODULE, REQUIRED) are now properly filtered from component lists to prevent them being treated as components.

### Testing Infrastructure
- **CTest integration**: Improved integration with CTest by deferring `enable_testing()` to directory scope using `cmake_language(EVAL CODE ...)`.
- **Test organization**: Better organization of install tests with dedicated test files.
- **Integration examples**: Added comprehensive integration example demonstrating correct usage patterns.

### Development Tools
- **clang-tidy MSVC support**: Added workaround to automatically append `--extra-arg=/EHsc` to CMAKE_CXX_CLANG_TIDY when using MSVC, addressing exception handling flag issues.
- **clangd integration**: Maintained and improved clangd support for better IDE integration.

### Dependency Management
- **CPM.cmake integration**: Maintained compatibility with CPM while improving installation behavior.
- **Package name consistency**: Introduced PACKAGE_NAME parameter for consistent target and package naming.
- **Argument parsing**: Improved argument parsing to handle package names and version numbers with regex metacharacters.

### Version Detection
- **Git tag-based versioning**: Enhanced automatic version detection from git tags with better fallback handling.
- **Semantic versioning validation**: Added validation to ensure proper semantic versioning format.

## Bug Fixes

- **Fixed CONFIG flag preservation**: CONFIG flag is now preserved when merging find_package calls without components.
- **Fixed component merging**: CONFIG, NO_MODULE, and REQUIRED keywords no longer treated as components.
- **Fixed namespace prefix escaping**: Corrected regex handling when escaping namespace prefixes for clean name calculation.
- **Fixed version extraction**: Improved version extraction logic to enforce semantic versioning format.
- **Fixed QUIET dependency handling**: Phantom dependencies from failed QUIET find_package calls are no longer included in config files.
- **Fixed enable_testing() timing**: Changed to use EVAL CODE instead of DEFER DIRECTORY for immediate execution at parent directory scope.
- **Fixed quoting issues**: Resolved various quoting issues in Windows bash environments.
- **Fixed CI test project**: Corrected usage order demonstration in CI test project.

## Testing

### New Tests Added
- `test_dependency_mapping.cmake`: Comprehensive tests for dependency mapping functionality
- `test_dependency_provider.cmake`: Tests for dependency provider core functionality
- `test_provider_merge.cmake`: Tests for component merging behavior
- `test_integration_example.txt`: Complete integration example demonstrating correct usage

### Test Infrastructure
- Install test suite with dedicated CMakeLists.txt
- Provider merging tests in CI pipeline
- Conditional test execution based on project configuration

## Migration Guide

### For Existing Projects

If you're upgrading from v4.0.5 or earlier, you'll need to make the following changes:

1. **Update CMake minimum version** to 3.24:
   ```cmake
   cmake_minimum_required(VERSION 3.24)
   ```

2. **Update setup function order** in your CMakeLists.txt:
   ```cmake
   # Enable dependency tracking BEFORE project()
   cpp_library_enable_dependency_tracking()
   
   # Declare your project
   project(your-library VERSION 1.0.0 LANGUAGES CXX)
   
   # Setup cpp-library AFTER project()
   cpp_library_setup(...)
   
   # If you have tests or examples, explicitly include CTest
   include(CTest)
   ```

3. **Update CMakePresets.json**:
   - Remove any `install` preset entries
   - Add `CPM_SOURCE_CACHE` to cache variables in your presets if desired

4. **Review dependency tracking**:
   - Ensure all `find_package()` calls happen after `cpp_library_enable_dependency_tracking()`
   - Add custom dependency mappings if needed for packages with non-standard names

5. **Update CI workflow** (if using the template):
   - The CI workflow is now generated from `ci.yml.in` template
   - Review and update your workflow based on the new template

## Contributors

- Sean Parent - Primary contributor
- Copilot SWE Agent - Automated contributions

## Statistics

- **69 commits** since v4.0.5
- **23 files changed**
- **3,030 insertions, 315 deletions**
- Date range: 2025-11-11 to 2025-12-16

## What's Next

Future releases will likely focus on:
- Additional dependency mapping patterns
- Enhanced documentation
- More comprehensive testing scenarios
- Performance optimizations
- Community feedback integration

## Links

- [Pull Request #12](https://github.com/stlab/cpp-library/pull/12) - Using a dependency provider to generate install dependencies
- [Full Changelog](https://github.com/stlab/cpp-library/compare/v4.0.5...main)
