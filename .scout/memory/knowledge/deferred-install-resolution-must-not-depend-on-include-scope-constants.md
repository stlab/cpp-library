---
title: "Deferred install resolution must not depend on include-scope constants"
entity_type: discovery
confidence: 1.00
created: 2026-11-21T22:01:14Z
last_accessed: 2026-11-21T22:01:14Z
last_reinforced: 2026-11-21T22:01:14Z
access_count: 1
sources:
  - "cmake/cpp-library-install.cmake:130-131"
  - "cmake/cpp-library-install.cmake:164-172"
tags: ["cmake", "deferred-install", "function-scope", "system-packages", "threads"]
tier: knowledge
---

# Deferred install resolution must not depend on include-scope constants

Keep the system-package allowlist local to _cpp_library_resolve_dependency, which initializes _CPP_LIBRARY_SYSTEM_PACKAGES on every invocation (cmake/cpp-library-install.cmake:130-131) before its fallback membership check (cmake/cpp-library-install.cmake:164-172).

Root cause: the install module can be included while cpp_library_setup or its consumer wrapper is executing in a function scope. Deferred installation finalization runs after that scope has ended. A list initialized only at module include time is then unavailable to the resolver, so an otherwise supported system target such as Threads::Threads can be misclassified as an untracked dependency. Initializing this fixed list inside its sole consumer avoids that lifetime dependency.

For mutable install metadata needed by deferred work, preserve the repository's existing target/global properties or explicitly captured deferred arguments rather than relying on include-time local variables. The function-scoped packaging case in the existing package-CI regression was the validation boundary that exposed this coupling.
