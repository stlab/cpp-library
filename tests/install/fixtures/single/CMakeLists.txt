cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
cpp_library_enable_dependency_tracking()
project(single LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
set(install_args)
if(CUSTOM_INSTALL_OPTION)
    list(APPEND install_args INSTALL_OPTION "${CUSTOM_INSTALL_OPTION}")
endif()
cpp_library_setup(
    DESCRIPTION "Dependency-free packaging fixture"
    NAMESPACE stlab
    HEADERS single.hpp
    ${install_args})
if(SOURCE_ONLY_DEPENDENCY)
    add_library(source_only_dependency INTERFACE)
    cpp_library_map_dependency(source_only_dependency "SourceOnlyDependency 1.0.0")
    target_link_libraries(single INTERFACE source_only_dependency)
endif()
if(EXTERNAL_PACKAGE)
    find_package(stlab-extra 1.0.0 CONFIG REQUIRED)
    target_link_libraries(single INTERFACE stlab::extra)
endif()
