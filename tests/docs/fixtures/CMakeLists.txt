cmake_minimum_required(VERSION 3.24)
project(docs-fixture LANGUAGES CXX)
include("${TOOLKIT_SOURCE}/cpp-library.cmake")
set(CPP_LIBRARY_VERSION 1.2.3)
set(FIXTURE_INSTALL OFF CACHE BOOL "")
set(BUILD_DOCS ON)

# Replace only the network theme download; exercise real configuration and Doxygen.
function(CPMAddPackage)
    file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/theme")
    foreach(stylesheet doxygen-awesome.css doxygen-awesome-sidebar-only.css)
        file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/theme/${stylesheet}" "")
    endforeach()
    set(doxygen-awesome-css_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/theme" PARENT_SCOPE)
endfunction()

set(docs_args)
if(CASE STREQUAL "extended")
    list(APPEND docs_args
        DOCS_INPUTS "extra docs" "${CMAKE_CURRENT_SOURCE_DIR}/absolute docs/group.dox"
        DOCS_OPTIONS
            "PROJECT_BRIEF = \"Customized documentation\""
            "WARN_IF_UNDOCUMENTED = NO"
            [=[PREDEFINED = "FIXTURE_PATH=C:\\docs\\"]=]
            "EXCLUDE_SYMBOLS += fixture::extra"
        DOCS_EXCLUDE_SYMBOLS "fixture::hidden")
elseif(CASE STREQUAL "missing-input")
    list(APPEND docs_args DOCS_INPUTS "missing docs")
elseif(CASE STREQUAL "malformed-option")
    list(APPEND docs_args DOCS_OPTIONS "not a Doxygen assignment")
elseif(CASE STREQUAL "malformed-terminal-continuation-option")
    list(APPEND docs_args DOCS_OPTIONS [=[PREDEFINED = A= \]=])
elseif(CASE STREQUAL "malformed-continuation-option")
    list(APPEND docs_args DOCS_OPTIONS
        [=[PREDEFINED = A= \ ]=]
        "WARN_IF_UNDOCUMENTED = NO")
elseif(CASE STREQUAL "multiline-option")
    list(APPEND docs_args DOCS_OPTIONS "QUIET = YES\nGENERATE_XML = YES")
elseif(CASE STREQUAL "missing-input-value")
    list(APPEND docs_args DOCS_INPUTS)
elseif(CASE STREQUAL "missing-option-value")
    list(APPEND docs_args DOCS_OPTIONS)
elseif(CASE STREQUAL "custom")
    file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/docs")
    file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/docs/Doxyfile"
        "PROJECT_NAME = \"Legacy configuration\"\n"
        "INPUT = \"@INPUT_DIR@\"\n"
        "OUTPUT_DIRECTORY = \"@OUTPUT_DIR@\"\n"
        "GENERATE_LATEX = NO\nQUIET = YES\nWARN_AS_ERROR = YES\n")
    list(APPEND docs_args DOCS_INPUTS "extra docs"
        DOCS_OPTIONS "PROJECT_BRIEF = \"Customized documentation\"")
endif()

cpp_library_setup(
    DESCRIPTION "Documentation fixture"
    NAMESPACE fixture
    INSTALL_OPTION FIXTURE_INSTALL
    HEADERS api.hpp
    ${docs_args})
