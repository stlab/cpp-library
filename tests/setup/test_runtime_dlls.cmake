# SPDX-License-Identifier: BSL-1.0
# Run as: cmake -P tests/setup/test_runtime_dlls.cmake
cmake_minimum_required(VERSION 3.24)
get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/runtime-dlls-${test_id}")
find_program(ctest NAMES ctest REQUIRED)

function(run)
    execute_process(COMMAND ${ARGV} RESULT_VARIABLE result
        OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Command failed (${result}): ${ARGV}\n${out}\n${err}")
    endif()
endfunction()

run("${CMAKE_COMMAND}" -S "${CMAKE_CURRENT_LIST_DIR}/fixtures/runtime_dlls"
    -B "${test_root}" -G Ninja "-DTOOLKIT_SOURCE=${toolkit_source}")
run("${CMAKE_COMMAND}" --build "${test_root}")
if(WIN32)
    include("${test_root}/runtime-dlls.cmake")
    if(NOT runtime_dlls)
        message(FATAL_ERROR "Shared runtime fixture did not produce a DLL")
    endif()
    foreach(dll IN LISTS runtime_dlls)
        get_filename_component(filename "${dll}" NAME)
        if(NOT EXISTS "${test_root}/client apps/${filename}")
            message(FATAL_ERROR "Runtime DLL was not deployed: ${filename}")
        endif()
    endforeach()
endif()
run("${ctest}" --test-dir "${test_root}" --output-on-failure)
file(REMOVE_RECURSE "${test_root}")
message(STATUS "PASS custom shared and static executable runtime deployment")
