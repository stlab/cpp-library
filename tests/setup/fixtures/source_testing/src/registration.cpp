#include <cpp-library/testing.hpp>

#if CPP_LIBRARY_TESTING()
#include <doctest/doctest.h>
#include <fstream>

#if defined(_MSVC_LANG)
#define FIXTURE_CPLUSPLUS _MSVC_LANG
#else
#define FIXTURE_CPLUSPLUS __cplusplus
#endif

#if REQUIRED_STANDARD == 17
static_assert(FIXTURE_CPLUSPLUS >= 201703L);
#elif REQUIRED_STANDARD == 20
static_assert(FIXTURE_CPLUSPLUS >= 202002L);
#elif REQUIRED_STANDARD == 23
static_assert(FIXTURE_CPLUSPLUS > 202002L);
#endif

namespace {
/// Returns the configured internal value.
int internal_value() {
    return 42;
}

TEST_CASE("anonymous component") {
    CHECK(internal_value() == EXPECTED_INTERNAL);
    std::ofstream marker("in-source-executions", std::ios::app);
    marker << "anonymous\n";
    CHECK(marker.good());
}
}
#endif
