# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-docs.cmake - Documentation setup with Doxygen

# Creates 'docs' target for generating API documentation with Doxygen and doxygen-awesome-css theme.
# - Precondition: NAME, VERSION, and DESCRIPTION specified; Doxygen available
# - Postcondition: 'docs' custom target created, Doxyfile configured, theme downloaded via CPM
function(_cpp_library_setup_docs)
    set(oneValueArgs
        NAME
        VERSION
        DESCRIPTION
    )
    set(multiValueArgs
        DOCS_EXCLUDE_SYMBOLS
        DOCS_INPUTS
        DOCS_OPTIONS
    )

    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(docs_extensions "")
    foreach(input IN LISTS ARG_DOCS_INPUTS)
        get_filename_component(input "${input}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        if(NOT EXISTS "${input}")
            message(FATAL_ERROR "cpp-library: Documentation input does not exist: ${input}")
        endif()
        string(REPLACE "\"" "\\\"" input "${input}")
        string(APPEND docs_extensions "INPUT += \"${input}\"\n")
    endforeach()
    foreach(option IN LISTS ARG_DOCS_OPTIONS)
        if(NOT option MATCHES "^[A-Z][A-Z0-9_]*[ \t]*\\+?=[^\r\n]*$")
            message(FATAL_ERROR
                "cpp-library: DOCS_OPTIONS requires single-line Doxygen assignments: ${option}")
        endif()
        string(APPEND docs_extensions "${option}\n")
    endforeach()

    find_package(Doxygen REQUIRED)

    # Download doxygen-awesome-css theme via CPM
    # https://github.com/jothepro/doxygen-awesome-css
    CPMAddPackage(
        # [DEPENDENCY] https://github.com/jothepro/doxygen-awesome-css/releases
        URI gh:jothepro/doxygen-awesome-css@2.5.0
        DOWNLOAD_ONLY YES
    )

    # Set the CSS directory path
    set(AWESOME_CSS_DIR ${doxygen-awesome-css_SOURCE_DIR})

    # Configure Doxyfile from template
    set(DOXYFILE_IN ${CPP_LIBRARY_ROOT}/templates/Doxyfile.in)
    set(DOXYFILE_OUT ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile)

    # Set variables for Doxyfile template
    set(PROJECT_NAME "${ARG_NAME}")
    set(PROJECT_BRIEF "${ARG_DESCRIPTION}")
    set(PROJECT_VERSION "${ARG_VERSION}")
    set(INPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
    set(OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    set(AWESOME_CSS_PATH "${AWESOME_CSS_DIR}")
    set(EXAMPLES_PATH "")
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/examples")
        set(EXAMPLES_PATH "${CMAKE_CURRENT_SOURCE_DIR}/examples")
    endif()

    # Convert exclude symbols list to space-separated string
    if(ARG_DOCS_EXCLUDE_SYMBOLS)
        string(REPLACE ";" " " EXCLUDE_SYMBOLS_STR "${ARG_DOCS_EXCLUDE_SYMBOLS}")
        set(EXCLUDE_SYMBOLS "${EXCLUDE_SYMBOLS_STR}")
    else()
        set(EXCLUDE_SYMBOLS "")
    endif()

    # Check if we have a custom Doxyfile, otherwise use template
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/docs/Doxyfile")
        configure_file("${CMAKE_CURRENT_SOURCE_DIR}/docs/Doxyfile" ${DOXYFILE_OUT} @ONLY)
    else()
        configure_file(${DOXYFILE_IN} ${DOXYFILE_OUT} @ONLY)
    endif()
    if(NOT docs_extensions STREQUAL "")
        file(APPEND "${DOXYFILE_OUT}"
            "\n# Project documentation settings supplied through cpp_library_setup.\n${docs_extensions}")
    endif()

    # Add custom target for documentation with proper stderr capture
    if(WIN32)
        # On Windows, use PowerShell to redirect stderr to stdout
        add_custom_target(docs
            COMMAND PowerShell -Command "& '${DOXYGEN_EXECUTABLE}' '${DOXYFILE_OUT}' 2>&1"
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            COMMENT "Generating API documentation with Doxygen"
            VERBATIM
        )
    else()
        # On Unix-like systems, use shell redirection
        add_custom_target(docs
            COMMAND ${DOXYGEN_EXECUTABLE} ${DOXYFILE_OUT} 2>&1
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            COMMENT "Generating API documentation with Doxygen"
            VERBATIM
        )
    endif()

    # Ensure the output directory exists
    file(MAKE_DIRECTORY ${OUTPUT_DIR})

    message(STATUS "Documentation target 'docs' configured")
    message(STATUS "Run 'cmake --build . --target docs' to generate documentation")

endfunction()
