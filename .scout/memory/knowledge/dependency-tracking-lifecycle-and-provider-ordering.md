---
title: "Dependency Tracking Lifecycle and Provider Ordering"
entity_type: observation
source: inferred
confidence: 0.75
created: 2026-10-12T21:15:39Z
last_accessed: 2026-10-12T21:15:39Z
last_reinforced: 2026-10-12T21:15:39Z
access_count: 1
sources:
  - "cpp-library.cmake:61-71"
  - "cmake/cpp-library-dependency-provider.cmake:10-58"
  - "cmake/cpp-library-dependency-provider.cmake:71-105"
  - "cmake/cpp-library-install.cmake:150-229"
relationships:
  - type: applies_to
    target: "Architecture Overview"
tags: ["dependency-tracking", "dependency-provider", "cpp-library-enable-dependency-tracking", "cmake-project-top-level-includes", "set-dependency-provider"]
tier: knowledge
---

# Dependency Tracking Lifecycle and Provider Ordering

Dependency tracking must be activated before project() by calling cpp_library_enable_dependency_tracking(), which appends cmake/cpp-library-dependency-provider.cmake to CMAKE_PROJECT_TOP_LEVEL_INCLUDES and propagates it to parent scope. When CMake 3.24+ processes project(), the provider is installed via SET_DEPENDENCY_PROVIDER. It records supported find_package() requests and FetchContent metadata in GLOBAL properties. For find_package(), it builds canonical dependency declarations containing the package, requested version, components, optional components, and supported flags; it does not preserve every argument verbatim. Package declarations are stored in _CPP_LIBRARY_TRACKED_DEP_<package>.

Failure behavior depends on the missing state. When deriving an unmapped, non-system namespaced link dependency, an absent provider causes a fatal configuration error. If the provider is installed but that dependency was not captured, configuration reports the untracked dependency and installation validation rejects it. Explicit mappings and recognized system packages can resolve dependencies without a tracked provider declaration. Preserve these distinctions when changing diagnostics or provider ordering.

Aliases / also known as: Dependency Tracking Lifecycle and Provider Ordering, dependency tracking, dependency provider, cpp_library_enable_dependency_tracking, CMAKE_PROJECT_TOP_LEVEL_INCLUDES, SET_DEPENDENCY_PROVIDER
