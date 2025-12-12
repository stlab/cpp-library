# SPDX-License-Identifier: BSL-1.0
#
# Unit tests for dependency provider tracking
# These tests verify that the dependency provider correctly tracks dependencies

# Note: We can't actually test the provider installation itself in these unit tests
# since that requires being called during project(). Instead, we test the tracking
# functions directly and simulate tracked dependencies.

# Test 19: Direct provider tracking simulation
run_test("Provider tracking simulation - single dependency")
# Simulate what the provider would track
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_stlab-enum-ops" "stlab-enum-ops 1.0.0")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "stlab-enum-ops")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)
mock_target_links(test19_target "stlab::enum-ops")
_cpp_library_generate_dependencies(RESULT test19_target "stlab")
verify_output("${RESULT}" "find_dependency(stlab-enum-ops 1.0.0)" "Test 19")

# Test 20: Provider tracking with COMPONENTS
run_test("Provider tracking - Qt with COMPONENTS")
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6" "Qt6 6.5.0 COMPONENTS Core Widgets")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "Qt6")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)
mock_target_links(test20_target "Qt6::Core" "Qt6::Widgets")
_cpp_library_generate_dependencies(RESULT test20_target "mylib")
verify_output("${RESULT}" "find_dependency(Qt6 6.5.0 COMPONENTS Core Widgets)" "Test 20")

# Test 21: Provider tracking with multiple dependencies
run_test("Provider tracking - multiple dependencies")
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_stlab-enum-ops" "stlab-enum-ops 1.0.0")
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Boost" "Boost 1.79.0 COMPONENTS filesystem system")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "stlab-enum-ops")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "Boost")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)
mock_target_links(test21_target "stlab::enum-ops" "Boost::filesystem" "Threads::Threads")
_cpp_library_generate_dependencies(RESULT test21_target "stlab")
set(EXPECTED "find_dependency(stlab-enum-ops 1.0.0)\nfind_dependency(Boost 1.79.0 COMPONENTS filesystem system)\nfind_dependency(Threads)")
verify_output("${RESULT}" "${EXPECTED}" "Test 21")

# Test 22: Provider tracking with custom mapping override
run_test("Provider tracking - custom mapping override")
# Provider tracked one version
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_stlab-enum-ops" "stlab-enum-ops 2.0.0")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "stlab-enum-ops")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)
# But custom mapping overrides it
cpp_library_map_dependency("stlab::enum-ops" "stlab-enum-ops 1.5.0")
mock_target_links(test22_target "stlab::enum-ops")
_cpp_library_generate_dependencies(RESULT test22_target "stlab")
# Custom mapping should win
verify_output("${RESULT}" "find_dependency(stlab-enum-ops 1.5.0)" "Test 22")

# Test 23: Provider not installed - fallback to introspection
run_test("Fallback to introspection when provider not installed")
# No provider installed
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED)
# But version variable is set for fallback
set(stlab_enum_ops_VERSION "1.0.0")
mock_target_links(test23_target "stlab::enum-ops")
_cpp_library_generate_dependencies(RESULT test23_target "stlab")
verify_output("${RESULT}" "find_dependency(stlab-enum-ops 1.0.0)" "Test 23")

# Test 24: Provider tracking - system packages don't need tracking
run_test("Provider tracking - system packages")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)
# System packages like Threads don't need to be tracked
mock_target_links(test24_target "Threads::Threads" "OpenMP::OpenMP_CXX")
_cpp_library_generate_dependencies(RESULT test24_target "mylib")
set(EXPECTED "find_dependency(Threads)\nfind_dependency(OpenMP)")
verify_output("${RESULT}" "${EXPECTED}" "Test 24")

# Test 25: Provider tracking - complex real-world with tracking
run_test("Provider tracking - complex real-world scenario")
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_stlab-enum-ops" "stlab-enum-ops 1.0.0")
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6" "Qt6 6.5.0 COMPONENTS Core Widgets")
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_OpenCV" "OpenCV 4.5.0")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "stlab-enum-ops")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "Qt6")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "OpenCV")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)
# Non-namespaced targets need custom mapping
cpp_library_map_dependency("opencv_core" "OpenCV 4.5.0")
# Mix of tracked dependencies and system packages
mock_target_links(test25_target "stlab::enum-ops" "Qt6::Core" "Qt6::Widgets" "opencv_core" "Threads::Threads")
_cpp_library_generate_dependencies(RESULT test25_target "stlab")
set(EXPECTED "find_dependency(stlab-enum-ops 1.0.0)\nfind_dependency(Qt6 6.5.0 COMPONENTS Core Widgets)\nfind_dependency(OpenCV 4.5.0)\nfind_dependency(Threads)")
verify_output("${RESULT}" "${EXPECTED}" "Test 25")

# Test 26: Provider tracking with CONFIG flag
run_test("Provider tracking - with CONFIG flag")
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_MyPackage" "MyPackage 2.0.0 CONFIG")
set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "MyPackage")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)
mock_target_links(test26_target "MyPackage::MyPackage")
_cpp_library_generate_dependencies(RESULT test26_target "mylib")
verify_output("${RESULT}" "find_dependency(MyPackage 2.0.0 CONFIG)" "Test 26")

