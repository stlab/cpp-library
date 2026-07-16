# Worktree Create/Remove VSCode Tasks — Design

## Goal

Add the same "worktree: create" / "worktree: remove" VS Code tasks used in `github.com/stlab/cel-rs` to `templates/.vscode/tasks.json`, so consumer projects get one-click git-worktree management with tokensave integration, matching the reference example — but with the tokensave calls made best-effort so a consumer without `tokensave` installed still gets a fully working worktree create/remove.

## Reference (cel-rs, verbatim source)

`.vscode/tasks.json`:

```json
"inputs": [
    {
        "id": "worktreeName",
        "type": "promptString",
        "description": "Worktree name (e.g. my-feature) — branch will be worktree-<name>"
    }
],
"tasks": [
    {
        "label": "worktree: create",
        "type": "shell",
        "command": "git worktree add \".claude/worktrees/${input:worktreeName}\" -b \"worktree-${input:worktreeName}\" && tokensave init \".claude/worktrees/${input:worktreeName}\" && tokensave branch add \"worktree-${input:worktreeName}\" --path \".claude/worktrees/${input:worktreeName}\" && code --new-window \".claude/worktrees/${input:worktreeName}\"",
        "options": { "cwd": "${workspaceFolder}" },
        "problemMatcher": [],
        "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
        "label": "worktree: remove",
        "type": "shell",
        "command": "git worktree remove \".claude/worktrees/${input:worktreeName}\" && tokensave branch gc",
        "options": { "cwd": "${workspaceFolder}" },
        "problemMatcher": [],
        "presentation": { "reveal": "always", "panel": "dedicated" }
    }
]
```

`.gitignore`: `.claude/worktrees/` and `.tokensave` (both unanchored).

## Scope

Files touched:

1. `templates/.vscode/tasks.json` — convert to JSONC (adds `//` section-divider comments); add the `worktreeName` input and the two worktree tasks (adapted per below); add matching section-divider comments to the pre-existing CMake-preset and cleanup tasks now that the file supports comments.
2. `templates/.gitignore` — add `.claude/worktrees/` and `.tokensave`.

Not in scope: `templates/.vscode/extensions.json` (tokensave isn't a VS Code extension, nothing to recommend); cpp-library's own root `.vscode/` (it has no tasks.json of its own — only the template, which is consumer-facing).

## Adaptations from the reference

**1. JSONC conversion.** `templates/.vscode/tasks.json` has been strict JSON since it was created (validated via `python3 -m json.tool` in every prior task). cel-rs's file uses `//` comments. Per your direction, we're matching cel-rs's style, which means the validation method changes: a small regex preprocessor strips full-line `//` comments before parsing, since cel-rs's comments are always on their own line (never trailing after a JSON token):

```bash
python3 -c '
import json, re
text = open("templates/.vscode/tasks.json").read()
text = re.sub(r"^[ \t]*//.*$", "", text, flags=re.MULTILINE)
json.loads(text)
print("OK")
'
```
(Single-quoted outer `-c` argument, deliberately — a double-quoted bash string would let the shell itself interpolate the trailing `$` in the regex before Python ever sees it.)

**2. Best-effort tokensave (the change from your last question).** The reference chains `tokensave init && tokensave branch add` directly into the command with plain `&&`, so a missing `tokensave` binary would abort the whole task (same class of problem as the CMake Tools sync issue found in the previous feature's final review). Instead, the tokensave calls are wrapped in a group that always reports success, scoped so it can't mask a real `git worktree add`/`git worktree remove` failure:

Default (bash/zsh — macOS/Linux; also used as the base `command` VS Code falls back to):

```text
git worktree add ".claude/worktrees/${input:worktreeName}" -b "worktree-${input:worktreeName}" && (command -v tokensave >/dev/null 2>&1 && tokensave init ".claude/worktrees/${input:worktreeName}" && tokensave branch add "worktree-${input:worktreeName}" --path ".claude/worktrees/${input:worktreeName}" || true) && code --new-window ".claude/worktrees/${input:worktreeName}"
```

Windows override (per-task `"windows"` block overriding both `"command"` and the shell, same mechanism already used for the 8 CMake preset tasks — needed here because cmd.exe's existence-check syntax differs from bash's, not just because of `&&` support):

```text
git worktree add ".claude/worktrees/${input:worktreeName}" -b "worktree-${input:worktreeName}" && (where tokensave >nul 2>&1 && (tokensave init ".claude/worktrees/${input:worktreeName}" && tokensave branch add "worktree-${input:worktreeName}" --path ".claude/worktrees/${input:worktreeName}") || ver>nul) && code --new-window ".claude/worktrees/${input:worktreeName}"
```

`ver>nul` is a deliberate choice over `exit /b 0` — the latter risks terminating the whole `cmd.exe /c "..."` invocation early (since we're not inside a separate batch-file scope), which would skip `code --new-window` entirely. `ver` is a harmless always-succeeds no-op.

`worktree: remove` follows the identical pattern with `tokensave branch gc` in place of init/branch-add, and no trailing `code` call to protect.

Net effect: if `tokensave` is missing OR present-but-erroring, the worktree is still created/removed and the editor still opens — tokensave bookkeeping is strictly secondary to the primary git operation, matching the design principle already established for the CMake Tools sync.

**3. Windows `&&` compatibility.** Same fix already applied to the 8 CMake preset tasks last session (Windows PowerShell 5.1 doesn't support `&&`) — covered by the same `"windows"` override above, so no separate change needed.

**4. Placement and organization.** The two new tasks and the `worktreeName` input go at the top of their respective arrays (matching cel-rs's placement and being the natural first stop for someone opening a new consumer project). Section-divider comments are added:

- `// ============ Worktree Tasks ============` above the two new tasks
- `// ============ CMake Preset Tasks ============` above the existing "Configure & Build: Default Configuration" (the first pre-existing task)
- `// ============ Cleanup Tasks ============` above "Clean Build Directory (Active Config)" (the first pre-existing clean task)

**5. Gitignore.** Both `.claude/worktrees/` and `.tokensave` added to `templates/.gitignore`, unanchored, matching cel-rs exactly — since the copied tasks generate both.

## Process for this change

Per your instruction: this work happens in an isolated worktree (default `.worktrees/` location — no existing worktree-directory convention in this repo to follow, and no explicit override given for the controller's own dev tooling), finishing with a pushed branch + PR rather than a direct push to `main`.
