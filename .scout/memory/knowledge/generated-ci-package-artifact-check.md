---
title: "Generated CI package artifact check"
entity_type: decision
confidence: 0.95
created: 2026-11-15T04:12:07Z
last_accessed: 2026-11-15T04:27:16Z
last_reinforced: 2026-11-15T04:27:16Z
access_count: 2
sources:
  - "templates/.github/workflows/ci.yml.in:76-79"
  - "templates/test-package.cmake.in:8-35"
  - "cmake/cpp-library-ci.cmake:41-54"
tags: ["ci", "packaging", "cmake"]
tier: knowledge
---

# Generated CI package artifact check

Generated consumer CI deliberately verifies only the root package's installed Config, ConfigVersion and Targets artifacts; dependency installation and downstream find_package resolution remain the consumer's responsibility. The checker requires both file existence and membership in the current CMake install manifest, so stale absolute-destination artifacts cannot pass. Absolute library destinations do not require the otherwise unused install prefix to exist. The deferred generator captures CPP_LIBRARY_ROOT when scheduled because setup may run inside a function whose scope ends before deferred calls execute. Sources: templates/.github/workflows/ci.yml.in:76-79, templates/test-package.cmake.in:8-35, cmake/cpp-library-ci.cmake:41-54.
