# Unit Tests for cpp-library-install.cmake

This directory contains unit tests for the dependency mapping and merging functionality in `cmake/cpp-library-install.cmake`.

## Running Tests Locally

From the root of the cpp-library repository:

```bash
cmake -P tests/install/CMakeLists.txt
```

Or from this directory:

```bash
cmake -P CMakeLists.txt
```

## Test Coverage

The test suite covers:

1. **System Packages**: Threads, OpenMP, ZLIB, CURL, OpenSSL (no version required)
2. **External Dependencies**: Automatic version detection from `<PackageName>_VERSION`
3. **Internal cpp-library Dependencies**: Namespace matching and package name generation
4. **Component Merging**: Multiple Qt/Boost components merged into single `find_dependency()` call
5. **Custom Mappings**: Manual dependency mappings via `cpp_library_map_dependency()`
6. **Non-namespaced Targets**: Custom mapping for targets like `opencv_core`
7. **Deduplication**: Duplicate components and dependencies removed
8. **Generator Expressions**: BUILD_INTERFACE dependencies skipped
9. **Edge Cases**: Empty libraries, different versions, override behavior

## Test Output

Successful run:
```
-- Running test 1: System package without version
--   ✓ PASS: Test 1
-- Running test 2: External dependency with version
--   ✓ PASS: Test 2
...
-- =====================================
-- Test Summary:
--   Total:  18
--   Passed: 18
--   Failed: 0
-- =====================================
```

Failed test example:
```
-- Running test 5: Multiple different packages
--   ✗ FAIL: Test 5
--     Expected: find_dependency(stlab-enum-ops 1.0.0)
-- find_dependency(stlab-copy-on-write 2.1.0)
-- find_dependency(Threads)
--     Actual:   find_dependency(stlab-enum-ops 1.0.0)
```

## Adding New Tests

To add a new test case, edit `test_dependency_mapping.cmake`:

```cmake
# Test N: Description of what you're testing
run_test("Test description")
add_library(testN_target INTERFACE)

# Set up dependencies and version variables
set(package_name_VERSION "1.0.0")
target_link_libraries(testN_target INTERFACE package::target)

# Generate dependencies
_cpp_library_generate_dependencies(RESULT testN_target "namespace")

# Verify output
verify_output("${RESULT}" "find_dependency(package-name 1.0.0)" "Test N")
```

## CI Integration

These tests run automatically on every push/PR via GitHub Actions. See `.github/workflows/ci.yml` for the workflow configuration.

