---
title: "Public-header verification must participate in the default build"
entity_type: pattern
confidence: 0.99
created: 2026-11-19T00:38:12Z
last_accessed: 2026-11-19T00:38:12Z
last_reinforced: 2026-11-19T00:38:12Z
access_count: 1
sources:
  - "cpp-library.cmake:314-323"
  - "tests/setup/test_header_checks.cmake:151-159"
tags: ["cmake", "header-verification", "testing", "file-sets"]
tier: knowledge
---

# Public-header verification must participate in the default build

cpp_library_setup() enables native CMake VERIFY_INTERFACE_HEADER_SETS only for top-level projects with BUILD_TESTING enabled. Preserve both the target property and the ALL custom target dependency on <target>_verify_interface_header_sets: native verification targets are excluded from the default build, so setting the property alone does not enforce the check. Keep verification based on PUBLIC/INTERFACE header file sets rather than a second header list; this includes generated headers and file sets added after setup. These build-time, per-header checks are separate from configure-time clangd indexing. C++17/20/23 fixtures check the configured standard, public usage requirements, generated-header ordering, and the testing-off/subproject scope boundaries. Platform-specific public headers must guard their contents and be no-ops when unsupported; do not introduce platform-exclusion lists.
