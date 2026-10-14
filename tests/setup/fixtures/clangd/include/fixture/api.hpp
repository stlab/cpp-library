#ifndef FIXTURE_API_HPP
#define FIXTURE_API_HPP
#if PUBLIC_CONTEXT != 42
#error Missing consumer definition
#endif
#ifdef PRODUCER_PRIVATE
#error Producer definition leaked to consumer
#endif
#ifdef LATE_CONTEXT
#include <fixture/config.hpp>
#include <dependency.hpp>
#if LATE_CONTEXT != 61 || GENERATED_CONTEXT != 73 || DEPENDENCY_CONTEXT != 19
#error Incorrect generated or transitive consumer context
#endif
#if defined(OWNER_EXPORT) || defined(owner_EXPORTS)
#error DLL export definition leaked to consumer
#endif
#endif
namespace fixture {
struct widget {
    int value() const { return 42; }
};
}
#endif
