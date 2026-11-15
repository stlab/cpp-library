# README and Doxygen Defaults — Design

## Goal

Make the README's C++-only project examples select C++ explicitly, and give generated Doxygen files concise, public-header-relative paths without removing consumer overrides.

## Non-goals

This change does not add a CMake API, change custom `docs/Doxyfile` files, or add the Read the Docs search extension.

## Approaches

- Fix only the README examples and defer Doxygen because its rendered-output cases need integration coverage.
- Fix both bounded documentation issues in their existing owners and extend the existing Doxygen integration test. This is the chosen approach because the toolkit already supplies `INPUT_DIR`, appends `DOCS_OPTIONS` after the template, and tests documentation from paths containing spaces.

## Design

Use `project(... LANGUAGES CXX)` in the README's C++-only examples and state that projects with C sources should use `LANGUAGES C CXX`. Add `FULL_PATH_NAMES = NO` and a quoted `STRIP_FROM_INC_PATH = "@INPUT_DIR@"` to the toolkit Doxyfile template. Keep `DOCS_OPTIONS` after the template defaults so explicit consumer settings take precedence; custom Doxyfiles remain unchanged.

The existing documentation test harness will check rendered file paths and include hints from a source path containing spaces, distinguish duplicate header basenames, and verify a later `DOCS_OPTIONS` override. It will continue to run Doxygen to verify the generated configuration is accepted.
