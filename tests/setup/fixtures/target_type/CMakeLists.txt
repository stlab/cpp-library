cmake_minimum_required(VERSION 3.24)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
cpp_library_enable_dependency_tracking()
project(sample LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
if(DEFINED FIXTURE_NORMAL_DATADIR)
    set(CMAKE_INSTALL_DATADIR "${FIXTURE_NORMAL_DATADIR}")
endif()
if(NOT CHECK_INSTALL_DIRS)
    set(FIXTURE_INSTALL OFF CACHE BOOL "" FORCE)
endif()
if(CHECK_DIALECT)
    include(CTest)
    include("${TOOLKIT_SOURCE}/tests/setup/fixtures/mock_doctest.cmake")
    add_library(unrelated INTERFACE)
    get_target_property(unrelated_extensions unrelated CXX_EXTENSIONS)
    set(unrelated_before "${unrelated_extensions}")
    set(test_args TESTS dialect_test.cpp compile_fail.cpp EXAMPLES dialect_example.cpp)
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/compiler-id.txt" "${CMAKE_CXX_COMPILER_ID}")
endif()
set(source_args SOURCES sample.cpp)
if(OMIT_SOURCES)
    set(source_args)
endif()
if(DEFINED FIXTURE_CPP_VERSION)
    set(version_args REQUIRES_CPP_VERSION "${FIXTURE_CPP_VERSION}")
endif()
if(CHECK_THREADS)
    include(CTest)
    include("${TOOLKIT_SOURCE}/tests/setup/fixtures/mock_doctest.cmake")
    set(test_args TESTS thread_test.cpp EXAMPLES thread_example.cpp)
    if(DEFINED FIXTURE_ENABLE_THREADS)
        set(thread_args ENABLE_THREADS "${FIXTURE_ENABLE_THREADS}")
    elseif(MISSING_THREADS_VALUE)
        set(thread_args ENABLE_THREADS)
    endif()
    if(EXPECT_THREADS)
        if(FORCE_PTHREAD_FLAG AND UNIX AND CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
            set(CMAKE_HAVE_LIBC_PTHREAD FALSE)
        endif()
        file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/include/fixture/thread.hpp" [=[
#pragma once
#include <latch>
#include <thread>
inline int thread_value() {
    int result = 0;
    std::latch ready(1);
    std::jthread worker([&] { result = 42; ready.count_down(); });
    ready.wait();
    worker.join();
    return result;
}
]=])
        file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/sample.cpp" [=[
#include <fixture/thread.hpp>
#include <cpp-library/testing.hpp>
namespace fixture { int sample() { return thread_value(); } }
#if CPP_LIBRARY_TESTING()
const int embedded_thread_result = thread_value();
#endif
]=])
        set(thread_main [=[
#include <fixture/thread.hpp>
#include <fixture/sample.hpp>
int main() {
    if (thread_value() != 42) return 1;
#ifndef HEADER_ONLY
    if (fixture::sample() != 42) return 2;
#endif
    return 0;
}
]=])
        file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/tests/thread_test.cpp" "${thread_main}")
        file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/examples/thread_example.cpp" "${thread_main}")
        if(OMIT_SOURCES)
            add_compile_definitions(HEADER_ONLY)
        endif()
    else()
        set(CMAKE_DISABLE_FIND_PACKAGE_Threads TRUE)
        file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/tests/thread_test.cpp" "int main() { return 0; }\n")
        file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/examples/thread_example.cpp" "int main() { return 0; }\n")
    endif()
endif()
cpp_library_setup(
    DESCRIPTION "Consumer-selected target type fixture"
    NAMESPACE fixture
    HEADERS sample.hpp
    ${version_args}
    ${thread_args}
    ${test_args}
    ${source_args})
if(CHECK_THREADS)
    if(BUILD_SHARED_LIBS AND NOT OMIT_SOURCES)
        set_target_properties(sample PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
    endif()
    get_target_property(links sample INTERFACE_LINK_LIBRARIES)
    _cpp_library_generate_dependencies(dependencies sample fixture)
    if(EXPECT_THREADS)
        if(NOT "Threads::Threads" IN_LIST links OR NOT dependencies MATCHES "find_dependency\\(Threads\\)")
            message(FATAL_ERROR "Missing transitive thread dependency: ${links}; ${dependencies}")
        endif()
        if(FORCE_PTHREAD_FLAG AND UNIX AND CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
            get_target_property(options Threads::Threads INTERFACE_COMPILE_OPTIONS)
            if(NOT options MATCHES "-pthread")
                message(FATAL_ERROR "Explicit pthread flag case did not supply compile flags: ${options}")
            endif()
        endif()
    elseif(TARGET Threads::Threads OR "Threads::Threads" IN_LIST links OR dependencies MATCHES "Threads")
        message(FATAL_ERROR "Disabled threading still configured thread support")
    endif()
    if(NOT PROJECT_IS_TOP_LEVEL OR NOT BUILD_TESTING)
        foreach(target thread_test thread_example sample_in_source_tests)
            if(TARGET "${target}")
                message(FATAL_ERROR "Unexpected development target ${target}")
            endif()
        endforeach()
    endif()
endif()
if(CHECK_INSTALL_DIRS)
    if(NOT CMAKE_INSTALL_DATADIR STREQUAL EXPECTED_DATADIR)
        message(FATAL_ERROR "Expected DATADIR ${EXPECTED_DATADIR}, got '${CMAKE_INSTALL_DATADIR}'")
    endif()
    if(NOT CMAKE_INSTALL_FULL_DATADIR STREQUAL "${CMAKE_INSTALL_PREFIX}/${EXPECTED_DATADIR}")
        message(FATAL_ERROR "Unexpected full DATADIR '${CMAKE_INSTALL_FULL_DATADIR}'")
    endif()
    if(NOT CMAKE_INSTALL_FULL_BINDIR STREQUAL "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}")
        message(FATAL_ERROR "Unexpected full BINDIR '${CMAKE_INSTALL_FULL_BINDIR}'")
    endif()
    if(FIXTURE_INSTALL)
        install(FILES include/fixture/sample.hpp
            DESTINATION "${CMAKE_INSTALL_DATADIR}/licenses/fixture-sample")
    endif()
endif()
get_target_property(actual sample TYPE)
if(NOT actual STREQUAL EXPECTED_TYPE)
    message(FATAL_ERROR "Expected ${EXPECTED_TYPE}, got ${actual}")
endif()
if(DEFINED EXPECTED_CPP_VERSION)
    get_target_property(features sample INTERFACE_COMPILE_FEATURES)
    if(NOT "cxx_std_${EXPECTED_CPP_VERSION}" IN_LIST features)
        message(FATAL_ERROR "Expected C++${EXPECTED_CPP_VERSION} requirement, got '${features}'")
    endif()
endif()
if(NOT BUILD_SHARED_LIBS STREQUAL EXPECTED_BUILD_SHARED_LIBS)
    message(FATAL_ERROR "Setup changed parent BUILD_SHARED_LIBS")
endif()
if(CHECK_DIALECT)
    set(checked_targets dialect_test compile_fail dialect_example)
    if(NOT OMIT_SOURCES)
        list(APPEND checked_targets sample)
    endif()
    foreach(target IN LISTS checked_targets)
        get_target_property(extensions ${target} CXX_EXTENSIONS)
        if(NOT "${extensions}" STREQUAL "${EXPECTED_EXTENSIONS}")
            message(FATAL_ERROR "${target} CXX_EXTENSIONS: expected ${EXPECTED_EXTENSIONS}, got ${extensions}")
        endif()
    endforeach()
    get_target_property(unrelated_extensions unrelated CXX_EXTENSIONS)
    if(NOT "${unrelated_before}" STREQUAL "${unrelated_extensions}")
        message(FATAL_ERROR "Setup changed unrelated target dialect")
    endif()
    if(NOT DEFINED EXPECTED_CALLER_EXTENSIONS AND DEFINED CMAKE_CXX_EXTENSIONS)
        message(FATAL_ERROR "Setup changed caller CMAKE_CXX_EXTENSIONS")
    elseif(DEFINED EXPECTED_CALLER_EXTENSIONS AND
           NOT "${CMAKE_CXX_EXTENSIONS}" STREQUAL "${EXPECTED_CALLER_EXTENSIONS}")
        message(FATAL_ERROR "Setup changed caller CMAKE_CXX_EXTENSIONS")
    endif()
endif()
