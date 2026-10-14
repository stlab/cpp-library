#ifndef FIXTURE_NAVIGATION_HPP
#define FIXTURE_NAVIGATION_HPP
#include <fixture/config.hpp>
#include <dependency.hpp>
#if GENERATED_CONTEXT != 73 || DEPENDENCY_CONTEXT != 19 || LATE_CONTEXT != 61
#error Wrong consumer context
#endif
namespace fixture {
class navigation {
public:
    int answer() const { return GENERATED_CONTEXT; }
};
inline int use_navigation(const navigation& instance) {
    return instance.answer();
}
}
#endif
