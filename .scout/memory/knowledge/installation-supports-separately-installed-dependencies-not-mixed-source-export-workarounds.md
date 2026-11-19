---
title: "Installation supports separately installed dependencies, not mixed source export workarounds"
entity_type: decision
confidence: 0.99
created: 2026-11-18T23:22:41Z
last_accessed: 2026-11-18T23:22:41Z
last_reinforced: 2026-11-18T23:22:41Z
access_count: 1
sources:
  - "README.md:215-226"
  - "README.md:240-245"
  - "cmake/cpp-library-install.cmake:70-72"
tags: ["cmake", "installation", "cpm", "supported-boundary"]
tier: knowledge
---

# Installation supports separately installed dependencies, not mixed source export workarounds

The supported installation workflow installs required dependencies separately before configuring the component, then has CPM resolve those installed packages. Installing a component against dependencies fetched from source in that same build is explicitly unsupported. Ordinary source consumption uses ordinary PUBLIC/INTERFACE target links, not BUILD_INTERFACE/INSTALL_INTERFACE wrappers to bypass export checks. CMake validates enabled installation exports during configuration/generation, before cmake --install; source-only builds without installed dependencies should disable component installation. Do not reintroduce the removed special extraction of BUILD_INTERFACE dependencies into installed find_dependency() requirements. CPM_USE_LOCAL_PACKAGES is only a preference and may fall back to source; it does not guarantee this installation precondition.
