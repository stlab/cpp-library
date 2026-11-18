# SPDX-License-Identifier: BSL-1.0
#
# Unit tests for resolving dependencies added through CPM.
#
# CPM records every added package in `CPM_PACKAGES` and its version in
# `CPM_PACKAGE_<name>_VERSION`, including packages served from `CPM_SOURCE_CACHE`, which
# bypass `FetchContent_MakeAvailable()` and therefore the dependency provider.

run_test("CPM package from source cache without provider tracking")
set(CPM_PACKAGES "cel-runtime")
set(CPM_PACKAGE_cel-runtime_VERSION "1.1.0")
mock_target_links(cpm1_target "cel::runtime")
_cpp_library_generate_dependencies(RESULT cpm1_target "cel" UNVERIFIED)
verify_output("${RESULT}" "find_dependency(cel-runtime 1.1.0)" "CPM cached package resolves with version")
verify_output("${UNVERIFIED}" "" "CPM cached package is verified")

run_test("CPM package tracked by FetchContent takes CPM version")
_cpp_library_dependency_provider(FETCHCONTENT_MAKEAVAILABLE_SERIAL stlab-enum-ops
    SOURCE_DIR /cache/stlab-enum-ops BINARY_DIR /build/_deps/stlab-enum-ops-build
    GIT_REPOSITORY https://github.com/stlab/stlab-enum-ops.git GIT_TAG v1.0.0
    EXCLUDE_FROM_ALL SYSTEM)
set(CPM_PACKAGES "stlab-enum-ops")
set(CPM_PACKAGE_stlab-enum-ops_VERSION "1.0.0")
mock_target_links(cpm2_target "stlab::enum-ops")
_cpp_library_generate_dependencies(RESULT cpm2_target "stlab")
verify_output("${RESULT}" "find_dependency(stlab-enum-ops 1.0.0)" "FetchContent-tracked CPM package gains version")

run_test("FetchContent tracking records only the dependency name")
_cpp_library_dependency_provider(FETCHCONTENT_MAKEAVAILABLE_SERIAL cel-runtime
    SOURCE_DIR /cache/cel-runtime GIT_TAG 2dd73e9c26c6d02c79bfb26f82521c62a1bfd079)
_cpp_library_get_all_tracked_deps(TRACKED)
verify_output("${TRACKED}" "cel-runtime" "Declaration arguments are not tracked as packages")

run_test("CPM package without a derivable version")
set(CPM_PACKAGES "cel-runtime")
set(CPM_PACKAGE_cel-runtime_VERSION "0")
mock_target_links(cpm4_target "cel::runtime")
_cpp_library_generate_dependencies(RESULT cpm4_target "cel" UNVERIFIED)
verify_output("${RESULT}" "find_dependency(cel-runtime)" "CPM placeholder version 0 is omitted")
verify_output("${UNVERIFIED}" "" "Versionless CPM package is verified")

run_test("Provider find_package tracking takes precedence over CPM registry")
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6" "Qt6 6.5.0 COMPONENTS Core")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "Qt6")
set(CPM_PACKAGES "Qt6")
set(CPM_PACKAGE_Qt6_VERSION "6.5.0")
mock_target_links(cpm5_target "Qt6::Core")
_cpp_library_generate_dependencies(RESULT cpm5_target "mylib")
verify_output("${RESULT}" "find_dependency(Qt6 6.5.0 COMPONENTS Core)" "find_package details are preserved")
