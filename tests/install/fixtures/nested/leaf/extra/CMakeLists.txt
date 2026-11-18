cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
project(extra LANGUAGES CXX)
set(CPP_LIBRARY_VERSION_extra 1.0.0)
cpp_library_setup(
    DESCRIPTION "Transitive packaging dependency fixture"
    NAMESPACE stlab
    HEADERS extra.hpp
    INSTALL_OPTION STLAB_LEAF_INSTALL)
