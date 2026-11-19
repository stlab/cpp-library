#include <stlab/leaf.hpp>
#include <stlab/parent.hpp>

int main() { return stlab::parent() + stlab::leaf() == 42 ? 0 : 1; }
