---
title: "Generated CI package artifact check"
entity_type: decision
confidence: 0.98
created: 2026-11-15T04:12:07Z
last_accessed: 2026-11-21T06:05:52Z
last_reinforced: 2026-11-21T06:05:52Z
access_count: 4
sources:
  - "templates/.github/workflows/ci.yml.in:76-79"
  - "templates/test-package.cmake.in:8-35"
  - "cmake/cpp-library-ci.cmake:41-54"
  - "README.md:223-265"
  - "docs/installation-testing.md:3-17"
  - "cmake/cpp-library-setup.cmake:187-196"
tags: ["ci", "packaging", "cmake", "source-builds"]
tier: knowledge
---

# Generated CI package artifact check

# Generated CI package artifact check

Generated consumer CI is source-only; it no longer installs or runs package-artifact checks automatically. Source presets (default, test, docs, clang-tidy, init) disable the resolved namespace/custom installation option; install enables it. Merely removing cmake --install is insufficient: CMake validates exports at generation time, so source-built dependencies without export sets can break configuration unless installation is disabled.

Clients wanting installation testing provide their own YAML workflow that installs required dependencies separately, configures the component against those installed packages, then installs and optionally runs the generated cpp-library-test-package.cmake script. No installation-specific dependency declarations or export workarounds belong in client CMakeLists.txt. CPM_USE_LOCAL_PACKAGES is a preference, not a source-fallback prohibition.

The optional checker verifies root Config, ConfigVersion and Targets artifact existence AND membership in the install manifest, not downstream consumption or dependency closure. Keep stale-artifact and absolute-destination protections. Keep deferred generator root capture for function-scoped setup.

Presets are configured from templates/CMakePresets.json.in with @ONLY to preserve literal ${sourceDir}; preserve existing consumer files unless force initialization is requested. This updates the earlier memory that incorrectly described automatic generated-CI installation checking after PR #61.
