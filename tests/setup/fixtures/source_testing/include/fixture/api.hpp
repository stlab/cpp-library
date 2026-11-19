#pragma once

#if defined(_WIN32)
#if defined(sample_EXPORTS)
#define FIXTURE_API __declspec(dllexport)
#else
#define FIXTURE_API
#endif
#else
#define FIXTURE_API __attribute__((visibility("default")))
#endif

/// Returns the configured public value.
#if defined(FIXTURE_HEADER_ONLY)
inline int public_value() { return 42; }
#else
FIXTURE_API int public_value();
#endif
