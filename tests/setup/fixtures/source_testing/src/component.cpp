#include <cpp-library/testing.hpp>
#include <fixture/api.hpp>
#include "private/component.hpp"
#include <config.hpp>

#if CPP_LIBRARY_TESTING()
#include <doctest/doctest.h>
#endif

int public_value() {
    return GENERATED_VALUE;
}

int private_value() {
    return PRIVATE_VALUE + PUBLIC_VALUE;
}
