#pragma once
#include <stlab/leaf-config.hpp>

#if defined(_WIN32) && LEAF_SHARED && !defined(LEAF_BUILD)
#define LEAF_API __declspec(dllimport)
#else
#define LEAF_API
#endif

extern "C" LEAF_API int stlab_fixture_leaf_v1();

namespace stlab {
inline int leaf() { return stlab_fixture_leaf_v1(); }
}
