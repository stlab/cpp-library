# SPDX-License-Identifier: BSL-1.0
#
# Run as: cmake -P tests/install/test_package_ci.cmake
cmake_minimum_required(VERSION 3.24)

get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/package-ci-${test_id}")

function(run_command)
    execute_process(COMMAND ${ARGN}
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Command failed (${result}): ${ARGN}\n${out}\n${err}")
    endif()
endfunction()

function(expect_check_failure check prefix missing_file)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" "-DPACKAGE_TEST_PREFIX=${prefix}" -P "${check}"
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(result EQUAL 0 OR NOT "${out}\n${err}" MATCHES "${missing_file}")
        message(FATAL_ERROR
            "Expected package check to report ${missing_file} as missing:\n${out}\n${err}")
    endif()
endfunction()

function(run_workflow_install workflow binary prefix)
    file(READ "${workflow}" workflow_text)
    string(REGEX MATCH "cmake --install build/default --prefix [^\n]*"
        install_command "${workflow_text}")
    if(NOT install_command)
        message(FATAL_ERROR "Generated workflow has no install command: ${workflow}")
    endif()
    string(REPLACE "build/default" "\"${binary}\"" install_command "${install_command}")
    string(REPLACE "\${{ runner.temp }}/install" "${prefix}" install_command "${install_command}")

    if(WIN32)
        find_program(shell NAMES pwsh powershell REQUIRED)
        execute_process(COMMAND "${shell}" -NoProfile -Command "${install_command}"
            RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    else()
        execute_process(COMMAND /bin/sh -c "${install_command}"
            RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    endif()
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Generated workflow install failed (${result}):\n${install_command}\n${out}\n${err}")
    endif()
endfunction()

function(run_single)
    set(root "${test_root}/single")
    set(source "${root}/source")
    set(binary "${root}/build")
    set(prefix "${root}/install prefix")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/single/" DESTINATION "${source}")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_LIBDIR=lib64)
    run_command("${CMAKE_COMMAND}" --build "${binary}")

    set(workflow "${source}/.github/workflows/ci.yml")
    if(NOT EXISTS "${workflow}")
        message(FATAL_ERROR "Missing generated CI workflow: ${workflow}")
    endif()
    set(check "${binary}/cpp-library-test-package.cmake")
    if(NOT EXISTS "${check}")
        message(FATAL_ERROR "Missing generated packaging check: ${check}")
    endif()

    expect_check_failure("${check}" "${prefix}" "Package install prefix does not exist")
    set(workflow_prefix "${root}/./install prefix")
    cmake_path(NATIVE_PATH workflow_prefix workflow_prefix)
    run_workflow_install("${workflow}" "${binary}" "${workflow_prefix}")
    run_command("${CMAKE_COMMAND}" "-DPACKAGE_TEST_PREFIX=${prefix}" -P "${check}")

    set(package_dir "lib64/cmake/stlab-single")
    foreach(artifact IN ITEMS
            stlab-singleConfig.cmake
            stlab-singleConfigVersion.cmake
            stlab-singleTargets.cmake)
        set(path "${prefix}/${package_dir}/${artifact}")
        file(RENAME "${path}" "${path}.backup")
        expect_check_failure("${check}" "${prefix}" "${artifact}")
        file(RENAME "${path}.backup" "${path}")
    endforeach()

    message(STATUS "PASS single: installed package artifacts are checked")
endfunction()

function(run_absolute_libdir)
    set(root "${test_root}/absolute libdir")
    set(source "${root}/source")
    set(binary "${root}/build")
    set(prefix "${root}/missing prefix")
    set(libdir "${root}/absolute install lib")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/single/" DESTINATION "${source}")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" "-DCMAKE_INSTALL_LIBDIR=${libdir}")

    set(check "${binary}/cpp-library-test-package.cmake")
    set(package_dir "${libdir}/cmake/stlab-single")
    file(MAKE_DIRECTORY "${package_dir}")
    foreach(artifact IN ITEMS
            stlab-singleConfig.cmake
            stlab-singleConfigVersion.cmake
            stlab-singleTargets.cmake)
        file(WRITE "${package_dir}/${artifact}" "stale artifact")
    endforeach()
    expect_check_failure("${check}" "${prefix}" "install_manifest.txt")
endfunction()

function(run_function_scope)
    set(root "${test_root}/function scope")
    set(source "${root}/source")
    set(binary "${root}/build")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/single/" DESTINATION "${source}")
    file(WRITE "${source}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.24)
project(single LANGUAGES CXX)
set(CPP_LIBRARY_VERSION 1.0.0)
function(setup_library)
    include("${TOOLKIT_SOURCE}/cpp-library.cmake")
    cpp_library_setup(DESCRIPTION "fixture" NAMESPACE stlab HEADERS single.hpp)
endfunction()
setup_library()
]=])
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}")
    message(STATUS "PASS function scope: package check is generated")
endfunction()

function(run_absolute_install stale)
    set(root "${test_root}/absolute install ${stale}")
    set(source "${root}/source")
    set(binary "${root}/build")
    set(prefix "${root}/prefix")
    set(libdir "${root}/absolute lib")
    set(includedir "${root}/absolute include")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/single/" DESTINATION "${source}")
    set(args)
    if(stale)
        list(APPEND args -DSTLAB_INSTALL=OFF)
        file(APPEND "${source}/CMakeLists.txt" [=[
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/unrelated.txt" "unrelated")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/unrelated.txt" DESTINATION ".")
]=])
        set(package_dir "${libdir}/cmake/stlab-single")
        file(MAKE_DIRECTORY "${package_dir}")
        foreach(artifact IN ITEMS stlab-singleConfig.cmake stlab-singleConfigVersion.cmake stlab-singleTargets.cmake)
            file(WRITE "${package_dir}/${artifact}" "stale")
        endforeach()
    endif()
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" "-DCMAKE_INSTALL_LIBDIR=${libdir}"
        "-DCMAKE_INSTALL_INCLUDEDIR=${includedir}" ${args})
    run_command("${CMAKE_COMMAND}" --install "${binary}" --prefix "${prefix}")
    set(check "${binary}/cpp-library-test-package.cmake")
    if(stale)
        expect_check_failure("${check}" "${prefix}" "stlab-singleConfig.cmake")
        message(STATUS "PASS absolute install: stale artifacts rejected")
    else()
        if(EXISTS "${prefix}")
            message(FATAL_ERROR "Absolute installation unexpectedly created ${prefix}")
        endif()
        run_command("${CMAKE_COMMAND}" "-DPACKAGE_TEST_PREFIX=${prefix}" -P "${check}")
        message(STATUS "PASS absolute install: installed artifacts accepted")
    endif()
endfunction()

if(CASE STREQUAL "scope")
    run_function_scope()
elseif(CASE STREQUAL "stale")
    run_absolute_install(TRUE)
elseif(CASE STREQUAL "absolute")
    run_absolute_install(FALSE)
elseif(DEFINED CASE)
    message(FATAL_ERROR "Unknown case: ${CASE}")
else()
    run_single()
    run_absolute_libdir()
    run_function_scope()
    run_absolute_install(TRUE)
    run_absolute_install(FALSE)
endif()
file(REMOVE_RECURSE "${test_root}")
message(STATUS "Generated package artifact checks passed!")
