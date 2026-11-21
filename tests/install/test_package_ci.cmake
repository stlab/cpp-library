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
    run_command("${CMAKE_COMMAND}" --install "${binary}" --prefix "${workflow_prefix}")
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

# Exercises source-only presets and preserves consumer-owned template changes.
function(run_source_presets custom)
    set(root "${test_root}/presets-${custom}")
    set(source "${root}/source")
    set(binary "${root}/bootstrap")
    set(install_option STLAB_INSTALL)
    set(args)
    if(custom)
        set(install_option SINGLE_PACKAGE_INSTALL)
        list(APPEND args "-DCUSTOM_INSTALL_OPTION=${install_option}")
    endif()
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/single/" DESTINATION "${source}")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" "-D${install_option}=OFF" ${args})

    foreach(preset default test)
        run_command("${CMAKE_COMMAND}" -E chdir "${source}"
            "${CMAKE_COMMAND}" --preset "${preset}" "-DTOOLKIT_SOURCE=${toolkit_source}"
            -DSOURCE_ONLY_DEPENDENCY=ON ${args})
        run_command("${CMAKE_COMMAND}" --build "${source}/build/${preset}")
        file(READ "${source}/build/${preset}/cmake_install.cmake" install_script)
        if(install_script MATCHES "stlab-single")
            message(FATAL_ERROR "${preset}: source-only preset registered package installation")
        endif()
    endforeach()

    set(presets "${source}/CMakePresets.json")
    set(workflow "${source}/.github/workflows/ci.yml")
    file(READ "${presets}" original_presets)
    string(JSON count LENGTH "${original_presets}" configurePresets)
    math(EXPR last "${count} - 1")
    foreach(index RANGE 0 ${last})
        string(JSON name GET "${original_presets}" configurePresets ${index} name)
        string(JSON value GET "${original_presets}" configurePresets ${index}
            cacheVariables "${install_option}")
        set(expected OFF)
        if(name STREQUAL "install")
            set(expected ON)
        endif()
        if(NOT value STREQUAL expected)
            message(FATAL_ERROR "${name}: expected ${install_option}=${expected}, got ${value}")
        endif()
    endforeach()
    file(READ "${workflow}" original_workflow)
    if(original_workflow MATCHES "cmake --install|cpp-library-test-package")
        message(FATAL_ERROR "Generated CI still installs or checks package artifacts")
    endif()

    file(APPEND "${presets}" "\n ")
    file(APPEND "${workflow}" "\n# consumer-owned workflow\n")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}")
    file(READ "${presets}" preserved_presets)
    file(READ "${workflow}" preserved_workflow)
    if(NOT preserved_presets STREQUAL "${original_presets}\n "
            OR NOT preserved_workflow STREQUAL "${original_workflow}\n# consumer-owned workflow\n")
        message(FATAL_ERROR "Consumer templates changed without force initialization")
    endif()
    run_command("${CMAKE_COMMAND}" -E chdir "${source}"
        "${CMAKE_COMMAND}" --preset init "-DTOOLKIT_SOURCE=${toolkit_source}" ${args})
    file(READ "${presets}" regenerated_presets)
    file(READ "${workflow}" regenerated_workflow)
    if(NOT regenerated_presets STREQUAL original_presets
            OR NOT regenerated_workflow STREQUAL original_workflow)
        message(FATAL_ERROR "Force initialization did not regenerate consumer templates")
    endif()
    run_command("${CMAKE_COMMAND}" -E chdir "${source}"
        "${CMAKE_COMMAND}" --preset install "-DTOOLKIT_SOURCE=${toolkit_source}" ${args})
    run_command("${CMAKE_COMMAND}" --install "${source}/build/install"
        --prefix "${root}/install")
    run_command("${CMAKE_COMMAND}" "-DPACKAGE_TEST_PREFIX=${root}/install"
        -P "${source}/build/install/cpp-library-test-package.cmake")
    message(STATUS "PASS presets-${custom}: source-only builds and explicit installation")
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
    run_source_presets(FALSE)
    run_source_presets(TRUE)
    run_single()
    run_absolute_libdir()
    run_function_scope()
    run_absolute_install(TRUE)
    run_absolute_install(FALSE)
endif()
file(REMOVE_RECURSE "${test_root}")
message(STATUS "Generated package artifact checks passed!")
