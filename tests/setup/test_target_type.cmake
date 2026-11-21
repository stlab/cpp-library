# SPDX-License-Identifier: BSL-1.0
#
# Run as: cmake -P tests/setup/test_target_type.cmake

cmake_minimum_required(VERSION 3.24)

get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/target-type-${test_id}")
set(failed_cases)

# Configures a private fixture copy and checks the consumer-selected target type.
function(run_case name shared expected_type)
    set(case_source "${test_root}/${name}/source")
    set(case_binary "${test_root}/${name}/build")
    file(MAKE_DIRECTORY "${case_source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/target_type/"
        DESTINATION "${case_source}")
    if(name MATCHES "^threads_nested")
        file(WRITE "${test_root}/${name}/CMakeLists.txt"
            "cmake_minimum_required(VERSION 3.24)\ninclude(\"\${TOOLKIT_SOURCE}/cpp-library.cmake\")\ncpp_library_enable_dependency_tracking()\nproject(parent LANGUAGES CXX)\nenable_testing()\nadd_subdirectory(source)\n")
        set(case_source "${test_root}/${name}")
    endif()

    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${case_source}" -B "${case_binary}" -G Ninja
            "-DTOOLKIT_SOURCE=${toolkit_source}"
            "-DBUILD_SHARED_LIBS=${shared}"
            "-DEXPECTED_BUILD_SHARED_LIBS=${shared}"
            "-DEXPECTED_TYPE=${expected_type}"
            -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
            ${ARGN}
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(name STREQUAL "threads_missing_value")
        if(NOT result EQUAL 0 AND "${out}${err}" MATCHES "ENABLE_THREADS requires a value")
            set(result 0)
            set(err "")
        else()
            set(result 1)
            set(err "Expected a missing ENABLE_THREADS value diagnostic:\n${out}\n${err}")
        endif()
    elseif(result EQUAL 0 AND name MATCHES "^(dialect_|threads_)")
        execute_process(COMMAND "${CMAKE_COMMAND}" --build "${case_binary}"
            RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
        if(result EQUAL 0)
            execute_process(COMMAND "${CMAKE_CTEST_COMMAND}" --test-dir "${case_binary}" --output-on-failure
                RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
        endif()
        if(result EQUAL 0 AND name STREQUAL "dialect_default")
            file(READ "${case_binary}/compiler-id.txt" compiler_id)
            if(compiler_id MATCHES "^(GNU|Clang|AppleClang)$")
                file(READ "${case_binary}/compile_commands.json" commands)
                string(JSON command_count LENGTH "${commands}")
                math(EXPR last_command "${command_count} - 1")
                set(checked_sources)
                foreach(index RANGE ${last_command})
                    string(JSON file GET "${commands}" ${index} file)
                    if(file MATCHES "/(sample|sample_in_source_tests|dialect_test|compile_fail|dialect_example)\\.cpp$")
                        string(JSON command GET "${commands}" ${index} command)
                        if(NOT command MATCHES "-std=c\\+\\+20")
                            set(result 1)
                            set(err "Expected standard C++20 compile flag for ${file}: ${command}")
                        endif()
                        list(APPEND checked_sources "${file}")
                    endif()
                endforeach()
                list(REMOVE_DUPLICATES checked_sources)
                list(LENGTH checked_sources checked_commands)
                if(NOT checked_commands EQUAL 5)
                    set(result 1)
                    set(err "Expected five toolkit source files, got ${checked_commands}")
                endif()
            endif()
        endif()
    endif()
    if(NOT result EQUAL 0)
        message(STATUS "FAIL ${name}: Target type case failed:\n${out}\n${err}")
        list(APPEND failed_cases "${name}")
    else()
        if(err)
            message(STATUS "${name} configure diagnostics:\n${err}")
        endif()
        message(STATUS "PASS ${name}: ${expected_type}; BUILD_SHARED_LIBS=${shared}")
    endif()
    set(failed_cases "${failed_cases}" PARENT_SCOPE)
endfunction()

run_case(default_static OFF STATIC_LIBRARY)
run_case(default_shared ON SHARED_LIBRARY)
run_case(header_only_static_default OFF INTERFACE_LIBRARY -DOMIT_SOURCES=ON)
run_case(header_only_shared_default ON INTERFACE_LIBRARY -DOMIT_SOURCES=ON)
run_case(standard_default OFF STATIC_LIBRARY -DEXPECTED_CPP_VERSION=20)
run_case(standard_header_only OFF INTERFACE_LIBRARY -DOMIT_SOURCES=ON -DEXPECTED_CPP_VERSION=20)
run_case(standard_override OFF STATIC_LIBRARY -DFIXTURE_CPP_VERSION=17 -DEXPECTED_CPP_VERSION=17)
run_case(dialect_default OFF STATIC_LIBRARY -DCHECK_DIALECT=ON -DEXPECTED_EXTENSIONS=OFF)
run_case(dialect_header_only OFF INTERFACE_LIBRARY -DOMIT_SOURCES=ON
    -DCHECK_DIALECT=ON -DEXPECTED_EXTENSIONS=OFF)
run_case(dialect_on OFF STATIC_LIBRARY -DCHECK_DIALECT=ON
    -DCMAKE_CXX_EXTENSIONS=ON -DEXPECTED_EXTENSIONS=ON -DEXPECTED_CALLER_EXTENSIONS=ON)
run_case(dialect_off OFF STATIC_LIBRARY -DCHECK_DIALECT=ON
    -DCMAKE_CXX_EXTENSIONS=OFF -DEXPECTED_EXTENSIONS=OFF -DEXPECTED_CALLER_EXTENSIONS=OFF)
run_case(threads_default OFF STATIC_LIBRARY -DCHECK_THREADS=ON -DEXPECT_THREADS=ON)
run_case(threads_shared ON SHARED_LIBRARY -DCHECK_THREADS=ON -DEXPECT_THREADS=ON
    -DFIXTURE_ENABLE_THREADS=ON -DFORCE_PTHREAD_FLAG=ON)
run_case(threads_interface OFF INTERFACE_LIBRARY -DOMIT_SOURCES=ON
    -DCHECK_THREADS=ON -DEXPECT_THREADS=ON)
run_case(threads_disabled OFF STATIC_LIBRARY -DCHECK_THREADS=ON
    -DEXPECT_THREADS=OFF -DFIXTURE_ENABLE_THREADS=OFF)
run_case(threads_interface_disabled OFF INTERFACE_LIBRARY -DOMIT_SOURCES=ON
    -DCHECK_THREADS=ON -DEXPECT_THREADS=OFF -DFIXTURE_ENABLE_THREADS=OFF)
run_case(threads_without_tests OFF STATIC_LIBRARY -DCHECK_THREADS=ON
    -DEXPECT_THREADS=ON -DBUILD_TESTING=OFF)
run_case(threads_nested OFF STATIC_LIBRARY -DCHECK_THREADS=ON -DEXPECT_THREADS=ON)
run_case(threads_nested_disabled OFF STATIC_LIBRARY -DCHECK_THREADS=ON
    -DEXPECT_THREADS=OFF -DFIXTURE_ENABLE_THREADS=OFF)
run_case(threads_missing_value OFF STATIC_LIBRARY -DCHECK_THREADS=ON
    -DEXPECT_THREADS=OFF -DMISSING_THREADS_VALUE=ON)

file(REMOVE_RECURSE "${test_root}")
if(failed_cases)
    message(FATAL_ERROR "Target type cases failed: ${failed_cases}")
endif()
message(STATUS "All target type cases passed!")
