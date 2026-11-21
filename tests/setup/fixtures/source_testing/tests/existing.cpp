#include <fixture/api.hpp>

#if __has_include(<cpp-library/testing.hpp>) || __has_include("private/component.hpp")
#error "Public tests must not receive private include directories"
#endif

#if defined(PRIVATE_VALUE) || defined(REQUIRED_STANDARD)
#error "Public tests must not receive implementation-only definitions"
#endif

#if defined(EXPECT_SHARED) && !defined(FIXTURE_USING_DLL)
#error "Public tests must consume production DLL usage requirements"
#endif

#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

TEST_CASE("production public API") {
    CHECK(public_value() == 42);
}
