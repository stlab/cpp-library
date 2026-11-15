cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
cpp_library_enable_dependency_tracking()
project(single LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
cpp_library_setup(
    DESCRIPTION "Dependency-free packaging fixture"
    NAMESPACE stlab
    HEADERS single.hpp)
if(EXTERNAL_PACKAGE)
    find_package(stlab-extra 1.0.0 CONFIG REQUIRED)
    target_link_libraries(single INTERFACE stlab::extra)
endif()
