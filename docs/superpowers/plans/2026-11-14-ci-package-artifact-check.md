# CI Package Artifact Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace generated downstream-consumer testing with a check that the normal CI install produced the root package's config, version, and target-export files.

**Architecture:** Keep the workflow's existing `cmake --install` step and pass its prefix to the generated check script. The script verifies the three local package artifacts under the configured CMake install directory without staging dependencies or configuring a consumer.

**Tech Stack:** CMake script mode, CMake install rules, generated GitHub Actions workflow.

**Spec:** `docs/superpowers/specs/2026-11-14-ci-package-artifact-check-design.md`

## Global Constraints

- Do not recursively install subdirectories, build a downstream consumer, or call `find_package()`.
- Do not require additional client configuration.
- Leave dependency installation and discovery to the client.
- Keep the existing workflow install step responsible for install-time errors.

## Review Focus

- A missing prefix must fail with a useful error rather than succeeding through a self-staged install.
- A missing config, version, or targets file must fail the artifact check.
- A prefix containing spaces must work when passed from the generated workflow.
- A non-default `CMAKE_INSTALL_LIBDIR` must be honored.
- An absolute `CMAKE_INSTALL_LIBDIR` must not let stale files bypass a missing-prefix failure.
- The check must not configure or build a downstream consumer.

---

### Task 1: Check installed package artifacts in generated CI

**Files:**
- Modify: `cmake/cpp-library-ci.cmake`
- Modify: `cpp-library.cmake`
- Modify: `templates/test-package.cmake.in`
- Modify: `templates/.github/workflows/ci.yml.in`
- Modify: `tests/install/test_package_ci.cmake`

**Interfaces:**
- The generated script accepts `PACKAGE_TEST_PREFIX` as a `cmake -D` variable.
- The workflow passes the same `${{ runner.temp }}/install` prefix used by
  `cmake --install`.
- The generated script checks
  `<prefix>/<CMAKE_INSTALL_LIBDIR>/cmake/<PACKAGE_NAME>/` for
  `<PACKAGE_NAME>Config.cmake`, `<PACKAGE_NAME>ConfigVersion.cmake`, and
  `<PACKAGE_NAME>Targets.cmake`.

- [x] **Step 1: Rewrite the regression around the normal install prefix**

Replace the dependency-staging, external-dependency, and shadow-install cases
in `tests/install/test_package_ci.cmake` with focused artifact-check cases.
Configure the `single` fixture with `CMAKE_INSTALL_LIBDIR=lib64` and use an
install prefix whose path contains spaces. Before installing, invoke the
generated check with `PACKAGE_TEST_PREFIX` and require it to fail. Install the
fixture by executing the generated workflow's install command and require the
check to pass. For each required artifact, copy the install tree to a separate
prefix, remove that artifact, and require the check to fail. Also configure a
second fixture with an absolute `CMAKE_INSTALL_LIBDIR`, create stale artifact
files there, and verify a nonexistent install prefix still fails. Do not
configure or build a consumer.

- [x] **Step 2: Run the regression to confirm it exposes the old behavior**

Run: `cmake -P tests/install/test_package_ci.cmake`

Expected: FAIL because the current generated script ignores the supplied prefix
and stages its own package instead of rejecting the missing artifacts.

- [x] **Step 3: Generate a check script that verifies only local artifacts**

In `cmake/cpp-library-ci.cmake`, remove recursive install-list generation and
change the internal package-test helper and its `cpp-library.cmake` call site
to pass only the package name. Pass the configured `CMAKE_INSTALL_LIBDIR` to
`templates/test-package.cmake.in`. Replace the staging, consumer configure,
build, and CTest logic in that template with validation of `PACKAGE_TEST_PREFIX`
and explicit existence checks for the three required files. Report the missing
path in each failure.

- [x] **Step 4: Pass the workflow's existing install prefix to the check**

Update `templates/.github/workflows/ci.yml.in` so both install steps quote the
`${{ runner.temp }}/install` argument, and the artifact-check step passes that
same prefix as `PACKAGE_TEST_PREFIX`.

- [x] **Step 5: Run the focused packaging regression**

Run: `cmake -P tests/install/test_package_ci.cmake`

Expected: PASS for artifact presence and FAIL cases, including the absent
pre-install prefix, each missing artifact, a path containing spaces, `lib64`,
and stale artifacts under an absolute library directory.
