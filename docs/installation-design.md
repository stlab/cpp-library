# Installation design

This document records the installation policy and the recommendation for
[#37](https://github.com/stlab/cpp-library/issues/37). It is for maintainers
evaluating installation changes, not a guide to distributing a complete
application or dependency bundle.

## Goals and boundaries

- Strongly discourage installation workflows. Use CPM to consume and build
  dependencies from source unless a package manager or another specific
  requirement calls for installation.
- Installing a component does not install its dependencies. CMake cannot
  generally provide that guarantee across arbitrary dependencies and build
  systems. The client or package manager is responsible for making those
  dependencies available.
- Provide component install rules and dependency information for package
  managers and other explicit installation workflows. Do not treat the
  resulting artifacts as self-contained, distributable packages with their
  dependencies included.
- Minimize installation-specific requirements in client `CMakeLists.txt`
  files. Most clients following the recommended CPM workflow should not need
  additional installation configuration.

These are design goals, not a claim that every existing example or API already
meets them. In particular, the README describes installation as optional but
does not yet state this policy as strongly.

## Existing behavior

`cpp_library_setup()` creates install rules when its selected installation
option is enabled. The option is `INSTALL_OPTION`, if specified, or the
uppercase namespace followed by `_INSTALL`. Its default is
`PROJECT_IS_TOP_LEVEL`; an existing option value is preserved. These rules
do not execute during an ordinary build.

An explicit install can produce headers, library artifacts, and CMake package
configuration and target exports. The generated configuration contains
`find_dependency()` calls for detected public dependencies; those calls locate
dependencies and do not install them. Tracking and mapping have limits, and
untracked dependencies can prevent installation. See the
[installation module](../cmake/cpp-library-install.cmake) and
[dependency handling documentation](../README.md#dependency-handling-in-installed-packages).

Install options select which toolkit packages contribute rules to a build.
If several packages share an enabled namespace option, an install of that build
can execute rules for more than one package. That is not a general mechanism
for installing a component's dependency closure: other dependencies may use
different options, come from installed packages, or have unrelated install
behavior. `INSTALL_OPTION` permits independently controlled packages in the
same namespace.

## Issue #37

The shared namespace option is initialized when each package calls
`cpp_library_setup()`, not when the top-level project begins. If a
same-namespace dependency is configured first, it can create the shared option
with a subproject default of `OFF`. The top-level package then preserves that
value, so its install rules are disabled even though its own default would
otherwise be `ON`. An existing cache value also persists across configurations.
This affects installation-rule selection, not normal source consumption.

An installation user can set the shared option explicitly at configuration
time, for example `-DCEL_INSTALL=ON`. This can also enable rules for other
packages using that option; it does not ensure their dependencies are
available. A project that needs to establish the default before loading
dependencies can declare the option after `project()` and before those
dependencies. A package that requires independent control can use a distinct
`INSTALL_OPTION`. These are existing mechanisms, not a requirement for every
CPM client.

## Recommendation

**Defer #37 without changing the implementation or adding an initializer.**
The gap was discovered during review, and no client has reported it as a
problem. An early initializer would replace a manual option declaration with
another installation-specific call and ordering requirement; it would not
meaningfully reduce client CMake. Moving `cpp_library_setup()` before
dependencies might avoid the specific ordering problem in some projects, but
requires clients to change their setup order and has not been established as a
general replacement. Changing shared-option defaults or overriding cached
values would risk existing builds and explicit choices.

Leave #37 open as a known limitation. Revisit it if a client reports a
concrete problem, or if a design can remove the ordering hazard without
adding installation-specific client boilerplate or breaking existing choices.
Any proposed change should cover shared options, independent
`INSTALL_OPTION` values, explicit cache overrides, and both standalone and
nested builds.

## History and compatibility

Installation support was restored in commit `3ab13f2`. Commit `fba98d9`
introduced dependency-provider tracking to generate dependency information
for installed CMake configurations. Commit `0e6c594` and
[#22](https://github.com/stlab/cpp-library/pull/22) introduced namespace
installation control so embedded projects can opt in, including for package
manager workflows.

[#27](https://github.com/stlab/cpp-library/pull/27) added independent options,
target-scoped deferred installation metadata, and transitive linkage for
separately installed nested packages. Its stated motivation includes the
standalone extraction of `stlab-execution` and its use by STLab. Preserve these
capabilities unless a separate change reviews their users, history, and
compatibility consequences. This recommendation removes no install feature.
