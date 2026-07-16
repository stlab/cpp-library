# cpp-library Root Worktree VSCode Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give cpp-library's own root repo the "worktree: create" / "worktree: remove" VS Code tasks (with best-effort tokensave integration) that consumer projects already get from `templates/.vscode/tasks.json`, by creating a root `.vscode/tasks.json` containing just those two tasks, and fix the root `.gitignore` gap that currently leaves `.claude/worktrees/` untracked-but-not-ignored.

**Architecture:** New file `.vscode/tasks.json` at repo root, containing only the `worktreeName` input and the two worktree tasks copied verbatim from `templates/.vscode/tasks.json` (no CMake-preset/cleanup tasks — this repo has no `CMakePresets.json`). `.gitignore` gains two entries.

**Tech Stack:** VS Code `tasks.json` schema (shell tasks, `promptString` input, per-platform `"windows"` override), `git worktree`, the `tokensave` CLI.

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-07-16-cpp-library-worktree-tasks-design.md` — follow it exactly.
- Task command strings must be byte-identical to the corresponding tasks in `templates/.vscode/tasks.json` (same best-effort tokensave wrapping, same `windows` override) — no drift between the consumer-facing and self-hosting versions.
- Do not touch `templates/.vscode/tasks.json`, `templates/.gitignore`, or any `cmake/*.cmake` module — this plan only adds files/entries for cpp-library's own root, it doesn't change what gets shipped to consumers.
- Do not remove the existing `.worktrees/` entry from root `.gitignore` — out of scope per the design.

---

### Task 1: Add `.vscode/tasks.json` at repo root

**Files:**
- Create: `.vscode/tasks.json`

**Interfaces:**
- Produces: `worktree: create` / `worktree: remove` tasks and a `worktreeName` input at the repo root, usable directly from VS Code's Run Task menu when the cpp-library repo itself is open as the workspace.

- [ ] **Step 1: Create `.vscode/tasks.json`** with exactly this content:

```jsonc
{
  "version": "2.0.0",
  "inputs": [
    { "id": "worktreeName", "type": "promptString", "description": "Worktree name (e.g. my-feature) — branch will be worktree-<name>" }
  ],
  "tasks": [
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
      },
      "detail": "Prompts for a name, creates a git worktree at .claude/worktrees/<name> on branch worktree-<name>, best-effort syncs it with tokensave if installed, and opens it in a new window."
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
      },
      "detail": "Prompts for a name, removes the git worktree at .claude/worktrees/<name>, and best-effort garbage-collects tokensave's branch tracking if installed."
    }
  ]
}
```

- [ ] **Step 2: Validate as JSON** (this file has no comments, so plain JSON parsing works):

```bash
python3 -c 'import json; d = json.load(open(".vscode/tasks.json")); print("OK, tasks:", len(d["tasks"]), "inputs:", len(d["inputs"]))'
```

Expected: `OK, tasks: 2 inputs: 1`.

- [ ] **Step 3: Diff against the template's corresponding entries** to confirm byte-for-byte match of the task bodies:

```bash
python3 -c '
import json, re
new = json.load(open(".vscode/tasks.json"))
# templates/.vscode/tasks.json is JSONC (full-line // comments) - strip before parsing
text = open("templates/.vscode/tasks.json").read()
text = re.sub(r"^[ \t]*//.*$", "", text, flags=re.MULTILINE)
tmpl = json.loads(text)
tmpl_tasks = {t["label"]: t for t in tmpl["tasks"]}
for t in new["tasks"]:
    label = t["label"]
    assert t == tmpl_tasks[label], "mismatch: " + label
new_input = new["inputs"][0]
tmpl_input = next(i for i in tmpl["inputs"] if i["id"] == "worktreeName")
assert new_input == tmpl_input, "worktreeName input mismatch"
print("OK: root tasks.json entries match templates/.vscode/tasks.json verbatim")
'
```

Expected: `OK: root tasks.json entries match templates/.vscode/tasks.json verbatim`.

- [ ] **Step 4: Commit**

```bash
git add .vscode/tasks.json
git commit -m "Add worktree create/remove VSCode tasks for cpp-library's own repo"
```

---

### Task 2: Fix root `.gitignore` worktree-directory gap

**Files:**
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing from Task 1 (independent file).

- [ ] **Step 1: Add the two new entries**, leaving the existing `.worktrees/` line untouched:

Change `.gitignore` from:

```
.DS_Store
.superpowers/
.worktrees/
```

to:

```
.DS_Store
.superpowers/
.worktrees/
.claude/worktrees/
.tokensave
```

- [ ] **Step 2: Verify `git status` no longer shows `.claude/` as untracked** (assuming no other untracked content exists under it at this point):

```bash
git status --porcelain .claude/
```

Expected: no output (or only entries for content genuinely not covered by the new ignore rule, which should not exist here).

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "Ignore .claude/worktrees/ and .tokensave in cpp-library's own root gitignore"
```

---

### Task 3: End-to-end verification

**Files:** none (scratch verification only; no repository changes beyond Tasks 1-2).

**Interfaces:**
- Consumes: `.vscode/tasks.json` and `.gitignore` from Tasks 1 and 2.

This environment has both `tokensave` and `code` CLIs on `PATH`. Follow the same verification approach as `docs/superpowers/plans/2026-07-16-worktree-vscode-tasks-plan.md` Task 3, Steps 3-9 (testing the git+tokensave command prefix for both bash and cmd.exe forms, with tokensave present and simulated-absent, skipping the actual `code --new-window` GUI launch in favor of `code --version` as a liveness check) — run those same command strings here since they are byte-identical to what's now in root `.vscode/tasks.json`. No need to re-verify template-copying (Task 3 Step 2 of that plan) since this file isn't copied into consumer projects.

- [ ] **Step 1: Confirm both CLIs are present**

```bash
command -v tokensave
command -v code
```

Expected: both print a file path, exit 0.

- [ ] **Step 2: Set up a scratch git repo for command-behavior testing**

```bash
CMDTEST="$(mktemp -d)"
cd "$CMDTEST"
git init -q
git commit -q --allow-empty -m "init"
```

- [ ] **Step 3: Test "worktree: create" / "worktree: remove" (bash form, tokensave present)**

```bash
cd "$CMDTEST"
git worktree add ".claude/worktrees/myfeature" -b "worktree-myfeature" && (command -v tokensave >/dev/null 2>&1 && tokensave init ".claude/worktrees/myfeature" && tokensave branch add "worktree-myfeature" --path ".claude/worktrees/myfeature" || true)
echo "CREATE EXIT: $?"
git worktree list

git worktree remove ".claude/worktrees/myfeature" && (command -v tokensave >/dev/null 2>&1 && tokensave branch gc || true)
echo "REMOVE EXIT: $?"
git worktree list
```

Expected: both `EXIT: 0`, worktree present after create and gone after remove.

- [ ] **Step 4: Test bash form with tokensave simulated absent**

```bash
cd "$CMDTEST"
git worktree add ".claude/worktrees/myfeature2" -b "worktree-myfeature2" && (command -v tokensave-simulated-missing >/dev/null 2>&1 && tokensave-simulated-missing init ".claude/worktrees/myfeature2" && tokensave-simulated-missing branch add "worktree-myfeature2" --path ".claude/worktrees/myfeature2" || true)
echo "CREATE EXIT: $?"
git worktree remove ".claude/worktrees/myfeature2" && (command -v tokensave-simulated-missing >/dev/null 2>&1 && tokensave-simulated-missing branch gc || true)
echo "REMOVE EXIT: $?"
```

Expected: both `EXIT: 0`.

- [ ] **Step 5: Test the Windows/cmd.exe form (tokensave present)**

```bash
cd "$CMDTEST"
cmd.exe /d /c "git worktree add \".claude/worktrees/myfeature3\" -b \"worktree-myfeature3\" && (where tokensave >nul 2>&1 && (tokensave init \".claude/worktrees/myfeature3\" && tokensave branch add \"worktree-myfeature3\" --path \".claude/worktrees/myfeature3\") || ver>nul)"
echo "EXIT: $?"
cmd.exe /d /c "git worktree remove \".claude/worktrees/myfeature3\" && (where tokensave >nul 2>&1 && tokensave branch gc || ver>nul)"
echo "EXIT: $?"
```

Expected: both exit 0.

- [ ] **Step 6: Confirm `code` CLI liveness**

```bash
code --version
```

Expected: prints a version string, exit 0. (The real `&& code --new-window "..."` invocation is not exercised — opening a GUI window is out of scope for automated headless verification; note this explicitly in the report.)

- [ ] **Step 7: Clean up**

```bash
rm -rf "$CMDTEST"
```

(No commit — this task produces no repository changes.)

## Self-Review Notes

- **Spec coverage:** root `.vscode/tasks.json` with only the worktree tasks (Task 1), gitignore gap fix (Task 2) — both items from the design's Scope section covered.
- **Placeholder scan:** none found; every step has literal content.
- **Consistency check:** Task 1 Step 3 mechanically verifies the new file's task bodies are byte-identical to `templates/.vscode/tasks.json`'s, preventing silent drift between the two copies.
