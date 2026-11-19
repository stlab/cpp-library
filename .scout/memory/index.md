# Memory Bank Index

## Knowledge

- [[knowledge/architecture-overview.md|Architecture Overview]] (concept, 0.80) `architecture-overview` `cpp-library-architecture` `cpp-library-overview` `toolkit-architecture` `cmake-infrastructure-overview`
- [[knowledge/consumer-lifecycle-and-template-overwrite-controls.md|Consumer Lifecycle and Template Overwrite Controls]] (decision, 0.75) `template-initialization` `cpp-library-force-init` `project-is-top-level` `lightweight-consumer-mode` `template-copying`
- [[knowledge/deferred-install-dependency-validation-and-config-generation.md|Deferred Install Dependency Validation and Config Generation]] (pattern, 0.75) `deferred-install` `install-validation` `untracked-dependencies` `cmake-language-defer` `find-dependency`
- [[knowledge/dependency-mappings-follow-the-exported-target-s-owning-project.md|Dependency mappings follow the exported target's owning project]] (discovery, 0.99) `cmake` `dependency-mappings` `project-scope` `deferred-install`
- [[knowledge/dependency-tracking-lifecycle-and-provider-ordering.md|Dependency Tracking Lifecycle and Provider Ordering]] (observation, 0.75) `dependency-tracking` `dependency-provider` `cpp-library-enable-dependency-tracking` `cmake-project-top-level-includes` `set-dependency-provider`
- [[knowledge/documentation-setup-and-theme-integration-with-build-docs.md|Documentation Setup and Theme Integration with BUILD_DOCS]] (pattern, 0.75) `build-docs` `doxygen` `doxygen-awesome-css` `documentation-generation` `docs-target`
- [[knowledge/generated-ci-package-artifact-check.md|Generated CI package artifact check]] (decision, 0.95) `ci` `packaging` `cmake`
- [[knowledge/installation-supports-separately-installed-dependencies-not-mixed-source-export-workarounds.md|Installation supports separately installed dependencies, not mixed source export workarounds]] (decision, 0.99) `cmake` `installation` `cpm` `supported-boundary`
- [[knowledge/target-naming-and-alias-deduplication-convention.md|Target Naming and Alias Deduplication Convention]] (pattern, 0.75) `target-naming` `alias-deduplication` `package-name` `clean-name` `cmake-alias-convention`
- [[knowledge/testing-and-example-executable-target-generation-gated-by-build-testing.md|Testing and Example Executable Target Generation Gated by BUILD_TESTING]] (pattern, 0.75) `build-testing` `doctest` `testing-setup` `negative-compilation-tests` `runtime-dll-copy`
- [[knowledge/version-overrides-must-not-leak-into-independently-named-subprojects.md|Version overrides must not leak into independently named subprojects]] (decision, 0.99) `cmake` `versions` `project-scope` `package-managers`

## Procedures

- [[procedures/interactive-and-headless-project-scaffolding-with-setup-cmake.md|Interactive and Headless Project Scaffolding with setup.cmake]] (procedure, 0.75) `setup-cmake` `project-scaffolding` `consumer-initialization` `standalone-generator` `cpp-library-setup-script`
