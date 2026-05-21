# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-ci.cmake - CI/CD configuration for cpp-library projects
#
# This module handles GitHub Actions workflow generation with PROJECT_NAME substitution

# Generates GitHub Actions CI workflow from template with PACKAGE_NAME substitution.
# - Precondition: PACKAGE_NAME must be set in parent scope
# - Postcondition: .github/workflows/ci.yml created from template if not present
# - With force_init: overwrites existing workflow file
function(_cpp_library_setup_ci PACKAGE_NAME force_init)
    # GitHub Actions refs (versions and source links) - update here to bump CI deps
    # [DEPENDENCY] https://github.com/actions/checkout/releases
    set(CI_ACTION_CHECKOUT "actions/checkout@v6")
    # [DEPENDENCY] https://github.com/ilammy/msvc-dev-cmd/releases
    # @1.13.0
    set(CI_ACTION_MSVC_DEV_CMD "ilammy/msvc-dev-cmd@0b201ec74fa43914dc39ae48a89fd1d8cb592756")
    # [DEPENDENCY] https://github.com/ssciwr/doxygen-install/releases
    # @2.0.1
    set(CI_ACTION_DOXYGEN_INSTALL "ssciwr/doxygen-install@329d88f5a303066a5bd006db7516b1925b86350e")
    # [DEPENDENCY] https://github.com/actions/configure-pages/releases
    set(CI_ACTION_CONFIGURE_PAGES "actions/configure-pages@v6")
    # [DEPENDENCY] https://github.com/actions/upload-pages-artifact/releases
    set(CI_ACTION_UPLOAD_PAGES_ARTIFACT "actions/upload-pages-artifact@v5")
    # [DEPENDENCY] https://github.com/actions/deploy-pages/releases
    set(CI_ACTION_DEPLOY_PAGES "actions/deploy-pages@v5")

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
