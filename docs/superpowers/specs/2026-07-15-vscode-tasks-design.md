# VSCode Tasks for CMake Presets — Design

## Goal

Add a `templates/.vscode/tasks.json` to the set of template files `cpp_library_setup()` copies into a consumer project, giving every consumer one-click VS Code tasks that mirror the presets already defined in `templates/CMakePresets.json`, plus housekeeping tasks to clean the build tree and the CPM cache.

## Scope

Files touched:

1. `templates/.vscode/tasks.json` (new)
2. `templates/.vscode/extensions.json` — add `ms-vscode.cmake-tools` to `recommendations`
3. `cmake/cpp-library-setup.cmake` — add `.vscode/tasks.json` to the `TEMPLATE_FILES` list in `_cpp_library_copy_templates()`, so it's copied under the same copy-if-missing / `CPP_LIBRARY_FORCE_INIT` rules as the other templates

No changes to `CMakePresets.json` itself — the tasks are generated to match its current preset set:

- `configurePresets` / `buildPresets`: `default`, `test`, `docs`, `clang-tidy`, `init`, `install`
- `testPresets`: `test`, `clang-tidy`, `init`

## Task inventory (11 tasks)

**Configure & Build — one per configure/build preset (6 tasks):**

Each runs `cmake --preset <name> && cmake --build --preset <name>`. `default`'s task is the default `build`-group task (bound to Ctrl+Shift+B).

**Build & Test — one per preset that has a meaningful test run (2 tasks: `test`, `clang-tidy` — not `init`, whose `testPresets` entry exists only to support the init workflow and isn't a real test run):**

Each runs `cmake --preset <name> && cmake --build --preset <name> && ctest --preset <name>`. `test`'s task is the default `test`-group task.

**Clean tasks (3 tasks):**

- **Clean Build Directory (Active Config)** — `cmake -E rm -rf "${command:cmake.buildDirectory}"`. Relies on the CMake Tools extension (hence the new `extensions.json` recommendation) to resolve the currently-selected preset's binary directory. If the extension isn't installed, VS Code reports the command as unresolvable and the task doesn't run — there's no silent fallback, since `${command:...}` substitution happens before the task starts and there's no way to branch on whether it succeeded.
- **Clean Build Directory (All Presets)** — `cmake -E rm -rf "${workspaceFolder}/build"`. Always works; the explicit fallback for when the active-config task can't resolve.
- **Clean CPM Cache** — `cmake -E rm -rf "${workspaceFolder}/.cache/cpm"`.

All delete operations use `cmake -E rm -rf` (not `rm`/`Remove-Item`/`rmdir`) so the same command works unmodified on Windows/macOS/Linux — CMake is already a hard dependency of every consumer project.

## Syncing the CMake Tools active configuration

Every task that invokes `--preset <name>` should also set that preset as the CMake Tools extension's active configure/build/test preset (so the status bar and other extension features — e.g. the active-config clean task above — stay in sync with whatever was last run from the task list).

Confirmed by reading `microsoft/vscode-cmake-tools`'s `src/extension.ts`: the extension registers `cmake.setConfigurePreset(presetName, folder?)`, `cmake.setBuildPreset(presetName, folder?)`, and `cmake.setTestPreset(presetName, folder?)` as real commands (distinct from the interactive `cmake.selectConfigurePreset` family, which shows a picker). These aren't listed in `package.json`'s `contributes.commands` (so they won't appear in the Command Palette), but they're registered via the standard `vscode.commands.registerCommand` mechanism and are callable via `executeCommand`.

tasks.json has no native "invoke this command with this argument" task step — the only place VS Code lets a command take an argument from tasks.json is a `"type": "command"` **input**, which supports an `args` field. The plan:

- Define one input per `(command, preset-name)` pair actually needed:
  - `setConfigurePreset-<name>` for each of the 6 configure presets
  - `setBuildPreset-<name>` for each of the 6 build presets
  - `setTestPreset-<name>` for `test` and `clang-tidy`
  - 14 inputs total
- Each Configure & Build task references its own `setConfigurePreset-<name>` and `setBuildPreset-<name>` inputs inside an otherwise-unused `options.env` entry, e.g.:
  ```json
  "options": { "env": { "CMAKE_TOOLS_SYNC": "${input:setConfigurePreset-default} ${input:setBuildPreset-default}" } }
  ```
  VS Code resolves `${input:...}` substitutions (running the underlying command with its `args`) before the shell command executes, so this reliably runs `cmake.setConfigurePreset`/`cmake.setBuildPreset` as a side effect ahead of the real `cmake` invocation. The env var itself is never read by anything.
- Each Build & Test task (`test`, `clang-tidy`) does the same for all three: `setConfigurePreset-<name>`, `setBuildPreset-<name>`, `setTestPreset-<name>`.
- The clean tasks don't use `--preset` and get no sync entries.

This is a known-but-unusual VS Code pattern (an unused env var purely to trigger a side-effecting command substitution). It was chosen deliberately after confirming no cleaner native mechanism exists in tasks.json for firing a command-with-argument as a task step.

## Other task properties

- `problemMatcher: ["$gcc", "$msCompile"]` on every Configure & Build / Build & Test task, since the generator is fixed to Ninja but the actual compiler (gcc/clang vs. MSVC `cl.exe`) varies by platform — both matchers can be present simultaneously without conflict.
- `detail` on each task mirrors the matching preset's `description` from `CMakePresets.json`, so the task picker gives the same context the CMake preset picker does.

## Out of scope

- No changes to `CMakePresets.json` presets themselves.
- No attempt to auto-detect whether the CMake Tools extension is installed and branch task behavior on that — the two clean-build-dir tasks are presented as separate, explicit choices instead.
- No handling for consumer projects that add their own custom presets on top of the template — this only covers the presets shipped in `templates/CMakePresets.json` at generation time. If a consumer edits `CMakePresets.json` later, `tasks.json` doesn't stay in sync automatically (same as today's relationship between the two files already-templated in this repo).
