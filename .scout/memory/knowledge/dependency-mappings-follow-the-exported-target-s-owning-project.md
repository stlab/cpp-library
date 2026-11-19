---
title: "Dependency mappings follow the exported target's owning project"
entity_type: discovery
confidence: 0.99
created: 2026-11-18T23:22:31Z
last_accessed: 2026-11-18T23:22:31Z
last_reinforced: 2026-11-18T23:22:31Z
access_count: 1
sources:
  - "cmake/cpp-library-install.cmake:34-40"
  - "cmake/cpp-library-install.cmake:65-68"
tags: ["cmake", "dependency-mappings", "project-scope", "deferred-install"]
tier: knowledge
---

# Dependency mappings follow the exported target's owning project

Explicit dependency mappings are isolated per CMake project. Registration keys GLOBAL properties by SHA256(PROJECT_BINARY_DIR) plus dependency target. Generation must derive PROJECT_BINARY_DIR from the exported target's BINARY_DIR, not from the directory calling the generator. Helper directories and deferred package finalization can generate another project's target; using caller scope leaks or selects the wrong override. Non-project subdirectories share the owning project's mappings; nested and sibling projects do not. Retain the binary-directory identity so separate configurations of the same source project remain distinct. The GLOBAL storage also supports the script-mode mock harness; do not replace it with an unscoped target-only key.
