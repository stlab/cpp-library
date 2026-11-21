#include <fixture/api.hpp>

#if __has_include(<cpp-library/testing.hpp>) || __has_include("private/component.hpp")
#error "Public compile-fail tests must not receive private include directories"
#endif

#if defined(PRIVATE_VALUE) || defined(REQUIRED_STANDARD)
#error "Public compile-fail tests must not receive implementation-only definitions"
#endif

int main() {
    return public_value("not an argument");
}
