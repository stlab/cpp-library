# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-ci.cmake - CI setup functionality

function(_cpp_library_setup_ci)
    set(oneValueArgs
        NAME
        VERSION
        DESCRIPTION
        CI_DEPLOY_DOCS  # Always YES, but kept as parameter for template substitution
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "" ${ARGN})
    
    # Only generate CI files if they don't exist
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.github/workflows/ci.yml")
        # Create .github/workflows directory
        file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.github/workflows")
        
        # Determine template source
        if(DEFINED CPP_LIBRARY_CI_TEMPLATE)
            # Embedded template (packaged version)
            file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/cpp-library-ci.yml.in" "${CPP_LIBRARY_CI_TEMPLATE}")
            set(TEMPLATE_FILE "${CMAKE_CURRENT_BINARY_DIR}/cpp-library-ci.yml.in")
        else()
            # External template file (development version)
            set(TEMPLATE_FILE "${CPP_LIBRARY_ROOT}/templates/.github/workflows/ci.yml.in")
        endif()
        
        # Configure template variables
        set(PROJECT_NAME "${ARG_NAME}")
        set(PROJECT_VERSION "${ARG_VERSION}")
        set(PROJECT_DESCRIPTION "${ARG_DESCRIPTION}")
        set(ENABLE_DOCS_DEPLOYMENT "true")  # Always enable docs deployment
        
        configure_file(
            "${TEMPLATE_FILE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/.github/workflows/ci.yml"
            @ONLY
        )
        
        message(STATUS "Generated .github/workflows/ci.yml for ${ARG_NAME}")
    endif()
    
endfunction()
