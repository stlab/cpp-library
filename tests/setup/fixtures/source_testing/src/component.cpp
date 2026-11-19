#include <cpp-library/testing.hpp>
#include <fixture/api.hpp>
#include "private/component.hpp"
#include <config.hpp>

#if CPP_LIBRARY_TESTING()
#include <doctest/doctest.h>
#include <fstream>

TEST_CASE("compiled component") {
    CHECK(private_value() == 42);
    std::ofstream marker("in-source-executions", std::ios::app);
    marker << "component\n";
    CHECK(marker.good());
}
#endif

int public_value() {
    return GENERATED_VALUE;
}

int private_value() {
    return PRIVATE_VALUE + PUBLIC_VALUE;
}
