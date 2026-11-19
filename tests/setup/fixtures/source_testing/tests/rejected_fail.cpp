#include <cpp-library/testing.hpp>
#include <fixture/api.hpp>
#include "private/component.hpp"

int main() {
#if CPP_LIBRARY_TESTING()
    return public_value("not an argument");
#else
    return 0;
#endif
}
