---
title: "Deferred Install Dependency Validation and Config Generation"
entity_type: pattern
source: inferred
confidence: 0.75
created: 2026-10-12T21:15:45Z
last_accessed: 2026-10-12T21:17:06Z
last_reinforced: 2026-10-12T21:15:45Z
access_count: 2
sources:
  - "cmake/cpp-library-install.cmake:506-560"
relationships:
  - type: applies_to
    target: "Architecture Overview"
  - type: relates_to
    target: "Dependency Tracking Lifecycle and Provider Ordering"
tags: ["deferred-install", "install-validation", "untracked-dependencies", "cmake-language-defer", "find-dependency"]
tier: knowledge
---

# Deferred Install Dependency Validation and Config Generation

Install finalization uses cmake_language(DEFER CALL _cpp_library_finish_install) evaluated inside _cpp_library_setup_install() to execute after all downstream target_link_libraries() statements in the consumer's directory have run. _cpp_library_finish_install() first calls _cpp_library_deferred_generate_config() to produce package config and an unverified dependencies manifest, then invokes _cpp_library_setup_install_validation(). Because install(CODE ...) checks the unverified dependencies list during CMake's installation phase, untracked dependencies only log a warning during configuration but trigger a fatal install error (FATAL_ERROR) preventing broken CMake Config files from being installed. Consumers can resolve untracked links by placing find_package/CPMAddPackage in the top-level scope or using cpp_library_map_dependency().

Aliases / also known as: Deferred Install Dependency Validation and Config Generation, deferred install, install validation, _cpp_library_finish_install, _cpp_library_setup_install_validation, untracked dependencies
