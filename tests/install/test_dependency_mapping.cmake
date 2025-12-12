# SPDX-License-Identifier: BSL-1.0
#
# Unit tests for dependency mapping and merging

# Test 1: System package (Threads) - no version required
run_test("System package without version")
mock_target_links(test1_target "Threads::Threads")
_cpp_library_generate_dependencies(RESULT test1_target "mylib")
verify_output("${RESULT}" "find_dependency(Threads)" "Test 1")

# Test 2: Single external dependency with version
run_test("External dependency with version")
set(Boost_VERSION "1.75.0")
mock_target_links(test2_target "Boost::filesystem")
_cpp_library_generate_dependencies(RESULT test2_target "mylib")
verify_output("${RESULT}" "find_dependency(Boost 1.75.0)" "Test 2")

# Test 3: Internal cpp-library dependency
run_test("Internal cpp-library dependency")
set(stlab_enum_ops_VERSION "1.0.0")
mock_target_links(test3_target "stlab::enum-ops")
_cpp_library_generate_dependencies(RESULT test3_target "stlab")
verify_output("${RESULT}" "find_dependency(stlab-enum-ops 1.0.0)" "Test 3")

# Test 4: Multiple Qt components - should merge
run_test("Multiple Qt components merging")
cpp_library_map_dependency("Qt6::Core" "Qt6 6.5.0 COMPONENTS Core")
cpp_library_map_dependency("Qt6::Widgets" "Qt6 6.5.0 COMPONENTS Widgets")
cpp_library_map_dependency("Qt6::Network" "Qt6 6.5.0 COMPONENTS Network")
mock_target_links(test4_target "Qt6::Core" "Qt6::Widgets" "Qt6::Network")
_cpp_library_generate_dependencies(RESULT test4_target "mylib")
verify_output("${RESULT}" "find_dependency(Qt6 6.5.0 COMPONENTS Core Widgets Network)" "Test 4")

# Test 5: Multiple dependencies with different packages
run_test("Multiple different packages")
set(stlab_enum_ops_VERSION "1.0.0")
set(stlab_copy_on_write_VERSION "2.1.0")
mock_target_links(test5_target "stlab::enum-ops" "stlab::copy-on-write" "Threads::Threads")
_cpp_library_generate_dependencies(RESULT test5_target "stlab")
set(EXPECTED "find_dependency(stlab-enum-ops 1.0.0)\nfind_dependency(stlab-copy-on-write 2.1.0)\nfind_dependency(Threads)")
verify_output("${RESULT}" "${EXPECTED}" "Test 5")

# Test 6: Custom mapping with non-namespaced target
run_test("Non-namespaced target with custom mapping")
cpp_library_map_dependency("opencv_core" "OpenCV 4.5.0")
mock_target_links(test6_target "opencv_core")
_cpp_library_generate_dependencies(RESULT test6_target "mylib")
verify_output("${RESULT}" "find_dependency(OpenCV 4.5.0)" "Test 6")

# Test 7: Duplicate components should be deduplicated
run_test("Duplicate components deduplication")
cpp_library_map_dependency("Qt6::Core" "Qt6 6.5.0 COMPONENTS Core")
# Intentionally add Core twice
mock_target_links(test7_target "Qt6::Core" "Qt6::Core")
_cpp_library_generate_dependencies(RESULT test7_target "mylib")
verify_output("${RESULT}" "find_dependency(Qt6 6.5.0 COMPONENTS Core)" "Test 7")

# Test 8: Multiple Qt components with different versions (should NOT merge)
run_test("Different versions should not merge")
cpp_library_map_dependency("Qt6::Core" "Qt6 6.5.0 COMPONENTS Core")
cpp_library_map_dependency("Qt5::Widgets" "Qt5 5.15.0 COMPONENTS Widgets")
mock_target_links(test8_target "Qt6::Core" "Qt5::Widgets")
_cpp_library_generate_dependencies(RESULT test8_target "mylib")
set(EXPECTED "find_dependency(Qt6 6.5.0 COMPONENTS Core)\nfind_dependency(Qt5 5.15.0 COMPONENTS Widgets)")
verify_output("${RESULT}" "${EXPECTED}" "Test 8")

# Test 9: Component merging with additional args
run_test("Components with additional arguments")
cpp_library_map_dependency("Qt6::Core" "Qt6 6.5.0 COMPONENTS Core CONFIG")
cpp_library_map_dependency("Qt6::Widgets" "Qt6 6.5.0 COMPONENTS Widgets CONFIG")
mock_target_links(test9_target "Qt6::Core" "Qt6::Widgets")
_cpp_library_generate_dependencies(RESULT test9_target "mylib")
verify_output("${RESULT}" "find_dependency(Qt6 6.5.0 COMPONENTS Core Widgets CONFIG)" "Test 9")

# Test 10: Mixed components and non-component targets
run_test("Mixed Qt components and system packages")
cpp_library_map_dependency("Qt6::Core" "Qt6 6.5.0 COMPONENTS Core")
cpp_library_map_dependency("Qt6::Widgets" "Qt6 6.5.0 COMPONENTS Widgets")
mock_target_links(test10_target "Qt6::Core" "Qt6::Widgets" "Threads::Threads")
_cpp_library_generate_dependencies(RESULT test10_target "mylib")
set(EXPECTED "find_dependency(Qt6 6.5.0 COMPONENTS Core Widgets)\nfind_dependency(Threads)")
verify_output("${RESULT}" "${EXPECTED}" "Test 10")

# Test 11: Namespace matching (namespace::namespace)
run_test("Namespace equals component")
set(mylib_VERSION "1.5.0")
mock_target_links(test11_target "mylib::mylib")
_cpp_library_generate_dependencies(RESULT test11_target "mylib")
verify_output("${RESULT}" "find_dependency(mylib 1.5.0)" "Test 11")

# Test 12: OpenMP system package
run_test("OpenMP system package")
mock_target_links(test12_target "OpenMP::OpenMP_CXX")
_cpp_library_generate_dependencies(RESULT test12_target "mylib")
verify_output("${RESULT}" "find_dependency(OpenMP)" "Test 12")

# Test 13: Empty INTERFACE_LINK_LIBRARIES
run_test("Empty link libraries")
mock_target_links(test13_target)
_cpp_library_generate_dependencies(RESULT test13_target "mylib")
verify_output("${RESULT}" "" "Test 13")

# Test 14: Generator expressions should be skipped
run_test("Generator expressions skipped")
mock_target_links(test14_target "Threads::Threads" "$<BUILD_INTERFACE:some_local_target>")
_cpp_library_generate_dependencies(RESULT test14_target "mylib")
verify_output("${RESULT}" "find_dependency(Threads)" "Test 14")

# Test 15: Multiple Boost components (same package, different components)
run_test("Boost with multiple components")
cpp_library_map_dependency("Boost::filesystem" "Boost 1.75.0 COMPONENTS filesystem")
cpp_library_map_dependency("Boost::system" "Boost 1.75.0 COMPONENTS system")
cpp_library_map_dependency("Boost::thread" "Boost 1.75.0 COMPONENTS thread")
mock_target_links(test15_target "Boost::filesystem" "Boost::system" "Boost::thread")
_cpp_library_generate_dependencies(RESULT test15_target "mylib")
verify_output("${RESULT}" "find_dependency(Boost 1.75.0 COMPONENTS filesystem system thread)" "Test 15")

# Test 16: Custom mapping overrides automatic detection
run_test("Custom mapping override")
set(stlab_enum_ops_VERSION "2.0.0")
# Manual mapping should override the automatic version detection
cpp_library_map_dependency("stlab::enum-ops" "stlab-enum-ops 1.5.0")
mock_target_links(test16_target "stlab::enum-ops")
_cpp_library_generate_dependencies(RESULT test16_target "stlab")
verify_output("${RESULT}" "find_dependency(stlab-enum-ops 1.5.0)" "Test 16")

# Test 17: ZLIB system package
run_test("ZLIB system package")
mock_target_links(test17_target "ZLIB::ZLIB")
_cpp_library_generate_dependencies(RESULT test17_target "mylib")
verify_output("${RESULT}" "find_dependency(ZLIB)" "Test 17")

# Test 18: Complex real-world scenario
run_test("Complex real-world scenario")
set(stlab_enum_ops_VERSION "1.0.0")
cpp_library_map_dependency("Qt6::Core" "Qt6 6.5.0 COMPONENTS Core")
cpp_library_map_dependency("Qt6::Widgets" "Qt6 6.5.0 COMPONENTS Widgets")
cpp_library_map_dependency("opencv_core" "OpenCV 4.5.0")
mock_target_links(test18_target "stlab::enum-ops" "Qt6::Core" "Qt6::Widgets" "opencv_core" "Threads::Threads" "OpenMP::OpenMP_CXX")
_cpp_library_generate_dependencies(RESULT test18_target "stlab")
set(EXPECTED "find_dependency(stlab-enum-ops 1.0.0)\nfind_dependency(Qt6 6.5.0 COMPONENTS Core Widgets)\nfind_dependency(OpenCV 4.5.0)\nfind_dependency(Threads)\nfind_dependency(OpenMP)")
verify_output("${RESULT}" "${EXPECTED}" "Test 18")

