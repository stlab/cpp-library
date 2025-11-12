# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-ci.cmake - CI/CD configuration for cpp-library projects
#
# This module handles GitHub Actions workflow generation with PROJECT_NAME substitution

# Generates GitHub Actions CI workflow from template with PROJECT_NAME substitution.
# - Postcondition: .github/workflows/ci.yml created from template if not present
# - With force_init: overwrites existing workflow file
function(_cpp_library_setup_ci force_init)
    set(ci_template "${CPP_LIBRARY_ROOT}/templates/.github/workflows/ci.yml.in")
    set(ci_dest "${CMAKE_CURRENT_SOURCE_DIR}/.github/workflows/ci.yml")
    
    if(EXISTS "${ci_template}" AND (NOT EXISTS "${ci_dest}" OR force_init))
        get_filename_component(ci_dir "${ci_dest}" DIRECTORY)
        file(MAKE_DIRECTORY "${ci_dir}")
        configure_file("${ci_template}" "${ci_dest}" @ONLY)
        message(STATUS "Configured template file: .github/workflows/ci.yml")
    elseif(NOT EXISTS "${ci_template}")
        message(WARNING "CI template file not found: ${ci_template}")
    endif()
endfunction()
