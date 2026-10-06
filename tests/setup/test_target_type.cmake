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

    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${case_source}" -B "${case_binary}" -G Ninja
            "-DTOOLKIT_SOURCE=${toolkit_source}"
            "-DBUILD_SHARED_LIBS=${shared}"
            "-DEXPECTED_BUILD_SHARED_LIBS=${shared}"
            "-DEXPECTED_TYPE=${expected_type}"
            ${ARGN}
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
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

file(REMOVE_RECURSE "${test_root}")
if(failed_cases)
    message(FATAL_ERROR "Target type cases failed: ${failed_cases}")
endif()
message(STATUS "All target type cases passed!")
