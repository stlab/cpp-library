# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-install.cmake - Installation support for cpp-library projects
#
# This module provides minimal but complete CMake installation support for libraries
# built with cpp-library. It handles:
# - Header-only libraries (INTERFACE targets)
# - Static libraries
# - Shared libraries (when BUILD_SHARED_LIBS is ON)
# - CMake package config generation for find_package() support

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Generates find_dependency() calls for target's INTERFACE link libraries
# - Precondition: TARGET_NAME specifies existing target with INTERFACE_LINK_LIBRARIES
# - Postcondition: OUTPUT_VAR contains newline-separated find_dependency() calls for public dependencies
# - Handles common patterns: namespace::target from CPM, Qt5/Qt6::Component, Threads::Threads, etc.
function(_cpp_library_generate_dependencies OUTPUT_VAR TARGET_NAME NAMESPACE)
    get_target_property(LINK_LIBS ${TARGET_NAME} INTERFACE_LINK_LIBRARIES)
    
    if(NOT LINK_LIBS)
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
        return()
    endif()
    
    set(DEPENDENCY_LIST "")
    
    foreach(LIB IN LISTS LINK_LIBS)
        # Skip generator expressions (typically BUILD_INTERFACE dependencies)
        if(LIB MATCHES "^\\$<")
            continue()
        endif()
        
        # Parse namespaced target: PackageName::Component
        if(LIB MATCHES "^([^:]+)::(.+)$")
            set(PKG_NAME "${CMAKE_MATCH_1}")
            set(COMPONENT "${CMAKE_MATCH_2}")
            
            # Determine find_dependency() call based on package pattern
            if(PKG_NAME STREQUAL NAMESPACE)
                # Internal dependency: use component as package name (e.g., stlab::copy-on-write → copy-on-write)
                list(APPEND DEPENDENCY_LIST "find_dependency(${COMPONENT})")
            elseif(PKG_NAME STREQUAL "Threads")
                list(APPEND DEPENDENCY_LIST "find_dependency(Threads)")
            elseif(PKG_NAME MATCHES "^Qt[56]$")
                # Qt with component (e.g., Qt5::Core → find_dependency(Qt5 COMPONENTS Core))
                list(APPEND DEPENDENCY_LIST "find_dependency(${PKG_NAME} COMPONENTS ${COMPONENT})")
            else()
                # Generic package (e.g., libdispatch::libdispatch → libdispatch)
                list(APPEND DEPENDENCY_LIST "find_dependency(${PKG_NAME})")
            endif()
        endif()
    endforeach()
    
    # Remove duplicates and convert to newline-separated string
    if(DEPENDENCY_LIST)
        list(REMOVE_DUPLICATES DEPENDENCY_LIST)
        list(JOIN DEPENDENCY_LIST "\n" DEPENDENCY_LINES)
    else()
        set(DEPENDENCY_LINES "")
    endif()
    
    set(${OUTPUT_VAR} "${DEPENDENCY_LINES}" PARENT_SCOPE)
endfunction()

# Configures CMake install rules for library target and package config files.
# - Precondition: NAME, PACKAGE_NAME, VERSION, and NAMESPACE specified; target NAME exists
# - Postcondition: install rules created for target, config files, and export with NAMESPACE:: prefix
# - Supports header-only (INTERFACE) and compiled libraries, uses SameMajorVersion compatibility
function(_cpp_library_setup_install)
    set(oneValueArgs
        NAME            # Target name (e.g., "stlab-enum-ops")
        PACKAGE_NAME    # Package name for find_package() (e.g., "enum-ops")
        VERSION         # Version string (e.g., "1.2.3")
        NAMESPACE       # Namespace for alias (e.g., "stlab")
    )
    set(multiValueArgs
        HEADERS     # List of header file paths (for FILE_SET support check)
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Validate required arguments
    if(NOT ARG_NAME)
        message(FATAL_ERROR "_cpp_library_setup_install: NAME is required")
    endif()
    if(NOT ARG_PACKAGE_NAME)
        message(FATAL_ERROR "_cpp_library_setup_install: PACKAGE_NAME is required")
    endif()
    if(NOT ARG_VERSION)
        message(FATAL_ERROR "_cpp_library_setup_install: VERSION is required")
    endif()
    if(NOT ARG_NAMESPACE)
        message(FATAL_ERROR "_cpp_library_setup_install: NAMESPACE is required")
    endif()
    
    # Install the library target
    # For header-only libraries (INTERFACE), this installs the target metadata
    # For compiled libraries, this installs the library files and headers
    if(ARG_HEADERS)
        # Install with FILE_SET for modern header installation
        install(TARGETS ${ARG_NAME}
            EXPORT ${ARG_NAME}Targets
            FILE_SET headers DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        )
    else()
        # Install without FILE_SET (fallback for edge cases)
        install(TARGETS ${ARG_NAME}
            EXPORT ${ARG_NAME}Targets
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        )
    endif()
    
    # Generate find_dependency() calls for package dependencies
    _cpp_library_generate_dependencies(PACKAGE_DEPENDENCIES ${ARG_NAME} ${ARG_NAMESPACE})
    
    # Generate package version file
    # Uses SameMajorVersion compatibility (e.g., 2.1.0 is compatible with 2.0.0)
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${ARG_PACKAGE_NAME}ConfigVersion.cmake"
        VERSION ${ARG_VERSION}
        COMPATIBILITY SameMajorVersion
    )
    
    # Generate package config file from template
    # PACKAGE_DEPENDENCIES will be substituted via @PACKAGE_DEPENDENCIES@
    configure_file(
        "${CPP_LIBRARY_ROOT}/templates/Config.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/${ARG_PACKAGE_NAME}Config.cmake"
        @ONLY
    )
    
    # Install export targets with namespace
    # This allows downstream projects to use find_package(package-name)
    # and link against namespace::target
    install(EXPORT ${ARG_NAME}Targets
        FILE ${ARG_PACKAGE_NAME}Targets.cmake
        NAMESPACE ${ARG_NAMESPACE}::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${ARG_PACKAGE_NAME}
    )
    
    # Install package config and version files
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${ARG_PACKAGE_NAME}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${ARG_PACKAGE_NAME}ConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${ARG_PACKAGE_NAME}
    )
    
endfunction()
