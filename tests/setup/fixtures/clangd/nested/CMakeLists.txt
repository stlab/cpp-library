project(nested LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
set(NESTED_INSTALL OFF CACHE BOOL "" FORCE)
cpp_library_setup(DESCRIPTION "Nested header-only fixture" NAMESPACE nested
    HEADERS api.hpp REQUIRES_CPP_VERSION 20)
target_compile_definitions(nested INTERFACE NESTED_CONTEXT=29)
