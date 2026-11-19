#pragma once

/// Returns the configured private value.
#if defined(FIXTURE_HEADER_ONLY)
inline int private_value() { return 42; }
#else
int private_value();
#include <config.hpp>

/// Returns the value derived from private build requirements.
inline int configured_private_value() {
    return GENERATED_VALUE + PRIVATE_VALUE + PUBLIC_VALUE;
}
#endif
