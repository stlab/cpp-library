---
title: "Testing and Example Executable Target Generation Gated by BUILD_TESTING"
entity_type: pattern
source: inferred
confidence: 0.75
created: 2026-10-12T21:16:03Z
last_accessed: 2026-10-12T21:16:03Z
last_reinforced: 2026-10-12T21:16:03Z
access_count: 1
sources:
  - "cpp-library.cmake:82-163"
  - "cmake/cpp-library-testing.cmake:1-30"
relationships:
  - type: applies_to
    target: "Architecture Overview"
tags: ["build-testing", "doctest", "testing-setup", "negative-compilation-tests", "runtime-dll-copy"]
tier: knowledge
---

# Testing and Example Executable Target Generation Gated by BUILD_TESTING

When TESTS or EXAMPLES are supplied to cpp_library_setup(), include(CTest) must be invoked at directory scope before cpp_library_setup() so that CMake's testing infrastructure and the BUILD_TESTING cache option are defined. Test and example executables are created via _cpp_library_setup_executables() (delegated from _cpp_library_setup_testing for backward compatibility). Target generation is gated by BUILD_TESTING and PROJECT_IS_TOP_LEVEL. doctest is fetched automatically via CPM. A test or example executable whose basename contains '_fail' anywhere is excluded from the normal build and registered as a negative compilation test (WILL_FAIL test property). On Windows, cpp_library_copy_runtime_dlls() deploys shared DLL dependencies beside regular executables for test execution.

Aliases / also known as: Testing and Example Executable Target Generation Gated by BUILD_TESTING, test target setup, BUILD_TESTING, doctest integration, negative compilation tests, runtime DLL copy
