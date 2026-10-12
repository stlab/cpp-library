---
title: "Architecture Overview"
entity_type: concept
source: inferred
confidence: 0.80
created: 2026-10-12T21:15:34Z
last_accessed: 2026-10-12T21:17:06Z
last_reinforced: 2026-10-12T21:15:34Z
access_count: 2
sources:
  - "cpp-library.cmake:47-81"
  - "setup.cmake:1-50"
  - "cmake/cpp-library-setup.cmake:140-195"
tags: ["architecture-overview", "cpp-library-architecture", "cpp-library-overview", "toolkit-architecture", "cmake-infrastructure-overview"]
tier: knowledge
---

# Architecture Overview

cpp-library is a CMake infrastructure toolkit consumed by C++ libraries via CPMAddPackage to standardize build, test, install, docs, and CI workflows. Its implementation is CMake scripts and consumer templates; C++ sources in this repository are integration fixtures. It provides two entry points: setup.cmake for standalone project scaffolding, and cpp-library.cmake for runtime consumption. Consumer projects enable dependency tracking before project(), invoke project(), include(CTest) when using tests or examples, and configure via cpp_library_setup(). Target creation distinguishes between INTERFACE and compiled libraries (respecting BUILD_SHARED_LIBS), while top-level builds configure templates and CI. Installation and its dependency validation are independently controlled by installation options, including for subprojects.

Key boundary paths:
- cpp-library.cmake: runtime entry point exposing public functions
- cmake/cpp-library-setup.cmake: target setup, template management, and git version resolution
- cmake/cpp-library-install.cmake: deferred install config generation and dependency validation
- cmake/cpp-library-dependency-provider.cmake: CMake 3.24+ dependency provider hook
- setup.cmake: standalone project generator

Aliases / also known as: Architecture Overview, cpp-library architecture, cpp-library overview, toolkit architecture, CMake infrastructure overview
