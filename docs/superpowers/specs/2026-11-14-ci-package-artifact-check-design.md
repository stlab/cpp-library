# CI Package Artifact Check — Design

## Goal

Replace the generated downstream-consumer test with a check that the normal CI
install produced the root package's config, version, and exported-target files.
This keeps CI independent of how clients install dependencies; it does not
claim to validate downstream `find_package()` resolution.

## Scope

- Keep the generated workflow's normal `cmake --install` step.
- Pass its install prefix to the generated package-check script.
- Check for `<PACKAGE_NAME>Config.cmake`,
  `<PACKAGE_NAME>ConfigVersion.cmake`, and
  `<PACKAGE_NAME>Targets.cmake` under the package's configured CMake install
  directory.
- Add focused regression coverage for present and missing artifacts.

## Approaches

- **Stage dependencies and configure a consumer.** Rejected because CI cannot
  infer how arbitrary dependencies are installed or discovered without
  client-specific inputs.
- **Rely on install success alone.** Simpler, but does not detect a successful
  install that omitted the local package files.
- **Check local package artifacts.** Selected because it verifies the root
  package's install output without requiring dependency configuration.

## Constraints and non-goals

The check must not recursively install subdirectories, build a downstream
consumer, call `find_package()`, or require additional client configuration.
Dependency installation and discovery remain the client's responsibility.
The existing install step remains responsible for reporting install-time
errors.
