# SPDX-License-Identifier: BSL-1.0
#
# Run as: cmake -P tests/setup/test_install_dirs.cmake
cmake_minimum_required(VERSION 3.24)

get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/install-dirs-${test_id}")

function(run_command)
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Command failed (${result}): ${ARGN}\n${out}\n${err}")
    endif()
endfunction()

function(run_case name expected_data enabled)
    set(source "${test_root}/${name}/source")
    set(binary "${test_root}/${name}/build")
    set(prefix "${test_root}/${name}/prefix")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/target_type/" DESTINATION "${source}")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" -DOMIT_SOURCES=ON
        -DEXPECTED_TYPE=INTERFACE_LIBRARY -DBUILD_SHARED_LIBS=OFF
        -DEXPECTED_BUILD_SHARED_LIBS=OFF -DCHECK_INSTALL_DIRS=ON
        "-DFIXTURE_INSTALL=${enabled}" "-DEXPECTED_DATADIR=${expected_data}"
        "-DCMAKE_INSTALL_PREFIX=${prefix}" ${ARGN})
    if(enabled)
        run_command("${CMAKE_COMMAND}" --install "${binary}")
        if(NOT EXISTS "${prefix}/${expected_data}/licenses/fixture-sample/sample.hpp")
            message(FATAL_ERROR "${name}: license install destination missing")
        endif()
        set(next_prefix "${test_root}/${name}/next-prefix")
        run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}"
            "-DCMAKE_INSTALL_PREFIX=${next_prefix}")
    else()
        file(READ "${binary}/cmake_install.cmake" install_script)
        if(install_script MATCHES "fixture-sample")
            message(FATAL_ERROR "${name}: installation disabled but rules were generated")
        endif()
    endif()
    message(STATUS "PASS ${name}")
endfunction()

run_case(default share ON)
run_case(datadir custom-data ON -DCMAKE_INSTALL_DATADIR=custom-data)
run_case(normal_datadir normal-data ON -DFIXTURE_NORMAL_DATADIR=normal-data)
run_case(dataroot custom-root ON -DCMAKE_INSTALL_DATAROOTDIR=custom-root)
run_case(disabled share OFF)

set(source "${test_root}/subproject/source")
set(binary "${test_root}/subproject/build")
file(MAKE_DIRECTORY "${source}/component")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/target_type/" DESTINATION "${source}/component")
file(WRITE "${source}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.24)\nproject(wrapper LANGUAGES CXX)\nadd_subdirectory(component)\n")
run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
    "-DTOOLKIT_SOURCE=${toolkit_source}" -DOMIT_SOURCES=ON
    -DEXPECTED_TYPE=INTERFACE_LIBRARY -DBUILD_SHARED_LIBS=OFF
    -DEXPECTED_BUILD_SHARED_LIBS=OFF -DCHECK_INSTALL_DIRS=ON
    -DFIXTURE_INSTALL=OFF -DEXPECTED_DATADIR=share
    "-DCMAKE_INSTALL_PREFIX=${test_root}/subproject/prefix")
message(STATUS "PASS subproject")

file(REMOVE_RECURSE "${test_root}")
message(STATUS "All install directory cases passed!")
