---
title: "Version overrides must not leak into independently named subprojects"
entity_type: decision
confidence: 0.99
created: 2026-11-18T23:22:35Z
last_accessed: 2026-11-18T23:22:35Z
last_reinforced: 2026-11-18T23:22:35Z
access_count: 1
sources:
  - "cmake/cpp-library-setup.cmake:5-23"
  - "README.md:769-790"
tags: ["cmake", "versions", "project-scope", "package-managers"]
tier: knowledge
---

# Version overrides must not leak into independently named subprojects

Both cpp_library_setup() and cpp_library_set_version() share _cpp_library_get_git_version(). Override precedence is: nonempty CPP_LIBRARY_VERSION_<PROJECT_NAME> for the exact case-sensitive CMake project() name (hyphens included); nonempty legacy CPP_LIBRARY_VERSION only for PROJECT_IS_TOP_LEVEL; then the project's Git tag; then the existing warning and 0.0.0 fallback. A cache entry for the legacy variable otherwise leaks through nested directory scopes and incorrectly overwrites dependency ConfigVersion.cmake files. Package managers overriding nested projects must use the scoped variable; do not restore unconditional legacy-variable lookup. Independently named children and siblings must retain their own tags or explicit scoped overrides.
