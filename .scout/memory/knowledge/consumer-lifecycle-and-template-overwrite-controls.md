---
title: "Consumer Lifecycle and Template Overwrite Controls"
entity_type: decision
source: inferred
confidence: 0.75
created: 2026-10-12T21:15:50Z
last_accessed: 2026-10-12T21:15:50Z
last_reinforced: 2026-10-12T21:15:50Z
access_count: 1
sources:
  - "cmake/cpp-library-setup.cmake:140-175"
  - "cpp-library.cmake:200-260"
relationships:
  - type: applies_to
    target: "Architecture Overview"
tags: ["template-initialization", "cpp-library-force-init", "project-is-top-level", "lightweight-consumer-mode", "template-copying"]
tier: knowledge
---

# Consumer Lifecycle and Template Overwrite Controls

_cpp_library_setup_core() copies consumer development templates (.clang-format, .gitignore, .vscode settings/tasks, CMakePresets.json, docs/index.html) and generates .github/workflows/ci.yml using _cpp_library_setup_ci() only when PROJECT_IS_TOP_LEVEL is true. Subproject/dependency consumers exit early into lightweight mode, skipping templates, tests, docs, and presets. For top-level projects, existing template files are preserved by default to respect custom edits, unless overwritten when CPP_LIBRARY_FORCE_INIT is ON (e.g. via preset 'init' or cmake -DCPP_LIBRARY_FORCE_INIT=ON).

Aliases / also known as: Consumer Lifecycle and Template Overwrite Controls, template initialization, CPP_LIBRARY_FORCE_INIT, lightweight consumer mode, PROJECT_IS_TOP_LEVEL template copying
