#include <cpp-library/testing.hpp>
#include <fixture/api.hpp>
#include "private/component.hpp"

#if defined(FIXTURE_USING_DLL)
#error "Unit tests must not import the production DLL"
#endif

#if CPP_LIBRARY_TESTING()
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>
#endif

TEST_CASE("public and private implementation") {
    CHECK(public_value() == 42);
    CHECK(private_value() == 42);
#if !defined(FIXTURE_HEADER_ONLY)
    CHECK(configured_private_value() == 84);
#endif
}
