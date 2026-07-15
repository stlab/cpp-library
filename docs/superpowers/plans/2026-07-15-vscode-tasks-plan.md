# VSCode Tasks for CMake Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every `cpp-library` consumer project a `.vscode/tasks.json` (copied via the existing template mechanism) that provides one-click configure+build, build+test, and cleanup actions matching the presets in `templates/CMakePresets.json`.

**Architecture:** A new static JSON template (`templates/.vscode/tasks.json`) is registered in `_cpp_library_copy_templates()`'s existing `TEMPLATE_FILES` list, so it's copied into consumer projects under the same copy-if-missing / `CPP_LIBRARY_FORCE_INIT` rules as every other template. `templates/.vscode/extensions.json` gains a recommendation for the CMake Tools extension, which several tasks depend on. CI's existing "Validate template files" step is extended to catch regressions.

**Tech Stack:** CMake 3.24+ presets (`cmake --preset`, `cmake --build --preset`, `ctest --preset`), VS Code `tasks.json` schema (shell tasks, `command`-type inputs), VS Code CMake Tools extension commands (`cmake.setConfigurePreset`, `cmake.setBuildPreset`, `cmake.setTestPreset`, `cmake.buildDirectory`).

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-07-15-vscode-tasks-design.md` — follow it exactly; this plan implements it task-by-task.
- No changes to `templates/CMakePresets.json` — the new tasks must match its current preset set (`default`, `test`, `docs`, `clang-tidy`, `init`, `install`; test presets: `test`, `clang-tidy`, `init`).
- Build & Test tasks only for `test` and `clang-tidy` (not `init` — its `testPresets` entry isn't a real test run).
- All delete operations use `cmake -E rm -rf` (never `rm`/`Remove-Item`/`rmdir`) for cross-platform consistency.
- Every task that runs `--preset <name>` must also sync that name into the CMake Tools extension's active configure/build/test preset via the `${input:...}` command-substitution trick described in the spec — no exceptions, even though it adds boilerplate.
- `templates/` files are outputs copied into consumer projects, not inputs used by cpp-library's own build — don't wire them into cpp-library's own CMake configuration.

---

### Task 1: Add the `tasks.json` template and CMake Tools extension recommendation

**Files:**
- Create: `templates/.vscode/tasks.json`
- Modify: `templates/.vscode/extensions.json`

**Interfaces:**
- Produces: the template file at `templates/.vscode/tasks.json`, whose exact relative path (`.vscode/tasks.json`) Task 2 will register in `TEMPLATE_FILES`.

- [ ] **Step 1: Create `templates/.vscode/tasks.json`**

Create the file with exactly this content:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Configure & Build: Default Configuration",
      "type": "shell",
      "command": "cmake --preset default && cmake --build --preset default",
      "options": {
        "env": {
          "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-default} ${input:setBuildPreset-default}"
        }
      },
      "group": { "kind": "build", "isDefault": true },
      "problemMatcher": ["$gcc", "$msCompile"],
      "detail": "Default configuration for building the library"
    },
    {
      "label": "Configure & Build: Test Configuration",
      "type": "shell",
      "command": "cmake --preset test && cmake --build --preset test",
      "options": {
        "env": {
          "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-test} ${input:setBuildPreset-test}"
        }
      },
      "group": "build",
      "problemMatcher": ["$gcc", "$msCompile"],
      "detail": "Configuration for building and running tests"
    },
    {
      "label": "Configure & Build: Documentation Configuration",
      "type": "shell",
      "command": "cmake --preset docs && cmake --build --preset docs",
      "options": {
        "env": {
          "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-docs} ${input:setBuildPreset-docs}"
        }
      },
      "group": "build",
      "problemMatcher": ["$gcc", "$msCompile"],
      "detail": "Configuration for building documentation"
    },
    {
      "label": "Configure & Build: Clang-Tidy Configuration",
      "type": "shell",
      "command": "cmake --preset clang-tidy && cmake --build --preset clang-tidy",
      "options": {
        "env": {
          "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-clang-tidy} ${input:setBuildPreset-clang-tidy}"
        }
      },
      "group": "build",
      "problemMatcher": ["$gcc", "$msCompile"],
      "detail": "Configuration for running clang-tidy static analysis"
    },
    {
      "label": "Configure & Build: Initialize Templates",
      "type": "shell",
      "command": "cmake --preset init && cmake --build --preset init",
      "options": {
        "env": {
          "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-init} ${input:setBuildPreset-init}"
        }
      },
      "group": "build",
      "problemMatcher": ["$gcc", "$msCompile"],
      "detail": "Force regeneration of template files (CMakePresets.json, CI, etc.)"
    },
    {
      "label": "Configure & Build: Install Configuration",
      "type": "shell",
      "command": "cmake --preset install && cmake --build --preset install",
      "options": {
        "env": {
          "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-install} ${input:setBuildPreset-install}"
        }
      },
      "group": "build",
      "problemMatcher": ["$gcc", "$msCompile"],
      "detail": "Release build for installation with CPM_USE_LOCAL_PACKAGES enabled for testing installed packages"
    },
    {
      "label": "Build & Test: Run All Tests",
      "type": "shell",
      "command": "cmake --preset test && cmake --build --preset test && ctest --preset test",
      "options": {
        "env": {
          "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-test} ${input:setBuildPreset-test} ${input:setTestPreset-test}"
        }
      },
      "group": { "kind": "test", "isDefault": true },
      "problemMatcher": ["$gcc", "$msCompile"],
      "detail": "Configuration for building and running tests"
    },
    {
      "label": "Build & Test: Run Tests with Clang-Tidy",
      "type": "shell",
      "command": "cmake --preset clang-tidy && cmake --build --preset clang-tidy && ctest --preset clang-tidy",
      "options": {
        "env": {
          "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-clang-tidy} ${input:setBuildPreset-clang-tidy} ${input:setTestPreset-clang-tidy}"
        }
      },
      "group": "test",
      "problemMatcher": ["$gcc", "$msCompile"],
      "detail": "Configuration for running clang-tidy static analysis"
    },
    {
      "label": "Clean Build Directory (Active Config)",
      "type": "shell",
      "command": "cmake -E rm -rf \"${command:cmake.buildDirectory}\"",
      "detail": "Deletes the build directory for the CMake Tools extension's currently active configure preset. Requires the CMake Tools extension with an active preset selected."
    },
    {
      "label": "Clean Build Directory (All Presets)",
      "type": "shell",
      "command": "cmake -E rm -rf \"${workspaceFolder}/build\"",
      "detail": "Deletes the entire build/ directory, covering every preset's binary directory."
    },
    {
      "label": "Clean CPM Cache",
      "type": "shell",
      "command": "cmake -E rm -rf \"${workspaceFolder}/.cache/cpm\"",
      "detail": "Deletes the CPM dependency source cache (CPM_SOURCE_CACHE)."
    }
  ],
  "inputs": [
    { "id": "setConfigurePreset-default", "type": "command", "command": "cmake.setConfigurePreset", "args": "default" },
    { "id": "setConfigurePreset-test", "type": "command", "command": "cmake.setConfigurePreset", "args": "test" },
    { "id": "setConfigurePreset-docs", "type": "command", "command": "cmake.setConfigurePreset", "args": "docs" },
    { "id": "setConfigurePreset-clang-tidy", "type": "command", "command": "cmake.setConfigurePreset", "args": "clang-tidy" },
    { "id": "setConfigurePreset-init", "type": "command", "command": "cmake.setConfigurePreset", "args": "init" },
    { "id": "setConfigurePreset-install", "type": "command", "command": "cmake.setConfigurePreset", "args": "install" },
    { "id": "setBuildPreset-default", "type": "command", "command": "cmake.setBuildPreset", "args": "default" },
    { "id": "setBuildPreset-test", "type": "command", "command": "cmake.setBuildPreset", "args": "test" },
    { "id": "setBuildPreset-docs", "type": "command", "command": "cmake.setBuildPreset", "args": "docs" },
    { "id": "setBuildPreset-clang-tidy", "type": "command", "command": "cmake.setBuildPreset", "args": "clang-tidy" },
    { "id": "setBuildPreset-init", "type": "command", "command": "cmake.setBuildPreset", "args": "init" },
    { "id": "setBuildPreset-install", "type": "command", "command": "cmake.setBuildPreset", "args": "install" },
    { "id": "setTestPreset-test", "type": "command", "command": "cmake.setTestPreset", "args": "test" },
    { "id": "setTestPreset-clang-tidy", "type": "command", "command": "cmake.setTestPreset", "args": "clang-tidy" }
  ]
}
```

- [ ] **Step 2: Validate the new file is syntactically valid JSON**

Run: `python3 -m json.tool templates/.vscode/tasks.json`
Expected: pretty-printed JSON is echoed back, no error, exit code 0.

- [ ] **Step 3: Add the CMake Tools extension recommendation**

Modify `templates/.vscode/extensions.json` from:

```json
{
    "recommendations": [
        "matepek.vscode-catch2-test-adapter",
        "llvm-vs-code-extensions.vscode-clangd",
        "ms-vscode.live-server"
    ]
}
```

to:

```json
{
    "recommendations": [
        "matepek.vscode-catch2-test-adapter",
        "llvm-vs-code-extensions.vscode-clangd",
        "ms-vscode.live-server",
        "ms-vscode.cmake-tools"
    ]
}
```

- [ ] **Step 4: Validate `extensions.json` is still syntactically valid JSON**

Run: `python3 -m json.tool templates/.vscode/extensions.json`
Expected: pretty-printed JSON is echoed back, no error, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add templates/.vscode/tasks.json templates/.vscode/extensions.json
git commit -m "Add VSCode tasks template for CMake presets"
```

---

### Task 2: Register `tasks.json` in the template copy list

**Files:**
- Modify: `cmake/cpp-library-setup.cmake:139-146`

**Interfaces:**
- Consumes: `templates/.vscode/tasks.json` from Task 1 (must exist at that exact relative path, since `_cpp_library_copy_templates` builds `source_file` as `${CPP_LIBRARY_ROOT}/templates/${template_file}`).

- [ ] **Step 1: Add `.vscode/tasks.json` to `TEMPLATE_FILES`**

In `cmake/cpp-library-setup.cmake`, change:

```cmake
    set(TEMPLATE_FILES
        ".clang-format"
        ".gitignore"
        ".gitattributes"
        ".vscode/extensions.json"
        "docs/index.html"
        "CMakePresets.json"
    )
```

to:

```cmake
    set(TEMPLATE_FILES
        ".clang-format"
        ".gitignore"
        ".gitattributes"
        ".vscode/extensions.json"
        ".vscode/tasks.json"
        "docs/index.html"
        "CMakePresets.json"
    )
```

- [ ] **Step 2: Verify the copy behavior against a scratch consumer project**

Run (adjust the scratchpad path if yours differs; `<repo>` is this repository's absolute path):

```bash
SCRATCH="$(mktemp -d)"
mkdir -p "$SCRATCH/consumer"
cat > "$SCRATCH/consumer/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.24)
include(FetchContent)
FetchContent_Declare(CPM SOURCE_DIR "")
EOF
```

This throwaway `CMakeLists.txt` stub is not enough on its own — instead, follow the existing manual-exercise pattern already documented in this repo's `CLAUDE.md` ("To exercise cpp-library manually against a local consumer project"): create a minimal consumer project whose `CMakeLists.txt` calls `cpp_library_enable_dependency_tracking()`, `project(scratch-consumer)`, then `CPMAddPackage(NAME cpp-library SOURCE_DIR "<repo>")`, `include("${cpp-library_SOURCE_DIR}/cpp-library.cmake")`, and `cpp_library_setup(NAMESPACE scratch HEADERS "" )`. Configure it once:

```bash
cmake -S "$SCRATCH/consumer" -B "$SCRATCH/consumer/build"
```

Expected: configure succeeds, and `$SCRATCH/consumer/.vscode/tasks.json` now exists.

Then diff it against the template to confirm an exact, unmodified copy:

```bash
diff "$SCRATCH/consumer/.vscode/tasks.json" "<repo>/templates/.vscode/tasks.json"
```

Expected: no output (files identical).

- [ ] **Step 3: Commit**

```bash
git add cmake/cpp-library-setup.cmake
git commit -m "Register .vscode/tasks.json in template copy list"
```

---

### Task 3: End-to-end verification of the generated tasks' underlying commands

**Files:** none (scratch verification only; no repo changes).

**Interfaces:**
- Consumes: the scratch consumer project set up in Task 2, Step 2 (reuse or recreate it), and the 6 configure presets / 3 test presets / 3 clean commands defined in `templates/.vscode/tasks.json`.

This task can't drive the actual VS Code UI (no VS Code instance in this environment), so it verifies the one part that's fully headless-testable: that the shell command each task runs is itself correct. The `${input:...}` CMake Tools active-preset sync and the "Active Config" clean task's `${command:cmake.buildDirectory}` resolution require a live VS Code + CMake Tools session and can't be verified here — say so explicitly when reporting results.

- [ ] **Step 1: Run each "Configure & Build" task's underlying command**

In the scratch consumer project directory from Task 2 (`$SCRATCH/consumer`), run the exact command string from each Configure & Build task:

```bash
cd "$SCRATCH/consumer"
cmake --preset default && cmake --build --preset default
cmake --preset docs && cmake --build --preset docs
cmake --preset clang-tidy && cmake --build --preset clang-tidy
cmake --preset install && cmake --build --preset install
```

Expected: each pair completes with exit code 0. (Skip `init` here — it force-regenerates templates and was already exercised in Task 2; running it again is redundant.)

- [ ] **Step 2: Run the "Build & Test" tasks' underlying commands**

```bash
cmake --preset test && cmake --build --preset test && ctest --preset test
cmake --preset clang-tidy && cmake --build --preset clang-tidy && ctest --preset clang-tidy
```

Expected: both complete with exit code 0, and `ctest` reports tests run (even if the scratch consumer project has zero actual tests registered, `ctest --preset` itself must not error).

- [ ] **Step 3: Run the two extension-independent clean tasks**

```bash
cmake -E rm -rf "$SCRATCH/consumer/build"
test ! -d "$SCRATCH/consumer/build" && echo "build/ removed"

cmake -E rm -rf "$SCRATCH/consumer/.cache/cpm"
test ! -d "$SCRATCH/consumer/.cache/cpm" && echo ".cache/cpm removed"
```

Expected: both `echo` lines print — confirms `cmake -E rm -rf` deletes the target directories without error even when they contain files.

- [ ] **Step 4: Report the verification gap**

When reporting this task's results, state plainly that:
1. The shell commands underlying all 11 tasks were verified directly and work.
2. The CMake Tools active-preset sync (`${input:...}` triggering `cmake.setConfigurePreset`/`setBuildPreset`/`setTestPreset`) and the "Clean Build Directory (Active Config)" task's `${command:cmake.buildDirectory}` resolution were **not** verified, since they require opening the scratch consumer project in an actual VS Code window with the CMake Tools extension installed and a preset selected — recommend the user do a quick manual check there before relying on it.

- [ ] **Step 5: Clean up the scratch consumer project**

```bash
rm -rf "$SCRATCH"
```

(No commit — this task produces no repository changes.)
