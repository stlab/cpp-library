#pragma once

/// Returns the configured private value.
#if defined(FIXTURE_HEADER_ONLY)
inline int private_value() { return 42; }
#else
int private_value();
#endif
