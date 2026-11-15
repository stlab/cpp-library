# README and Doxygen Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the bounded README language-selection and generated Doxygen path-default issues.

**Architecture:** Update the existing README examples and toolkit Doxygen template. Extend the existing documentation integration fixture and test script; do not add a new public API or alter custom Doxyfiles.

**Tech Stack:** CMake 3.24+, Doxygen, Markdown.

**Spec:** `docs/superpowers/specs/2026-11-14-readme-doxygen-defaults-design.md`

## Global Constraints

- Keep client `DOCS_OPTIONS` overrides effective by appending them after template defaults.
- Keep custom `docs/Doxyfile` settings under consumer control.
- Quote the configured include root so spaces in the source path remain valid.
- Use `LANGUAGES C CXX` in examples for projects that contain C sources.

## Review Focus

- C++-only project examples must not enable C implicitly; verify each affected README declaration uses `LANGUAGES CXX`.
- The generated include root may contain spaces; assert the quoted value in the generated Doxyfile and run Doxygen.
- Consumer overrides must follow and supersede the shared defaults; configure an override case and run Doxygen.
- Custom Doxyfiles must not inherit toolkit-template defaults; preserve and run the existing custom-Doxyfile case.
- Duplicate header basenames must remain distinguishable under Doxygen's shortest-unique-path behavior; include duplicate basenames in the default-path fixture and verify the generated file index.

---

### Task 1: Clarify README project languages

**Files:**
- Modify: `README.md` C++-only project examples

**Interfaces:**
- Consumes: Existing project and consumer setup examples.
- Produces: Every C++-only example uses `LANGUAGES CXX`, with guidance to use `LANGUAGES C CXX` when C sources are present.

- [ ] **Step 1: Update the C++-only declarations and add the C-source note**

Change `project(your-library)` and `project(my-library)` to include `LANGUAGES CXX`. Add a sentence near the examples that directs projects with C sources to use `LANGUAGES C CXX`.

- [ ] **Step 2: Review all README project examples**

Confirm the existing `project(stlab LANGUAGES CXX)` example remains unchanged and that every C++-only example selects CXX.

### Task 2: Set and test Doxygen path defaults

**Files:**
- Modify: `templates/Doxyfile.in`
- Modify: `tests/docs/fixtures/CMakeLists.txt`
- Modify: `tests/docs/test_docs.cmake`

**Interfaces:**
- Consumes: `INPUT_DIR` and `DOCS_OPTIONS` from `cmake/cpp-library-docs.cmake`.
- Produces: Generated Doxyfiles with `FULL_PATH_NAMES = NO` and quoted `STRIP_FROM_INC_PATH = "@INPUT_DIR@"`; consumer options remain later in the file.

- [ ] **Step 1: Add regression cases for defaults, path spaces, duplicate basenames, and overrides**

In the existing docs fixture, create a second documented header with the same basename under a different include subdirectory. Add a case with `DOCS_OPTIONS` setting `FULL_PATH_NAMES = YES` and an explicit `STRIP_FROM_PATH`. In `tests/docs/test_docs.cmake`, assert the directory hierarchy distinguishes both file-list entries, the class include hint retains the namespace-relative path, default file references omit the absolute source path, and the override's file reference is relative to the project root.

- [ ] **Step 2: Run the documentation test and confirm the new checks fail**

Run: `cmake -P tests/docs/test_docs.cmake`

Expected: The default include hint still contains the `include/` prefix, showing that the test detects the missing include-path setting.

- [ ] **Step 3: Add the Doxygen template defaults**

Add `FULL_PATH_NAMES = NO` and `STRIP_FROM_INC_PATH = "@INPUT_DIR@"` to `templates/Doxyfile.in`. Do not add a default `STRIP_FROM_PATH`; keep consumer `DOCS_OPTIONS` appended after the template and leave the custom-Doxyfile path unchanged.

- [ ] **Step 4: Run the documentation test**

Run: `cmake -P tests/docs/test_docs.cmake`

Expected: All documentation cases pass, including the default path, duplicate-basename, override, and custom-Doxyfile cases.
