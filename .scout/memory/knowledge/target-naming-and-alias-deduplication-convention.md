---
title: "Target Naming and Alias Deduplication Convention"
entity_type: pattern
source: inferred
confidence: 0.75
created: 2026-10-12T21:15:55Z
last_accessed: 2026-10-12T21:15:55Z
last_reinforced: 2026-10-12T21:15:55Z
access_count: 1
sources:
  - "cpp-library.cmake:238-250"
  - "cmake/cpp-library-setup.cmake:56-80"
relationships:
  - type: applies_to
    target: "Architecture Overview"
tags: ["target-naming", "alias-deduplication", "package-name", "clean-name", "cmake-alias-convention"]
tier: knowledge
---

# Target Naming and Alias Deduplication Convention

cpp_library_setup derives CLEAN_NAME by removing "${ARG_NAMESPACE}-" prefix from PROJECT_NAME. The CMake target alias is always created as ${ARG_NAMESPACE}::${CLEAN_NAME}. To prevent collision in package naming, PACKAGE_NAME is set to ${ARG_NAMESPACE}-${CLEAN_NAME}, with a special deduplication case: if ARG_NAMESPACE equals CLEAN_NAME (for instance, project(stlab) with NAMESPACE stlab), the package collapses to just stlab rather than duplicating to stlab-stlab. This standard governs repo naming on GitHub (org/org-component) and ensures clean target export interfaces.

Aliases / also known as: Target Naming and Alias Deduplication Convention, target naming, alias deduplication, PACKAGE_NAME, CLEAN_NAME, CMake alias convention
