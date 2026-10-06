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
    ${install_args})
get_target_property(leaf_type leaf TYPE)
set(LEAF_SHARED 0)
if(leaf_type STREQUAL "SHARED_LIBRARY")
    set(LEAF_SHARED 1)
    if(WIN32)
        target_sources(leaf PRIVATE src/leaf.def)
    endif()
endif()
configure_file(include/stlab/leaf-config.hpp.in
    "${CMAKE_CURRENT_BINARY_DIR}/include/stlab/leaf-config.hpp" @ONLY)
target_sources(leaf PUBLIC
    FILE_SET headers TYPE HEADERS
    BASE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/include"
    FILES "${CMAKE_CURRENT_BINARY_DIR}/include/stlab/leaf-config.hpp")
target_include_directories(leaf PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>")
target_compile_definitions(leaf PRIVATE LEAF_BUILD)
if(INVALID_PACKAGE STREQUAL "leaf")
    add_library(UnknownLeaf::dep INTERFACE IMPORTED)
    target_link_libraries(leaf INTERFACE $<BUILD_INTERFACE:UnknownLeaf::dep>)
endif()
