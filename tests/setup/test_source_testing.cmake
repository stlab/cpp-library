# SPDX-License-Identifier: BSL-1.0
# Run as: cmake -P tests/setup/test_source_testing.cmake
cmake_minimum_required(VERSION 3.24)
get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/source-testing-${test_id}")
find_program(ctest NAMES ctest REQUIRED)

function(run)
    execute_process(COMMAND ${ARGV} RESULT_VARIABLE result
        OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Command failed (${result}): ${ARGV}\n${out}\n${err}")
    endif()
endfunction()

foreach(shared OFF ON)
    set(build "${test_root}/${shared}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/source_testing/"
        DESTINATION "${build}/source")
    run("${CMAKE_COMMAND}" -S "${build}/source" -B "${build}/build" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" "-DBUILD_SHARED_LIBS=${shared}"
        "-DFETCHCONTENT_BASE_DIR=${test_root}/dependencies")
    run("${CMAKE_COMMAND}" --build "${build}/build")
    run("${ctest}" --test-dir "${build}/build" --output-on-failure)
endforeach()
foreach(mode disabled header-only nested)
    set(build "${test_root}/${mode}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/source_testing/"
        DESTINATION "${build}/source/library")
    set(options -DBUILD_SHARED_LIBS=OFF)
    set(source "${build}/source/library")
    if(mode STREQUAL "disabled")
        list(APPEND options -DBUILD_TESTING=OFF)
    elseif(mode STREQUAL "header-only")
        list(APPEND options -DHEADER_ONLY=ON)
    else()
        file(WRITE "${build}/source/CMakeLists.txt"
            "cmake_minimum_required(VERSION 3.24)\nproject(consumer LANGUAGES CXX)\nadd_subdirectory(library)\n")
        set(source "${build}/source")
    endif()
    run("${CMAKE_COMMAND}" -S "${source}" -B "${build}/build" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" ${options}
        "-DFETCHCONTENT_BASE_DIR=${test_root}/dependencies")
    run("${CMAKE_COMMAND}" --build "${build}/build")
    if(mode STREQUAL "header-only")
        run("${ctest}" --test-dir "${build}/build" --output-on-failure)
    endif()
endforeach()
file(REMOVE_RECURSE "${test_root}")
message(STATUS "PASS source testing: static unit tests with static/shared production")
