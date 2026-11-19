# Compiler-only fixtures do not test registration; source_testing uses real doctest.
if(NOT TARGET doctest::doctest)
    add_library(doctest::doctest INTERFACE IMPORTED)
    set(mock_doctest "${CMAKE_CURRENT_BINARY_DIR}/mock-doctest")
    file(WRITE "${mock_doctest}/doctest/doctest.h"
        "#if defined(DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN)\nint main() { return 0; }\n#endif\n")
    set_property(TARGET doctest::doctest PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${mock_doctest}")
endif()
