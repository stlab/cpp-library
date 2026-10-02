include("${TOOLKIT_SOURCE}/cpp-library.cmake")
project(leaf LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
set(install_args INSTALL_OPTION STLAB_LEAF_INSTALL)
if(LEGACY_OPTIONS)
    set(install_args)
endif()
cpp_library_setup(
    DESCRIPTION "Leaf package fixture"
    NAMESPACE stlab
    HEADERS leaf.hpp
    SOURCES leaf.cpp
    LIBRARY_TYPE STATIC
    ${install_args})
if(INVALID_PACKAGE STREQUAL "leaf")
    add_library(UnknownLeaf::dep INTERFACE IMPORTED)
    target_link_libraries(leaf INTERFACE $<BUILD_INTERFACE:UnknownLeaf::dep>)
endif()
