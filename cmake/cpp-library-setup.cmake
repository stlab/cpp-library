# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-setup.cmake - Core library setup functionality

# Returns version string from CPP_LIBRARY_VERSION cache variable (if set), git tag (with 'v' prefix removed), or 
#    "0.0.0" fallback
function(_cpp_library_get_git_version OUTPUT_VAR)
    # If CPP_LIBRARY_VERSION is set (e.g., by vcpkg or other package manager via -DCPP_LIBRARY_VERSION=x.y.z),
    # use it instead of trying to query git (which may not be available in source archives)
    if(DEFINED CPP_LIBRARY_VERSION AND NOT CPP_LIBRARY_VERSION STREQUAL "")
        set(${OUTPUT_VAR} "${CPP_LIBRARY_VERSION}" PARENT_SCOPE)
        return()
    endif()
    
    # Try to get version from git tags
    execute_process(
        COMMAND git describe --tags --abbrev=0
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_TAG_VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    # If git tag found, use it (remove 'v' prefix if present)
    if(GIT_TAG_VERSION)
        string(REGEX REPLACE "^v" "" CLEAN_VERSION "${GIT_TAG_VERSION}")
        set(${OUTPUT_VAR} "${CLEAN_VERSION}" PARENT_SCOPE)
    else()
        # Fallback to 0.0.0 if no git tag found
        set(${OUTPUT_VAR} "0.0.0" PARENT_SCOPE)
        message(WARNING "No git tag found, using version 0.0.0. Consider creating a git tag for proper versioning.")
    endif()
endfunction()

# Creates library target (INTERFACE or compiled) with headers and proper configuration.
# - Precondition: NAME, NAMESPACE, PACKAGE_NAME, CLEAN_NAME, and REQUIRES_CPP_VERSION specified
# - Postcondition: library target created with alias NAMESPACE::CLEAN_NAME, install configured if TOP_LEVEL
function(_cpp_library_setup_core)
    set(oneValueArgs
        NAME
        VERSION
        DESCRIPTION
        NAMESPACE
        PACKAGE_NAME
        CLEAN_NAME
        REQUIRES_CPP_VERSION
        TOP_LEVEL
    )
    set(multiValueArgs
        HEADERS
        SOURCES
    )

    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get version from git tags if not provided
    if(NOT ARG_VERSION)
        _cpp_library_get_git_version(GIT_VERSION)
        set(ARG_VERSION "${GIT_VERSION}")
    endif()

    # Note: Project declaration is now handled in the main cpp_library_setup function
    # No need to check ARG_TOP_LEVEL here for project declaration

    if(ARG_SOURCES)
        # Create a library with sources (respects BUILD_SHARED_LIBS variable)
        add_library(${ARG_NAME} ${ARG_SOURCES})
        add_library(${ARG_NAMESPACE}::${ARG_CLEAN_NAME} ALIAS ${ARG_NAME})
        target_include_directories(${ARG_NAME} PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:include>
        )
        target_compile_features(${ARG_NAME} PUBLIC cxx_std_${ARG_REQUIRES_CPP_VERSION})
        if(ARG_HEADERS)
            target_sources(${ARG_NAME} PUBLIC
                FILE_SET headers
                TYPE HEADERS
                BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/include
                FILES ${ARG_HEADERS}
            )
        endif()
    else()
        # Header-only INTERFACE target
        add_library(${ARG_NAME} INTERFACE)
        add_library(${ARG_NAMESPACE}::${ARG_CLEAN_NAME} ALIAS ${ARG_NAME})
        target_include_directories(${ARG_NAME} INTERFACE
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:include>
        )
        target_compile_features(${ARG_NAME} INTERFACE cxx_std_${ARG_REQUIRES_CPP_VERSION})
        if(ARG_HEADERS)
            target_sources(${ARG_NAME} INTERFACE
                FILE_SET headers
                TYPE HEADERS
                BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/include
                FILES ${ARG_HEADERS}
            )
        endif()
    endif()
    
    # Setup installation when building as top-level project
    if(ARG_TOP_LEVEL)
        _cpp_library_setup_install(
            NAME "${ARG_NAME}"
            PACKAGE_NAME "${ARG_PACKAGE_NAME}"
            VERSION "${ARG_VERSION}"
            NAMESPACE "${ARG_NAMESPACE}"
            HEADERS "${ARG_HEADERS}"
        )
    endif()

endfunction()

# Copies template files (.clang-format, .gitignore, etc.) to project root if not present.
# - Precondition: PACKAGE_NAME must be passed as first parameter
# - Postcondition: missing template files copied to project, CI workflow configured with PACKAGE_NAME substitution
# - With FORCE_INIT: overwrites existing files
function(_cpp_library_copy_templates PACKAGE_NAME)
    set(options FORCE_INIT)
    cmake_parse_arguments(ARG "${options}" "" "" ${ARGN})

    # List of static template files to copy
    set(TEMPLATE_FILES
        ".clang-format"
        ".gitignore"
        ".gitattributes"
        ".vscode/extensions.json"
        "docs/index.html"
        "CMakePresets.json"
    )

    foreach(template_file IN LISTS TEMPLATE_FILES)
        set(source_file "${CPP_LIBRARY_ROOT}/templates/${template_file}")
        set(dest_file "${CMAKE_CURRENT_SOURCE_DIR}/${template_file}")

        if(EXISTS "${source_file}" AND (NOT EXISTS "${dest_file}" OR ARG_FORCE_INIT))
            get_filename_component(dest_dir "${dest_file}" DIRECTORY)
            file(MAKE_DIRECTORY "${dest_dir}")
            file(COPY "${source_file}" DESTINATION "${dest_dir}")
            message(STATUS "Copied template file: ${template_file}")
        elseif(NOT EXISTS "${source_file}")
            message(WARNING "Template file not found: ${source_file}")
        endif()
    endforeach()
    
    # Setup CI workflow with PACKAGE_NAME substitution
    _cpp_library_setup_ci("${PACKAGE_NAME}" ${ARG_FORCE_INIT})
endfunction()
