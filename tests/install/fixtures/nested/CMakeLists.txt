cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
cpp_library_enable_dependency_tracking()
project(parent LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
set(CMAKE_INSTALL_LIBDIR lib)
if(LEGACY_OFF)
    set(STLAB_INSTALL OFF CACHE BOOL "Legacy namespace installation")
endif()

set(install_args INSTALL_OPTION STLAB_PARENT_INSTALL)
if(LEGACY_OPTIONS)
    set(install_args)
elseif(MISSING_INSTALL_OPTION)
    set(install_args INSTALL_OPTION)
endif()
cpp_library_setup(
    DESCRIPTION "Parent package fixture"
    NAMESPACE stlab
    HEADERS parent.hpp
    ${install_args})
add_subdirectory(leaf)
# Resolve the installed target downstream, even when leaf is not exported in this build.
target_link_libraries(parent INTERFACE
    $<BUILD_INTERFACE:stlab::leaf>
    $<INSTALL_INTERFACE:$<1:stlab::leaf>>)
cpp_library_map_dependency("stlab::leaf" "stlab-leaf 1.0.0")
if(INVALID_PACKAGE STREQUAL "parent")
    add_library(UnknownParent::dep INTERFACE IMPORTED)
    target_link_libraries(parent INTERFACE $<BUILD_INTERFACE:UnknownParent::dep>)
endif()
