# Worktree Create/Remove VSCode Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cel-rs's "worktree: create" / "worktree: remove" VS Code tasks (git-worktree management with tokensave integration) to `templates/.vscode/tasks.json`, with the tokensave calls made best-effort so consumers without `tokensave` installed still get a fully working worktree create/remove.

**Architecture:** `templates/.vscode/tasks.json` converts from strict JSON to JSONC (adding `//` section-divider comments, matching cel-rs's style); one new `promptString` input and two new tasks are added at the top of their respective arrays. `templates/.gitignore` gains two entries for the directories/files those tasks generate. Neither file needs re-registering in `cmake/cpp-library-setup.cmake` — both are already in `TEMPLATE_FILES` from prior work.

**Tech Stack:** VS Code `tasks.json` schema (shell tasks, `promptString` inputs, per-platform `"windows"` overrides), `git worktree`, the `tokensave` CLI.

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-07-16-worktree-vscode-tasks-design.md` — follow it exactly.
- The new tasks and input go at the **top** of their arrays (matching cel-rs's placement).
- `templates/.vscode/tasks.json` is no longer strict JSON — validate it going forward with the comment-tolerant regex check in Task 1, not `python3 -m json.tool` directly.
- Tokensave calls in both new tasks must be best-effort: skipped cleanly if `tokensave` isn't on PATH, and non-fatal even if present-but-erroring — never able to block `git worktree add`/`git worktree remove` or (for create) `code --new-window`.
- No changes to `cmake/cpp-library-setup.cmake`, `templates/.vscode/extensions.json`, or cpp-library's own root `.vscode/` — out of scope per the spec.

---

### Task 1: Add worktree tasks to `templates/.vscode/tasks.json`

**Files:**
- Modify: `templates/.vscode/tasks.json` (full-file replacement — every existing task gains no functional change, only the addition of section-divider comments and the two new tasks/input)

**Interfaces:**
- Produces: `worktree: create` and `worktree: remove` tasks, and a `worktreeName` promptString input, all live at `templates/.vscode/tasks.json`. Task 3 verifies these directly; no other task depends on their internals.

- [ ] **Step 1: Replace the full contents of `templates/.vscode/tasks.json`**

Replace the entire file with exactly this content:

```json
{
  "version": "2.0.0",
  "inputs": [
    { "id": "worktreeName", "type": "promptString", "description": "Worktree name (e.g. my-feature) — branch will be worktree-<name>" },
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
  ],
  "tasks": [
    // ============ Worktree Tasks ============
    {
      "label": "worktree: create",
      "type": "shell",
      "command": "git worktree add \".claude/worktrees/${input:worktreeName}\" -b \"worktree-${input:worktreeName}\" && (command -v tokensave >/dev/null 2>&1 && tokensave init \".claude/worktrees/${input:worktreeName}\" && tokensave branch add \"worktree-${input:worktreeName}\" --path \".claude/worktrees/${input:worktreeName}\" || true) && code --new-window \".claude/worktrees/${input:worktreeName}\"",
      "options": {
        "cwd": "${workspaceFolder}"
      },
      "windows": {
        "command": "git worktree add \".claude/worktrees/${input:worktreeName}\" -b \"worktree-${input:worktreeName}\" && (where tokensave >nul 2>&1 && (tokensave init \".claude/worktrees/${input:worktreeName}\" && tokensave branch add \"worktree-${input:worktreeName}\" --path \".claude/worktrees/${input:worktreeName}\") || ver>nul) && code --new-window \".claude/worktrees/${input:worktreeName}\"",
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      },
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated"
      }
    },
    {
      "label": "worktree: remove",
      "type": "shell",
      "command": "git worktree remove \".claude/worktrees/${input:worktreeName}\" && (command -v tokensave >/dev/null 2>&1 && tokensave branch gc || true)",
      "options": {
        "cwd": "${workspaceFolder}"
      },
      "windows": {
        "command": "git worktree remove \".claude/worktrees/${input:worktreeName}\" && (where tokensave >nul 2>&1 && tokensave branch gc || ver>nul)",
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      },
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated"
      }
    },
    // ============ CMake Preset Tasks ============
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
      "detail": "Default configuration for building the library Requires the CMake Tools extension (ms-vscode.cmake-tools) — without it, this task fails to start.",
      "windows": {
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      }
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
      "detail": "Configuration for building and running tests Requires the CMake Tools extension (ms-vscode.cmake-tools) — without it, this task fails to start.",
      "windows": {
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      }
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
      "detail": "Configuration for building documentation Requires the CMake Tools extension (ms-vscode.cmake-tools) — without it, this task fails to start.",
      "windows": {
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      }
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
      "detail": "Configuration for running clang-tidy static analysis Requires the CMake Tools extension (ms-vscode.cmake-tools) — without it, this task fails to start.",
      "windows": {
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      }
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
      "detail": "Force regeneration of template files (CMakePresets.json, CI, etc.) Requires the CMake Tools extension (ms-vscode.cmake-tools) — without it, this task fails to start.",
      "windows": {
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      }
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
      "detail": "Release build for installation with CPM_USE_LOCAL_PACKAGES enabled for testing installed packages Requires the CMake Tools extension (ms-vscode.cmake-tools) — without it, this task fails to start.",
      "windows": {
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      }
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
      "detail": "Configuration for building and running tests Requires the CMake Tools extension (ms-vscode.cmake-tools) — without it, this task fails to start.",
      "windows": {
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      }
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
      "detail": "Configuration for running clang-tidy static analysis Requires the CMake Tools extension (ms-vscode.cmake-tools) — without it, this task fails to start.",
      "windows": {
        "options": {
          "shell": {
            "executable": "cmd.exe",
            "args": ["/d", "/c"]
          }
        }
      }
    },
    // ============ Cleanup Tasks ============
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
  ]
}
```

- [ ] **Step 2: Validate the file as JSONC (comment-tolerant)**

Run:

```bash
python3 -c '
import json, re
text = open("templates/.vscode/tasks.json").read()
text = re.sub(r"^[ \t]*//.*$", "", text, flags=re.MULTILINE)
data = json.loads(text)
print("OK, tasks:", len(data["tasks"]), "inputs:", len(data["inputs"]))
'
```

Expected: `OK, tasks: 13 inputs: 15` (11 pre-existing tasks + 2 new; 14 pre-existing inputs + 1 new).

- [ ] **Step 3: Commit**

```bash
git add templates/.vscode/tasks.json
git commit -m "Add worktree create/remove VSCode tasks with best-effort tokensave sync"
```

---

### Task 2: Gitignore the worktree directory and tokensave state

**Files:**
- Modify: `templates/.gitignore`

**Interfaces:**
- Consumes: nothing from Task 1 (independent file).

- [ ] **Step 1: Add the two new entries**

Change `templates/.gitignore` from:

```
# Auto-generated from cpp-library (https://github.com/stlab/cpp-library)
# Do not edit this file directly - it will be overwritten when templates are regenerated

/.cpm-cache
/.cache
/build
.DS_Store
compile_commands.json
```

to:

```
# Auto-generated from cpp-library (https://github.com/stlab/cpp-library)
# Do not edit this file directly - it will be overwritten when templates are regenerated

/.cpm-cache
/.cache
/build
.DS_Store
compile_commands.json
.claude/worktrees/
.tokensave
```

- [ ] **Step 2: Commit**

```bash
git add templates/.gitignore
git commit -m "Gitignore worktree directory and tokensave state in consumer template"
```

---

### Task 3: End-to-end verification

**Files:** none (scratch verification only; no repository changes).

**Interfaces:**
- Consumes: `templates/.vscode/tasks.json` and `templates/.gitignore` from Tasks 1 and 2.

This environment has both `tokensave` and `code` CLIs on `PATH` (confirm with `command -v tokensave` and `command -v code` — both should print a path). That lets the "tokensave present" branch of each task be tested for real. The "tokensave absent" branch is tested by substituting a guaranteed-nonexistent command name (`tokensave-simulated-missing`) in place of `tokensave` in a copy of the command string — this exercises the exact same conditional logic without needing to hide the real binary via PATH manipulation (which is fragile to test correctly across Git Bash / cmd.exe boundary translation). Actually running `code --new-window` is skipped in automated verification (it would open a real GUI window); `code --version` is used instead as a lightweight liveness check of the same binary the real command would invoke.

- [ ] **Step 1: Confirm both CLIs are present**

```bash
command -v tokensave
command -v code
```

Expected: both print a file path, exit 0.

- [ ] **Step 2: Verify the template copies correctly into a scratch consumer project**

```bash
SCRATCH="$(mktemp -d)"
mkdir -p "$SCRATCH/cmake" "$SCRATCH/include/wtcheck/wtcheck"
curl -fsSL https://github.com/cpm-cmake/CPM.cmake/releases/latest/download/get_cpm.cmake -o "$SCRATCH/cmake/CPM.cmake"
echo "#pragma once" > "$SCRATCH/include/wtcheck/wtcheck.hpp"
cat > "$SCRATCH/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.24)
include(cmake/CPM.cmake)
CPMAddPackage(
    NAME cpp-library
    SOURCE_DIR "D:/repos/github.com/stlab/cpp-library"
)
include("${cpp-library_SOURCE_DIR}/cpp-library.cmake")
cpp_library_enable_dependency_tracking()
project(wtcheck)
include(CTest)
cpp_library_setup(
    DESCRIPTION "Scratch consumer project for worktree-task template verification"
    NAMESPACE wtcheck
    HEADERS "include/wtcheck/wtcheck.hpp"
)
EOF
cmake -S "$SCRATCH" -B "$SCRATCH/build" 2>&1 | grep "Copied template file"
diff "$SCRATCH/.vscode/tasks.json" templates/.vscode/tasks.json
diff "$SCRATCH/.gitignore" templates/.gitignore
```

Expected: the `grep` shows `-- Copied template file: .vscode/tasks.json` and `-- Copied template file: .gitignore` among its output (confirming both were freshly copied, not skipped as already-present), and both `diff` commands produce no output (byte-identical copies).

- [ ] **Step 3: Set up a scratch git repo for command-behavior testing**

```bash
CMDTEST="$(mktemp -d)"
cd "$CMDTEST"
git init -q
git commit -q --allow-empty -m "init"
```

- [ ] **Step 4: Test "worktree: create" (bash form, tokensave present)**

Run the exact command string from the task, substituting `myfeature` for `${input:worktreeName}`:

```bash
cd "$CMDTEST"
git worktree add ".claude/worktrees/myfeature" -b "worktree-myfeature" && (command -v tokensave >/dev/null 2>&1 && tokensave init ".claude/worktrees/myfeature" && tokensave branch add "worktree-myfeature" --path ".claude/worktrees/myfeature" || true)
echo "EXIT: $?"
git worktree list
```

Expected: `EXIT: 0`, and `git worktree list` shows both the main worktree and `.claude/worktrees/myfeature` on branch `worktree-myfeature`.

- [ ] **Step 5: Test "worktree: remove" (bash form, tokensave present)**

```bash
cd "$CMDTEST"
git worktree remove ".claude/worktrees/myfeature" && (command -v tokensave >/dev/null 2>&1 && tokensave branch gc || true)
echo "EXIT: $?"
git worktree list
```

Expected: `EXIT: 0`, and `git worktree list` no longer shows `.claude/worktrees/myfeature`.

- [ ] **Step 6: Test "worktree: create" / "worktree: remove" (bash form, tokensave simulated absent)**

Same as Steps 4–5, but with `tokensave` replaced by a nonexistent command name in the copied string:

```bash
cd "$CMDTEST"
git worktree add ".claude/worktrees/myfeature2" -b "worktree-myfeature2" && (command -v tokensave-simulated-missing >/dev/null 2>&1 && tokensave-simulated-missing init ".claude/worktrees/myfeature2" && tokensave-simulated-missing branch add "worktree-myfeature2" --path ".claude/worktrees/myfeature2" || true)
echo "CREATE EXIT: $?"
git worktree list

git worktree remove ".claude/worktrees/myfeature2" && (command -v tokensave-simulated-missing >/dev/null 2>&1 && tokensave-simulated-missing branch gc || true)
echo "REMOVE EXIT: $?"
git worktree list
```

Expected: both `EXIT: 0` lines, worktree appears after create and is gone after remove — proving the worktree is created/removed successfully even when the tokensave binary doesn't exist.

- [ ] **Step 7: Test the Windows/cmd.exe form (tokensave present)**

```bash
cd "$CMDTEST"
cmd.exe /d /c "git worktree add \".claude/worktrees/myfeature3\" -b \"worktree-myfeature3\" && (where tokensave >nul 2>&1 && (tokensave init \".claude/worktrees/myfeature3\" && tokensave branch add \"worktree-myfeature3\" --path \".claude/worktrees/myfeature3\") || ver>nul)"
echo "EXIT: $?"
git worktree list
cmd.exe /d /c "git worktree remove \".claude/worktrees/myfeature3\" && (where tokensave >nul 2>&1 && tokensave branch gc || ver>nul)"
echo "EXIT: $?"
git worktree list
```

Expected: both exit 0; worktree present after create, gone after remove.

- [ ] **Step 8: Test the Windows/cmd.exe form (tokensave simulated absent)**

```bash
cd "$CMDTEST"
cmd.exe /d /c "git worktree add \".claude/worktrees/myfeature4\" -b \"worktree-myfeature4\" && (where tokensave-simulated-missing >nul 2>&1 && (tokensave-simulated-missing init \".claude/worktrees/myfeature4\" && tokensave-simulated-missing branch add \"worktree-myfeature4\" --path \".claude/worktrees/myfeature4\") || ver>nul)"
echo "EXIT: $?"
git worktree list
cmd.exe /d /c "git worktree remove \".claude/worktrees/myfeature4\" && (where tokensave-simulated-missing >nul 2>&1 && tokensave-simulated-missing branch gc || ver>nul)"
echo "EXIT: $?"
git worktree list
```

Expected: both exit 0; worktree present after create, gone after remove — proving the cmd.exe conditional syntax (`where` / `ver>nul`) behaves the same as the bash form when the binary is absent.

- [ ] **Step 9: Confirm `code` CLI liveness without opening a new window**

```bash
code --version
```

Expected: prints a version string, exit 0. (The actual `&& code --new-window "..."` invocation at the end of the real task is not exercised here — opening a real editor window is outside what automated headless verification should do. Note this explicitly in the report, same as the CMake Tools extension-dependent behaviors noted in the prior feature's verification.)

- [ ] **Step 10: Clean up scratch directories**

```bash
rm -rf "$SCRATCH" "$CMDTEST"
```

(No commit — this task produces no repository changes.)

## Self-Review Notes

- **Spec coverage:** JSONC conversion (Task 1, Step 1-2), best-effort tokensave wrapping for both tasks and both platforms (Task 1, Step 1; verified in Task 3 Steps 4-8), section-divider comments (Task 1, Step 1), gitignore additions (Task 2), placement at top of arrays (Task 1, Step 1) — all covered.
- **Placeholder scan:** none found; every step has literal content.
- **Type/name consistency:** `worktreeName` input id matches across both new tasks' `${input:worktreeName}` references; no drift.
