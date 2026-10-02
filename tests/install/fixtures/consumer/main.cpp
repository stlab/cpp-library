#include <stlab/parent.hpp>
#include <stlab/leaf.hpp>

int main() { return stlab::parent() + stlab::leaf() == 42 ? 0 : 1; }
