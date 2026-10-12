---
title: "Interactive and Headless Project Scaffolding with setup.cmake"
entity_type: procedure
source: inferred
confidence: 0.75
created: 2026-10-12T21:16:16Z
last_accessed: 2026-10-12T21:16:16Z
last_reinforced: 2026-10-12T21:16:16Z
access_count: 1
sources:
  - "setup.cmake:1-50"
  - "setup.cmake:380-460"
relationships:
  - type: applies_to
    target: "Architecture Overview"
tags: ["setup-cmake", "project-scaffolding", "consumer-initialization", "standalone-generator", "cpp-library-setup-script"]
tier: procedures
---

# Interactive and Headless Project Scaffolding with setup.cmake

setup.cmake provides interactive or headless project scaffolding for consumers. It extracts the latest release version from local git tags or falls back to remote git ls-remote query against github.com/stlab/cpp-library.git tags matching v[0-9]*. It creates directory hierarchy (include/<namespace>/, src/, tests/, examples/), scaffolds top-level CMakeLists.txt with proper dependency tracking invocation before project(), writes initial library header with include guards, initializes a clean git repository, and commits the initial scaffold.

Aliases / also known as: Interactive and Headless Project Scaffolding with setup.cmake, setup.cmake, project scaffolding, consumer initialization, standalone generator, cpp-library setup script
