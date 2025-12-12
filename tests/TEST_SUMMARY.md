# Test Suite Summary

## Overview

Comprehensive unit test suite for `cmake/cpp-library-install.cmake`, focusing on dependency mapping and component merging functionality.

## Test Statistics

- **Total Tests**: 18
- **Pass Rate**: 100%
- **Test Framework**: CMake script mode with custom test harness

## Test Coverage

### 1. System Packages (Tests 1, 12, 17)
- Threads, OpenMP, ZLIB
- No version requirements (as expected for system packages)

### 2. External Dependencies (Test 2)
- Automatic version detection from `<PackageName>_VERSION` variables
- Boost, Qt, and other external packages

### 3. Internal cpp-library Dependencies (Tests 3, 11)
- Namespace matching: `stlab::enum-ops` → `find_dependency(stlab-enum-ops)`
- Same namespace and component: `mylib::mylib` → `find_dependency(mylib)`

### 4. Component Merging (Tests 4, 7, 8, 9, 10, 15)
- **Qt Components**: Multiple Qt6 components merged into single `find_dependency()` call
- **Boost Components**: Multiple Boost libraries merged correctly
- **Deduplication**: Duplicate components removed automatically
- **Version Separation**: Different versions NOT merged (Qt5 vs Qt6)
- **Additional Args**: CONFIG and other args preserved during merging

### 5. Custom Mappings (Tests 6, 16)
- Non-namespaced targets (opencv_core)
- Override automatic version detection
- Custom find_package() syntax

### 6. Edge Cases (Tests 13, 14, 18)
- Empty link libraries
- Generator expressions (BUILD_INTERFACE) skipped
- Complex real-world scenarios with mixed dependency types

## Test Architecture

### Mocking Strategy
- Mock `get_target_property()` to return pre-defined link libraries
- Avoids need for actual CMake project/targets in script mode
- Clean test isolation with state cleanup between tests

### Test Structure
```
tests/install/
├── CMakeLists.txt              # Test runner with harness
├── test_dependency_mapping.cmake  # 18 test cases
├── README.md                   # Documentation
└── TEST_SUMMARY.md            # This file
```

### Test Harness Features
- Automatic test numbering
- Pass/fail reporting with colored output (✓/✗)
- Detailed failure messages showing expected vs actual
- Global state cleanup between tests
- Exit code 0 on success, 1 on failure (CI-friendly)

## Running Tests

### Locally
```bash
cmake -P tests/install/CMakeLists.txt
```

### CI Integration
Tests run automatically on every push/PR via GitHub Actions:
- Ubuntu, macOS, Windows
- See `.github/workflows/ci.yml`

## Sample Test Output

```
-- Running test 1: System package without version
--   ✓ PASS: Test 1
-- Running test 2: External dependency with version
--   ✓ PASS: Test 2
...
-- Running test 18: Complex real-world scenario
--   ✓ PASS: Test 18
-- 
-- =====================================
-- Test Summary:
--   Total:  18
--   Passed: 18
--   Failed: 0
-- =====================================
```

## Adding New Tests

1. Add test case to `test_dependency_mapping.cmake`
2. Use `run_test()` macro to initialize
3. Use `mock_target_links()` to set up dependencies
4. Call `_cpp_library_generate_dependencies()`
5. Use `verify_output()` to check results

Example:
```cmake
run_test("My new test")
set(MyPackage_VERSION "1.0.0")
mock_target_links(testN_target "MyPackage::Component")
_cpp_library_generate_dependencies(RESULT testN_target "mylib")
verify_output("${RESULT}" "find_dependency(MyPackage 1.0.0)" "Test N")
```

## Future Enhancements

Potential areas for additional testing:
- Error condition testing (missing versions without mappings)
- OPTIONAL_COMPONENTS syntax
- REQUIRED keyword handling
- More complex generator expression patterns
- Performance testing with large dependency trees

