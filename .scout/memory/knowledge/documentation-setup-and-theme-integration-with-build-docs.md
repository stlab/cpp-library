---
title: "Documentation Setup and Theme Integration with BUILD_DOCS"
entity_type: pattern
source: inferred
confidence: 0.75
created: 2026-10-12T21:16:10Z
last_accessed: 2026-10-12T21:16:10Z
last_reinforced: 2026-10-12T21:16:10Z
access_count: 1
sources:
  - "cmake/cpp-library-docs.cmake:8-50"
  - "cmake/cpp-library-docs.cmake:53-85"
relationships:
  - type: applies_to
    target: "Architecture Overview"
tags: ["build-docs", "doxygen", "doxygen-awesome-css", "documentation-generation", "docs-target"]
tier: knowledge
---

# Documentation Setup and Theme Integration with BUILD_DOCS

Public setup calls the documentation helper in cmake/cpp-library-docs.cmake only for a top-level project with BUILD_DOCS enabled. The helper requires Doxygen through find_package(Doxygen REQUIRED), fetches the doxygen-awesome-css theme through CPM, and creates the 'docs' build target. Missing Doxygen fails configuration rather than silently skipping documentation.

The generated Doxyfile uses a consumer's docs/Doxyfile when present, otherwise the toolkit's templates/Doxyfile.in. Both are configured into the current binary directory; DOCS_INPUTS and validated single-line DOCS_OPTIONS are appended afterward. Building the 'docs' preset renders styled HTML suitable for GitHub Pages. Template changes belong in templates/Doxyfile.in, not a nonexistent templates/docs/Doxyfile.in.

Aliases / also known as: Documentation Setup and Theme Integration with BUILD_DOCS, docs target, BUILD_DOCS, Doxygen setup, doxygen-awesome-css, documentation generation
