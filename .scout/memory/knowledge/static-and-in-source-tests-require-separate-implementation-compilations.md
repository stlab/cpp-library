---
title: "Static and in-source tests require separate implementation compilations"
entity_type: decision
confidence: 0.99
created: 2026-11-19T20:41:11Z
last_accessed: 2026-11-19T20:55:02Z
last_reinforced: 2026-11-19T20:55:02Z
access_count: 2
sources:
  - "cmake/cpp-library-testing.cmake:8-60"
  - "cmake/cpp-library-testing.cmake:62-96"
  - "cmake/cpp-library-testing.cmake:9"
  - "cmake/cpp-library-testing.cmake:18"
  - "README.md:792"
tags: ["cmake", "testing", "doctest", "static-linkage", "private-components", "generated-headers"]
tier: knowledge
votes_up: 1
votes_down: 0
last_voted: 2026-11-19T22:02:29Z
---

# Static and in-source tests require separate implementation compilations

# Static and in-source tests require separate implementation compilations

Preserve existing TESTS executable names and per-file mains. Their compiled component uses a separate production-mode static target, while <project>_in_source_tests compiles every implementation source directly with one generated doctest main. Do not combine these modes: enabling registrations in the ordinary static test library repeats embedded tests in existing binaries, while relying on archive extraction can silently omit registration-only translation units.

The private generated cpp-library/testing.hpp defines the function-style CPP_LIBRARY_TESTING() macro as 0 for production and the ordinary static implementation, and 1 for per-file test translation units and the separate in-source runner. Guard both doctest includes and cases with #if CPP_LIBRARY_TESTING(); never expose this generated header through installed public headers.

Finalize variants after the owner directory declares its sources, links, and generated-header dependencies. CMake file-set headers are stored separately from SOURCES: preserve HEADER_SETS and INTERFACE_HEADER_SETS generation ordering through one shared header-generation target used by production and both test variants. Requiring callers to add explicit add_dependencies() masks missing file-set support; clean direct test-target builds must also work without that workaround.

Static unit tests consume implementation compile requirements, including private requirements, rather than the production target's consumer-only compile definitions: the documented Windows DLL pattern adds an INTERFACE import definition that is incorrect for a static implementation. Keep production BUILD_SHARED_LIBS and third-party dependency linkage unchanged. Test targets and their private include roots are not exported.
