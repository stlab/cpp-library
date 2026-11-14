# SPDX-License-Identifier: BSL-1.0
#
# Run as: cmake -P tests/install/test_package_ci.cmake
cmake_minimum_required(VERSION 3.24)

get_filename_component(toolkit_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef test_id)
set(test_root "${toolkit_source}/build/package-ci-${test_id}")

# Runs a build tool and reports its output on failure.
function(run_command)
    execute_process(COMMAND ${ARGN}
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Command failed (${result}): ${ARGN}\n${out}\n${err}")
    endif()
endfunction()

# Checks packaging without changing the excluded dependency's normal installation.
function(run_case name shared generator config leaf_installed)
    set(root "${test_root}/${name} with spaces")
    set(source "${root}/source")
    set(binary "${root}/build")
    set(prefix "${root}/normal-install")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/nested/" DESTINATION "${source}")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G "${generator}"
        "-DTOOLKIT_SOURCE=${toolkit_source}" "-DBUILD_SHARED_LIBS=${shared}"
        "-DCMAKE_BUILD_TYPE=${config}" -DEXCLUDE_LEAF_FROM_ALL=ON
        -DSTLAB_PARENT_INSTALL=ON "-DSTLAB_LEAF_INSTALL=${leaf_installed}" ${ARGN})
    run_command("${CMAKE_COMMAND}" --build "${binary}" --target leaf --config "${config}")
    run_command("${CMAKE_COMMAND}" --install "${binary}" --prefix "${prefix}"
        --config "${config}")
    if(EXISTS "${prefix}/lib/cmake/stlab-leaf/stlab-leafConfig.cmake")
        message(FATAL_ERROR "Normal parent installation must still exclude the leaf")
    endif()
    set(consumer "${root}/missing-dependency")
    file(MAKE_DIRECTORY "${consumer}")
    file(WRITE "${consumer}/CMakeLists.txt"
        "cmake_minimum_required(VERSION 3.24)\nproject(consumer LANGUAGES CXX)\nfind_package(stlab-parent REQUIRED)\n")
    execute_process(COMMAND "${CMAKE_COMMAND}" -S "${consumer}" -B "${consumer}/build"
        -G "${generator}" "-DCMAKE_PREFIX_PATH=${prefix}"
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(result EQUAL 0 OR NOT "${out}\n${err}" MATCHES "stlab-leaf")
        message(FATAL_ERROR "Expected the parent-only install to lack stlab-leaf:\n${out}\n${err}")
    endif()
    set(check "${binary}/cpp-library-test-package.cmake")
    if(NOT EXISTS "${check}")
        message(FATAL_ERROR "Missing generated packaging check: ${check}")
    endif()
    if(leaf_installed)
        run_command("${CMAKE_COMMAND}" "-DCONFIG=${config}" -P "${check}")
    else()
        execute_process(COMMAND "${CMAKE_COMMAND}" "-DCONFIG=${config}" -P "${check}"
            RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
        if(result EQUAL 0 OR NOT "${out}\n${err}" MATCHES "stlab-leaf")
            message(FATAL_ERROR "Expected disabled leaf installation to fail packaging:\n${out}\n${err}")
        endif()
    endif()
    if(EXISTS "${prefix}/lib/cmake/stlab-leaf/stlab-leafConfig.cmake")
        message(FATAL_ERROR "Packaging check must not modify the normal install prefix")
    endif()
    message(STATUS "PASS ${name}: isolated packaging with an excluded dependency")
endfunction()

# Checks that packages without dependencies also receive a working generated check.
function(run_single)
    set(root "${test_root}/single")
    set(source "${root}/source")
    set(binary "${root}/build")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/single/" DESTINATION "${source}")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" -DCMAKE_BUILD_TYPE=Release)
    run_command("${CMAKE_COMMAND}" --build "${binary}")
    run_command("${CMAKE_COMMAND}" -P "${binary}/cpp-library-test-package.cmake")
    message(STATUS "PASS single: dependency-free generated packaging check")
endfunction()

# Keeps externally installed dependencies discoverable through a prefix list.
function(run_external)
    set(root "${test_root}/external with spaces")
    set(dependency "${root}/dependency")
    set(external_prefix "${root}/installed dependency")
    file(MAKE_DIRECTORY "${dependency}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/nested/leaf/extra/" DESTINATION "${dependency}")
    run_command("${CMAKE_COMMAND}" -S "${dependency}" -B "${dependency}/build" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" -DCMAKE_BUILD_TYPE=Release)
    run_command("${CMAKE_COMMAND}" --install "${dependency}/build" --prefix "${external_prefix}")
    set(source "${root}/source")
    set(binary "${root}/build")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/single/" DESTINATION "${source}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" -DCMAKE_BUILD_TYPE=Release -DEXTERNAL_PACKAGE=ON
        "-DCMAKE_PREFIX_PATH=${root}/unused;${external_prefix}"
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "External dependency fixture failed:\n${out}\n${err}")
    endif()
    run_command("${CMAKE_COMMAND}" --build "${binary}")
    run_command("${CMAKE_COMMAND}" -P "${binary}/cpp-library-test-package.cmake")
    message(STATUS "PASS external: semicolon-separated dependency prefixes preserved")
endfunction()

# Rejects an existing installation when this build did not install its package.
function(run_shadow)
    set(root "${test_root}/shadow")
    set(source "${root}/source")
    set(binary "${root}/build")
    set(old_prefix "${root}/previous installation")
    file(MAKE_DIRECTORY "${source}")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/fixtures/single/" DESTINATION "${source}")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -G Ninja
        "-DTOOLKIT_SOURCE=${toolkit_source}" -DCMAKE_BUILD_TYPE=Release)
    run_command("${CMAKE_COMMAND}" --install "${binary}" --prefix "${old_prefix}")
    run_command("${CMAKE_COMMAND}" -S "${source}" -B "${binary}" -DSTLAB_INSTALL=OFF)
    execute_process(COMMAND "${CMAKE_COMMAND}" -E env "CMAKE_PREFIX_PATH=${old_prefix}"
        "${CMAKE_COMMAND}" -P "${binary}/cpp-library-test-package.cmake"
        RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE err)
    if(result EQUAL 0 OR NOT "${out}\n${err}" MATCHES "stlab-single")
        message(FATAL_ERROR "Packaging must reject a previously installed package:\n${out}\n${err}")
    endif()
    message(STATUS "PASS shadow: previous installation cannot mask missing staged package")
endfunction()

if(CASE STREQUAL "external")
    run_external()
elseif(CASE STREQUAL "shadow")
    run_shadow()
elseif(DEFINED CASE)
    message(FATAL_ERROR "Unknown packaging case: ${CASE}")
else()
    run_case(static OFF Ninja Release ON)
    run_case(shared ON Ninja Release ON)
    run_case(multi-config OFF "Ninja Multi-Config" Debug ON)
    run_case(transitive OFF Ninja Release ON -DPACKAGE_TEST_EXTRA=ON)
    run_case(disabled-dependency OFF Ninja Release OFF)
    run_single()
    run_external()
    run_shadow()
endif()
file(REMOVE_RECURSE "${test_root}")
message(STATUS "Generated packaging checks passed!")
