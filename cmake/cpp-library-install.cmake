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

# System packages that don't require version constraints in find_dependency()
# These are commonly available system libraries where version requirements are typically not specified.
# To extend this list in your project, use cpp_library_map_dependency() to explicitly map additional packages.
set(_CPP_LIBRARY_SYSTEM_PACKAGES "Threads" "OpenMP" "ZLIB" "CURL" "OpenSSL")

# Registers a custom dependency mapping for find_dependency() generation
# - Precondition: TARGET is a namespaced target (e.g., "Qt6::Core", "stlab::enum-ops") or non-namespaced (e.g., "opencv_core")
# - Postcondition: FIND_DEPENDENCY_CALL stored for TARGET, used in package config generation
# - FIND_DEPENDENCY_CALL should be the complete arguments to find_dependency(), including version if needed
# - Multiple components of the same package (same name+version+args) are automatically merged into one call
# - Examples:
#   - cpp_library_map_dependency("Qt6::Core" "Qt6 6.5.0 COMPONENTS Core")
#   - cpp_library_map_dependency("Qt6::Widgets" "Qt6 6.5.0 COMPONENTS Widgets")
#     → Generates: find_dependency(Qt6 6.5.0 COMPONENTS Core Widgets)
#   - cpp_library_map_dependency("stlab::enum-ops" "stlab-enum-ops 1.0.0")
#   - cpp_library_map_dependency("opencv_core" "OpenCV 4.5.0")
# - Note: Most namespaced dependencies work automatically; only use when automatic detection fails or special syntax needed
function(cpp_library_map_dependency TARGET FIND_DEPENDENCY_CALL)
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEPENDENCY_MAP_${TARGET} "${FIND_DEPENDENCY_CALL}")
    # Track all mapped targets for cleanup in tests
    set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_MAPPED_TARGETS "${TARGET}")
endfunction()

# Generates find_dependency() calls for target's INTERFACE link libraries
# - Precondition: TARGET_NAME specifies existing target with INTERFACE_LINK_LIBRARIES
# - Postcondition: OUTPUT_VAR contains newline-separated find_dependency() calls for public dependencies
# - Primary method: Uses dependency tracking data from cpp_library_dependency_provider (CMake 3.24+)
# - Fallback method: Uses cpp_library_map_dependency() mappings and <PackageName>_VERSION introspection
# - Automatically includes version constraints from tracked find_package() calls when available
# - Common system packages (Threads, OpenMP, etc.) are exempt from version requirements
# - Merges multiple components of the same package into a single find_dependency() call with COMPONENTS
# - cpp-library dependencies: namespace::namespace → find_dependency(namespace VERSION), namespace::component → find_dependency(namespace-component VERSION)
# - External dependencies: name::name → find_dependency(name VERSION), name::component → find_dependency(name VERSION)
function(_cpp_library_generate_dependencies OUTPUT_VAR TARGET_NAME NAMESPACE)
    get_target_property(LINK_LIBS ${TARGET_NAME} INTERFACE_LINK_LIBRARIES)
    
    if(NOT LINK_LIBS)
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
        return()
    endif()
    
    # Check if dependency provider tracking is available
    get_property(PROVIDER_INSTALLED GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED)
    
    # Process each linked library
    foreach(LIB IN LISTS LINK_LIBS)
        # Skip generator expressions (typically BUILD_INTERFACE dependencies)
        if(LIB MATCHES "^\\$<")
            continue()
        endif()
        
        set(FIND_DEP_CALL "")
        
        # Check for custom mapping first (always respected, even with provider)
        get_property(CUSTOM_MAPPING GLOBAL PROPERTY _CPP_LIBRARY_DEPENDENCY_MAP_${LIB})
        
        if(CUSTOM_MAPPING)
            # Use explicit custom mapping
            set(FIND_DEP_CALL "${CUSTOM_MAPPING}")
            message(DEBUG "cpp-library: Using custom mapping for ${LIB}: ${CUSTOM_MAPPING}")
        elseif(PROVIDER_INSTALLED)
            # Try to use tracked dependency data from provider
            set(FIND_DEP_CALL "")
            _cpp_library_resolve_with_provider("${LIB}" "${NAMESPACE}" FIND_DEP_CALL)
        else()
            # Fallback to introspection method (old behavior)
            _cpp_library_resolve_with_introspection("${LIB}" "${NAMESPACE}" FIND_DEP_CALL)
        endif()
        
        # Add the dependency to the merged list
        if(FIND_DEP_CALL)
            _cpp_library_add_dependency("${FIND_DEP_CALL}")
        endif()
    endforeach()
    
    # Generate merged find_dependency() calls
    _cpp_library_get_merged_dependencies(DEPENDENCY_LINES)
    
    set(${OUTPUT_VAR} "${DEPENDENCY_LINES}" PARENT_SCOPE)
endfunction()

# Resolve dependency using tracked provider data (CMake 3.24+ with dependency provider)
# - Precondition: PROVIDER_INSTALLED is true, LIB is a target name, NAMESPACE is the project namespace
# - Postcondition: OUTPUT_VAR contains find_dependency() call syntax or empty if not found
function(_cpp_library_resolve_with_provider LIB NAMESPACE OUTPUT_VAR)
    # Parse the target name to extract package name
    if(LIB MATCHES "^([^:]+)::(.+)$")
        set(PKG_NAME "${CMAKE_MATCH_1}")
        set(COMPONENT "${CMAKE_MATCH_2}")
        
        # Determine the package name for lookup
        if(PKG_NAME STREQUAL NAMESPACE)
            # Internal cpp-library dependency
            if(PKG_NAME STREQUAL COMPONENT)
                set(FIND_PACKAGE_NAME "${PKG_NAME}")
            else()
                set(FIND_PACKAGE_NAME "${PKG_NAME}-${COMPONENT}")
            endif()
        else()
            # External dependency - use package name
            set(FIND_PACKAGE_NAME "${PKG_NAME}")
        endif()
        
        # Look up tracked dependency data
        get_property(TRACKED_CALL GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_${FIND_PACKAGE_NAME}")
        
        if(TRACKED_CALL)
            # Found tracked data - use it directly
            set(${OUTPUT_VAR} "${TRACKED_CALL}" PARENT_SCOPE)
            message(DEBUG "cpp-library: Using tracked dependency for ${LIB}: ${TRACKED_CALL}")
            return()
        else()
            # Not tracked - check if it's a system package
            if(FIND_PACKAGE_NAME IN_LIST _CPP_LIBRARY_SYSTEM_PACKAGES)
                set(${OUTPUT_VAR} "${FIND_PACKAGE_NAME}" PARENT_SCOPE)
                message(DEBUG "cpp-library: System package ${FIND_PACKAGE_NAME} (no tracking needed)")
                return()
            else()
                # Not tracked and not a system package - warn and fall back to introspection
                message(WARNING 
                    "cpp-library: Dependency ${LIB} (package: ${FIND_PACKAGE_NAME}) was not tracked by the dependency provider.\n"
                    "This may happen if the dependency was added after cpp_library_setup() or in a subdirectory.\n"
                    "Falling back to introspection method.")
                _cpp_library_resolve_with_introspection("${LIB}" "${NAMESPACE}" RESULT)
                set(${OUTPUT_VAR} "${RESULT}" PARENT_SCOPE)
                return()
            endif()
        endif()
    else()
        # Non-namespaced target - cannot use provider data
        message(WARNING 
            "cpp-library: Non-namespaced dependency ${LIB} cannot be resolved with provider.\n"
            "Falling back to introspection method.")
        _cpp_library_resolve_with_introspection("${LIB}" "${NAMESPACE}" RESULT)
        set(${OUTPUT_VAR} "${RESULT}" PARENT_SCOPE)
        return()
    endif()
endfunction()

# Resolve dependency using introspection (fallback for CMake < 3.24 or when provider not used)
# - Precondition: LIB is a target name, NAMESPACE is the project namespace
# - Postcondition: OUTPUT_VAR contains find_dependency() call syntax or empty if resolution fails
function(_cpp_library_resolve_with_introspection LIB NAMESPACE OUTPUT_VAR)
    # Parse as namespaced target
    if(LIB MATCHES "^([^:]+)::(.+)$")
        set(PKG_NAME "${CMAKE_MATCH_1}")
        set(COMPONENT "${CMAKE_MATCH_2}")
        
        # Determine package name
        if(PKG_NAME STREQUAL NAMESPACE)
            # Internal cpp-library dependency
            if(PKG_NAME STREQUAL COMPONENT)
                set(FIND_PACKAGE_NAME "${PKG_NAME}")
            else()
                set(FIND_PACKAGE_NAME "${PKG_NAME}-${COMPONENT}")
            endif()
        else()
            # External dependency
            set(FIND_PACKAGE_NAME "${PKG_NAME}")
        endif()
        
        # Check if system package
        if(FIND_PACKAGE_NAME IN_LIST _CPP_LIBRARY_SYSTEM_PACKAGES)
            set(${OUTPUT_VAR} "${FIND_PACKAGE_NAME}" PARENT_SCOPE)
            return()
        endif()
        
        # Try to look up <PackageName>_VERSION
        string(REPLACE "-" "_" VERSION_VAR_NAME "${FIND_PACKAGE_NAME}")
        
        if(DEFINED ${VERSION_VAR_NAME}_VERSION AND NOT "${${VERSION_VAR_NAME}_VERSION}" STREQUAL "")
            set(${OUTPUT_VAR} "${FIND_PACKAGE_NAME} ${${VERSION_VAR_NAME}_VERSION}" PARENT_SCOPE)
            return()
        else()
            # Version not found - generate error
            message(FATAL_ERROR 
                "Cannot determine version for dependency ${LIB} (package: ${FIND_PACKAGE_NAME}).\n"
                "The version variable ${VERSION_VAR_NAME}_VERSION is not set.\n"
                "\n"
                "Solution 1 (recommended): Use cpp_library_enable_dependency_tracking() with CMake 3.24+\n"
                "    cmake_minimum_required(VERSION 3.24)\n"
                "    include(cmake/CPM.cmake)\n"
                "    CPMAddPackage(\"gh:stlab/cpp-library@5.0.0\")\n"
                "    include(\${cpp-library_SOURCE_DIR}/cpp-library.cmake)\n"
                "    cpp_library_enable_dependency_tracking()\n"
                "    project(${CMAKE_PROJECT_NAME})\n"
                "\n"
                "Solution 2: Add explicit mapping:\n"
                "    cpp_library_map_dependency(\"${LIB}\" \"${FIND_PACKAGE_NAME} <VERSION>\")\n"
                "\n"
                "Replace <VERSION> with the actual version requirement.\n"
            )
        endif()
    else()
        # Non-namespaced target - requires explicit mapping
        message(FATAL_ERROR 
            "Cannot automatically handle non-namespaced dependency: ${LIB}\n"
            "\n"
            "Add a cpp_library_map_dependency() call before cpp_library_setup():\n"
            "    cpp_library_map_dependency(\"${LIB}\" \"<PACKAGE_NAME> <VERSION>\")\n"
            "\n"
            "For example, for opencv_core:\n"
            "    cpp_library_map_dependency(\"opencv_core\" \"OpenCV 4.5.0\")\n"
        )
    endif()
endfunction()

# Helper function to parse and store a dependency for later merging
# - Parses find_dependency() arguments to extract package, version, and components
# - Stores in global properties for merging by _cpp_library_get_merged_dependencies()
function(_cpp_library_add_dependency FIND_DEP_ARGS)
    # Parse: PackageName [Version] [COMPONENTS component1 component2 ...] [other args]
    string(REGEX MATCH "^([^ ]+)" PKG_NAME "${FIND_DEP_ARGS}")
    string(REGEX REPLACE "^${PKG_NAME} ?" "" REMAINING_ARGS "${FIND_DEP_ARGS}")
    
    # Extract version (first token that looks like a version number)
    set(VERSION "")
    if(REMAINING_ARGS MATCHES "^([0-9][0-9.]*)")
        set(VERSION "${CMAKE_MATCH_1}")
        string(REGEX REPLACE "^${VERSION} ?" "" REMAINING_ARGS "${REMAINING_ARGS}")
    endif()
    
    # Extract COMPONENTS if present
    set(COMPONENTS "")
    set(BASE_ARGS "${REMAINING_ARGS}")
    if(REMAINING_ARGS MATCHES "COMPONENTS +(.+)")
        set(COMPONENTS_PART "${CMAKE_MATCH_1}")
        # Extract just the component names (until next keyword or end)
        string(REGEX REPLACE " +(REQUIRED|OPTIONAL_COMPONENTS|CONFIG|NO_MODULE).*$" "" COMPONENTS "${COMPONENTS_PART}")
        # Remove COMPONENTS and component names from base args
        string(REGEX REPLACE "COMPONENTS +${COMPONENTS}" "" BASE_ARGS "${REMAINING_ARGS}")
        string(STRIP "${COMPONENTS}" COMPONENTS)
    endif()
    string(STRIP "${BASE_ARGS}" BASE_ARGS)
    
    # Create a key for this package (package_name + version + base_args)
    set(PKG_KEY "${PKG_NAME}|${VERSION}|${BASE_ARGS}")
    
    # Get or initialize the global list of package keys
    get_property(PKG_KEYS GLOBAL PROPERTY _CPP_LIBRARY_PKG_KEYS)
    if(NOT PKG_KEY IN_LIST PKG_KEYS)
        set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_PKG_KEYS "${PKG_KEY}")
    endif()
    
    # Append components to this package key
    if(COMPONENTS)
        get_property(EXISTING_COMPONENTS GLOBAL PROPERTY "_CPP_LIBRARY_PKG_COMPONENTS_${PKG_KEY}")
        if(EXISTING_COMPONENTS)
            set_property(GLOBAL PROPERTY "_CPP_LIBRARY_PKG_COMPONENTS_${PKG_KEY}" "${EXISTING_COMPONENTS} ${COMPONENTS}")
        else()
            set_property(GLOBAL PROPERTY "_CPP_LIBRARY_PKG_COMPONENTS_${PKG_KEY}" "${COMPONENTS}")
        endif()
    endif()
endfunction()

# Helper function to generate merged find_dependency() calls
# - Reads stored dependency info and merges components for the same package
# - Returns newline-separated find_dependency() calls
function(_cpp_library_get_merged_dependencies OUTPUT_VAR)
    get_property(PKG_KEYS GLOBAL PROPERTY _CPP_LIBRARY_PKG_KEYS)
    
    set(RESULT "")
    foreach(PKG_KEY IN LISTS PKG_KEYS)
        # Parse the key: package_name|version|base_args
        string(REPLACE "|" ";" KEY_PARTS "${PKG_KEY}")
        list(GET KEY_PARTS 0 PKG_NAME)
        list(GET KEY_PARTS 1 VERSION)
        list(GET KEY_PARTS 2 BASE_ARGS)
        
        # Build the find_dependency() call
        set(FIND_CALL "${PKG_NAME}")
        
        if(VERSION)
            string(APPEND FIND_CALL " ${VERSION}")
        endif()
        
        # Add components if any
        get_property(COMPONENTS GLOBAL PROPERTY "_CPP_LIBRARY_PKG_COMPONENTS_${PKG_KEY}")
        if(COMPONENTS)
            # Remove duplicates from components list
            string(REPLACE " " ";" COMP_LIST "${COMPONENTS}")
            list(REMOVE_DUPLICATES COMP_LIST)
            list(JOIN COMP_LIST " " UNIQUE_COMPONENTS)
            string(APPEND FIND_CALL " COMPONENTS ${UNIQUE_COMPONENTS}")
        endif()
        
        if(BASE_ARGS)
            string(APPEND FIND_CALL " ${BASE_ARGS}")
        endif()
        
        list(APPEND RESULT "find_dependency(${FIND_CALL})")
        
        # Clean up this key's component list
        set_property(GLOBAL PROPERTY "_CPP_LIBRARY_PKG_COMPONENTS_${PKG_KEY}")
    endforeach()
    
    # Clean up the keys list
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_PKG_KEYS "")
    
    if(RESULT)
        list(JOIN RESULT "\n" RESULT_STR)
    else()
        set(RESULT_STR "")
    endif()
    
    set(${OUTPUT_VAR} "${RESULT_STR}" PARENT_SCOPE)
endfunction()

# Configures CMake install rules for library target and package config files.
# - Precondition: NAME, PACKAGE_NAME, VERSION, and NAMESPACE specified; target NAME exists
# - Postcondition: install rules created for target, config files, and export with NAMESPACE:: prefix
# - Supports header-only (INTERFACE) and compiled libraries, uses SameMajorVersion compatibility
function(_cpp_library_setup_install)
    set(oneValueArgs
        NAME            # Target name (e.g., "stlab-enum-ops")
        PACKAGE_NAME    # Package name for find_package() (e.g., "stlab-enum-ops")
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
