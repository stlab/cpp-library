---
title: "Assign generated-test timeouts at registration to preserve per-test overrides"
entity_type: pattern
confidence: 1.00
created: 2026-11-21T06:03:02Z
last_accessed: 2026-11-21T06:03:09Z
last_reinforced: 2026-11-21T06:03:09Z
access_count: 2
sources:
  - "cpp-library.cmake:135-150"
  - "cpp-library.cmake:338-340"
  - "cmake/cpp-library-testing.cmake:8-15"
  - "cmake/cpp-library-testing.cmake:117-129"
  - "tests/setup/test_timeouts.cmake:31-39"
tags: ["ctest", "timeouts", "test-support", "deferred-configuration"]
tier: knowledge
---

# Assign generated-test timeouts at registration to preserve per-test overrides

Generated CTest timeout policy is project-local: cpp_library_setup stores an explicit TEST_TIMEOUT in the production library target's _CPP_LIBRARY_TEST_TIMEOUT property (cpp-library.cmake:338-340). _cpp_library_set_test_timeout reads that property, defaults to 120 seconds, and sets the native test TIMEOUT property (cmake/cpp-library-testing.cmake:8-15).

Keep timeout assignment immediate at each registration site, not in deferred test-support finalization. Ordinary tests/examples and compile-fail checks are registered in cpp-library.cmake:135-150; compiled libraries also register a separate in-source runner in cmake/cpp-library-testing.cmake:117-129. All three paths must apply the same policy using the production library target, not its static unit-test implementation target. Immediate assignment lets consumers use set_tests_properties after setup without deferred work resetting their intentional exceptions; the regression overrides both ordinary and in-source tests (tests/setup/test_timeouts.cmake:31-39).

Verification: cmake -P tests/setup/test_timeouts.cmake inspects effective CTest JSON, checks generated preset metadata, and proves one-second timeout failure for runtime and WILL_FAIL compile-fail tests.
