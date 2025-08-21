# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-docs.cmake - Documentation setup with Doxygen

function(_cpp_library_setup_docs)
    set(oneValueArgs
        NAME
        VERSION
        DESCRIPTION
    )
    set(multiValueArgs
        DOCS_EXCLUDE_SYMBOLS
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    find_package(Doxygen REQUIRED)
    if(NOT DOXYGEN_FOUND)
        message(WARNING "Doxygen not found. Documentation will not be built.")
        return()
    endif()
    
    # Download doxygen-awesome-css theme via CPM
    if(NOT TARGET doxygen-awesome-css)
        CPMAddPackage(
            NAME doxygen-awesome-css
            URI gh:jothepro/doxygen-awesome-css@2.3.4
            DOWNLOAD_ONLY YES
        )
    endif()
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
    set(EXAMPLE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/example")
    
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
    
    # Add custom target for documentation
    add_custom_target(docs
        COMMAND ${DOXYGEN_EXECUTABLE} ${DOXYFILE_OUT}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Generating API documentation with Doxygen"
        VERBATIM
    )
    
    # Ensure the output directory exists
    file(MAKE_DIRECTORY ${OUTPUT_DIR})
    
    message(STATUS "Documentation target 'docs' configured")
    message(STATUS "Run 'cmake --build . --target docs' to generate documentation")
    
endfunction()
