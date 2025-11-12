# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-ci.cmake - CI/CD configuration for cpp-library projects
#
# This module handles GitHub Actions workflow generation with PROJECT_NAME substitution

# Function to configure CI workflow template
function(_cpp_library_setup_ci)
    set(options FORCE_INIT)
    cmake_parse_arguments(ARG "${options}" "" "" ${ARGN})
    
    set(ci_template "${CPP_LIBRARY_ROOT}/templates/.github/workflows/ci.yml.in")
    set(ci_dest "${CMAKE_CURRENT_SOURCE_DIR}/.github/workflows/ci.yml")
    
    if(EXISTS "${ci_template}" AND (NOT EXISTS "${ci_dest}" OR ARG_FORCE_INIT))
        get_filename_component(ci_dir "${ci_dest}" DIRECTORY)
        file(MAKE_DIRECTORY "${ci_dir}")
        configure_file("${ci_template}" "${ci_dest}" @ONLY)
        message(STATUS "Configured template file: .github/workflows/ci.yml")
    elseif(NOT EXISTS "${ci_template}")
        message(WARNING "CI template file not found: ${ci_template}")
    endif()
endfunction()
