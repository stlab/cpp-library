cmake_minimum_required(VERSION 3.24)
project(clangd_fixture LANGUAGES CXX)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")

if(WORKSPACE)
    set(CPP_LIBRARY_VERSION 1.0.0)
    set(FIXTURE_INSTALL OFF CACHE BOOL "" FORCE)
    cpp_library_setup(DESCRIPTION "Workspace settings fixture" NAMESPACE fixture
        HEADERS api.hpp REQUIRES_CPP_VERSION 20)
    target_compile_definitions(clangd_fixture INTERFACE PUBLIC_CONTEXT=42
        "$<IF:$<CONFIG:Debug>,PRESET_CONTEXT=2,PRESET_CONTEXT=1>")
    return()
endif()

if(HEADER_ONLY)
    add_library(owner INTERFACE)
    set(usage INTERFACE)
else()
    add_library(owner owner.cpp)
    set_target_properties(owner PROPERTIES UNITY_BUILD OFF)
    set(usage PUBLIC)
    target_compile_definitions(owner PRIVATE PRODUCER_PRIVATE=1)
endif()
target_sources(owner ${usage} FILE_SET headers TYPE HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include"
    FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/api.hpp")
target_include_directories(owner ${usage}
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
    "$<INSTALL_INTERFACE:include>")
target_compile_definitions(owner ${usage} PUBLIC_CONTEXT=42)
target_compile_features(owner ${usage} cxx_std_20)

get_source_file_property(before "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/api.hpp" HEADER_FILE_ONLY)
get_source_file_property(language_before "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/api.hpp" LANGUAGE)
get_target_property(headers owner HEADER_SET_headers)
if(PROOF)
    add_subdirectory(index EXCLUDE_FROM_ALL)
    set(index_target fixture_index)
else()
    add_library(fixture::owner ALIAS owner)
    cpp_library_add_clangd_headers(TARGET fixture::owner
        HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/api.hpp")
    cpp_library_add_clangd_headers(TARGET owner
        HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/api.hpp")
    file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/generated/fixture")
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/generated/fixture/config.hpp"
        "#define GENERATED_CONTEXT 73\n")
    set(generated "${CMAKE_CURRENT_BINARY_DIR}/generated/fixture/config.hpp")
    set_source_files_properties("${generated}" PROPERTIES GENERATED TRUE)
    cpp_library_add_clangd_headers(TARGET owner HEADERS "${generated}"
        "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/extra.hpp")
    set(build_generated "${CMAKE_CURRENT_BINARY_DIR}/generated/fixture/build_generated.hpp")
    add_custom_command(OUTPUT "${build_generated}"
        COMMAND "${CMAKE_COMMAND}" -E copy "${generated}" "${build_generated}"
        DEPENDS "${generated}")
    add_custom_target(generate_build_header DEPENDS "${build_generated}")
    cpp_library_add_clangd_headers(TARGET owner HEADERS "${build_generated}")
    add_library(public_dependency INTERFACE)
    target_include_directories(public_dependency INTERFACE
        "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/dependency_include>")
    target_compile_definitions(public_dependency INTERFACE DEPENDENCY_CONTEXT=19)
    target_link_libraries(owner ${usage} public_dependency)
    target_include_directories(owner ${usage}
        "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/generated>")
    target_compile_definitions(owner ${usage} LATE_CONTEXT=61
        "$<$<CONFIG:Debug>:DEBUG_CONTEXT=1>"
        "$<$<CONFIG:Release>:RELEASE_CONTEXT=1>")
    if(BUILD_SHARED_LIBS AND NOT HEADER_ONLY)
        target_compile_definitions(owner PRIVATE OWNER_EXPORT=1)
        target_compile_definitions(owner INTERFACE OWNER_IMPORT=1)
    endif()
    add_subdirectory(nested)
    if(ERROR_CASE STREQUAL conflict)
        add_library(other INTERFACE)
        cpp_library_add_clangd_headers(TARGET other
            HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/api.hpp")
    elseif(ERROR_CASE STREQUAL missing)
        cpp_library_add_clangd_headers(TARGET absent HEADERS "${generated}")
    elseif(ERROR_CASE STREQUAL imported)
        add_library(imported INTERFACE IMPORTED)
        cpp_library_add_clangd_headers(TARGET imported HEADERS "${generated}")
    elseif(ERROR_CASE STREQUAL executable)
        add_executable(executable owner.cpp)
        cpp_library_add_clangd_headers(TARGET executable HEADERS "${generated}")
    elseif(ERROR_CASE STREQUAL relative)
        cpp_library_add_clangd_headers(TARGET owner HEADERS include/fixture/api.hpp)
    endif()
    get_property(index_target TARGET owner PROPERTY _CPP_LIBRARY_CLANGD_TARGET)
    install(TARGETS owner public_dependency EXPORT fixtureTargets
        FILE_SET headers DESTINATION include)
    install(EXPORT fixtureTargets DESTINATION lib/cmake/fixture)
endif()
get_source_file_property(after "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/api.hpp" HEADER_FILE_ONLY)
get_source_file_property(language_after "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/api.hpp" LANGUAGE)
get_target_property(headers_after owner HEADER_SET_headers)
if(NOT before STREQUAL after OR NOT language_before STREQUAL language_after OR
    NOT headers STREQUAL headers_after)
    message(FATAL_ERROR "Indexing changed production source properties")
endif()
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/properties.txt" "${headers}\n")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/index-target.txt" "${index_target}")
