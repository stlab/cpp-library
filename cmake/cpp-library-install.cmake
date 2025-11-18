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

# Registers a custom dependency mapping for find_dependency() generation
# - Precondition: TARGET is a namespaced target (e.g., "Qt5::Core", "Qt5::Widgets")
# - Postcondition: FIND_DEPENDENCY_CALL stored for TARGET, used in package config generation
# - Example: cpp_library_map_dependency("Qt5::Core" "Qt5 COMPONENTS Core")
function(cpp_library_map_dependency TARGET FIND_DEPENDENCY_CALL)
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEPENDENCY_MAP_${TARGET} "${FIND_DEPENDENCY_CALL}")
endfunction()

# Generates find_dependency() calls for target's INTERFACE link libraries
# - Precondition: TARGET_NAME specifies existing target with INTERFACE_LINK_LIBRARIES
# - Postcondition: OUTPUT_VAR contains newline-separated find_dependency() calls for public dependencies
# - Uses cpp_library_map_dependency() mappings if registered, otherwise uses defaults
# - Automatically handles cpp-library dependencies (namespace::package → find_dependency(package))
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
            
            # Check for custom mapping first
            get_property(CUSTOM_MAPPING GLOBAL PROPERTY _CPP_LIBRARY_DEPENDENCY_MAP_${LIB})
            
            if(CUSTOM_MAPPING)
                # Use custom mapping (e.g., "Qt5 COMPONENTS Core" for Qt5::Core)
                list(APPEND DEPENDENCY_LIST "find_dependency(${CUSTOM_MAPPING})")
            elseif(PKG_NAME STREQUAL NAMESPACE)
                # Internal cpp-library dependency: use component as package name
                # (e.g., stlab::copy-on-write → find_dependency(copy-on-write))
                list(APPEND DEPENDENCY_LIST "find_dependency(${COMPONENT})")
            else()
                # Default: use package name only (e.g., libdispatch::libdispatch → find_dependency(libdispatch))
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
