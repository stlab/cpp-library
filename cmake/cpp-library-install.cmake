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
#
# Note: GNUInstallDirs and CMakePackageConfigHelpers are included inside
# _cpp_library_setup_install() to avoid requiring project() to be called
# when this module is loaded.

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
# - Precondition: TARGET_NAME specifies existing target with INTERFACE_LINK_LIBRARIES, dependency provider installed
# - Postcondition: OUTPUT_VAR contains newline-separated find_dependency() calls for public dependencies
# - Uses dependency tracking data from cpp_library_dependency_provider to generate accurate calls
# - Automatically includes version constraints from tracked find_package() calls
# - Common system packages (Threads, OpenMP, etc.) are handled automatically
# - Merges multiple components of the same package into a single find_dependency() call with COMPONENTS
# - cpp_library_map_dependency() can override tracked dependencies for non-namespaced targets or special cases
# - cpp-library dependencies: namespace::namespace → find_dependency(namespace VERSION), namespace::component → find_dependency(namespace-component VERSION)
# - External dependencies: name::name → find_dependency(name VERSION), name::component → find_dependency(name VERSION)
function(_cpp_library_generate_dependencies OUTPUT_VAR TARGET_NAME NAMESPACE)
    get_target_property(LINK_LIBS ${TARGET_NAME} INTERFACE_LINK_LIBRARIES)
    
    if(NOT LINK_LIBS)
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
        return()
    endif()
    
    # Process each linked library
    foreach(LIB IN LISTS LINK_LIBS)
        # Handle BUILD_INTERFACE generator expressions
        # When re-exporting dependencies from external packages, they must be wrapped in BUILD_INTERFACE
        # to avoid CMake export errors, but we still want to track them for find_dependency()
        if(LIB MATCHES "^\\$<BUILD_INTERFACE:([^>]+)>$")
            set(EXTRACTED_TARGET "${CMAKE_MATCH_1}")
            # Only process if it's a namespaced target (external dependency)
            # Non-namespaced targets in BUILD_INTERFACE are local build targets
            if(EXTRACTED_TARGET MATCHES "::")
                set(LIB "${EXTRACTED_TARGET}")
                message(DEBUG "cpp-library: Extracted ${LIB} from BUILD_INTERFACE generator expression")
            else()
                # Skip non-namespaced BUILD_INTERFACE targets (local build targets)
                message(DEBUG "cpp-library: Skipping non-namespaced BUILD_INTERFACE target: ${EXTRACTED_TARGET}")
                continue()
            endif()
        elseif(LIB MATCHES "^\\$<")
            # Skip other generator expressions (INSTALL_INTERFACE, etc.)
            continue()
        endif()
        
        set(FIND_DEP_CALL "")
        
        # Check for custom mapping first (allows overrides for non-namespaced targets)
        get_property(CUSTOM_MAPPING GLOBAL PROPERTY _CPP_LIBRARY_DEPENDENCY_MAP_${LIB})
        
        if(CUSTOM_MAPPING)
            # Use explicit custom mapping
            set(FIND_DEP_CALL "${CUSTOM_MAPPING}")
            message(DEBUG "cpp-library: Using custom mapping for ${LIB}: ${CUSTOM_MAPPING}")
        else()
            # Use tracked dependency data from provider
            _cpp_library_resolve_dependency("${LIB}" "${NAMESPACE}" FIND_DEP_CALL)
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

# Resolve dependency using tracked provider data
# - Precondition: LIB is a target name, NAMESPACE is the project namespace
# - Postcondition: OUTPUT_VAR contains find_dependency() call syntax or error is raised
function(_cpp_library_resolve_dependency LIB NAMESPACE OUTPUT_VAR)
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
        else()
            # Not tracked - check if it's a system package
            if(FIND_PACKAGE_NAME IN_LIST _CPP_LIBRARY_SYSTEM_PACKAGES)
                set(${OUTPUT_VAR} "${FIND_PACKAGE_NAME}" PARENT_SCOPE)
                message(DEBUG "cpp-library: System package ${FIND_PACKAGE_NAME} (no tracking needed)")
            else()
                # Not tracked and not a system package - check if provider is installed
                get_property(PROVIDER_INSTALLED GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED)
                if(NOT PROVIDER_INSTALLED)
                    _cpp_library_example_usage(EXAMPLE)
                    message(FATAL_ERROR 
                        "cpp-library: Dependency provider not installed.\n"
                        "You must call cpp_library_enable_dependency_tracking() before project().\n"
                        "\n"
                        "Example:\n"
                        "${EXAMPLE}\n"
                    )
                else()
                    # Provider is installed but dependency wasn't tracked
                    # Check if we're in strict install validation mode
                    get_property(IN_INSTALL_MODE GLOBAL PROPERTY _CPP_LIBRARY_IN_INSTALL_MODE)
                    
                    if(IN_INSTALL_MODE)
                        # Strict mode during install: error out
                        message(FATAL_ERROR 
                            "cpp-library: Cannot install - Dependency ${LIB} (package: ${FIND_PACKAGE_NAME}) was not tracked.\n"
                            "\n"
                            "The dependency provider is installed, but this dependency was not captured.\n"
                            "Common causes:\n"
                            "  - find_package() or CPMAddPackage() was called in a subdirectory\n"
                            "  - Dependency was added before project() (must be after)\n"
                            "\n"
                            "Solution: Ensure dependencies are declared after project() in the top-level CMakeLists.txt.\n"
                            "\n"
                            "Correct order:\n"
                            "    cpp_library_enable_dependency_tracking()\n"
                            "    project(my-library)\n"
                            "    cpp_library_setup(...)\n"
                            "    find_package(SomePackage)  # or CPMAddPackage(...)\n"
                            "    target_link_libraries(...)\n"
                        )
                    else()
                        # Lenient mode during configure: notify and use fallback
                        # Print header message before first untracked dependency
                        get_property(HEADER_PRINTED GLOBAL PROPERTY _CPP_LIBRARY_UNTRACKED_HEADER_PRINTED)
                        if(NOT HEADER_PRINTED)
                            message(STATUS "cpp-library: Untracked dependencies (see: https://github.com/stlab/cpp-library#untracked-dependencies)")
                            set_property(GLOBAL PROPERTY _CPP_LIBRARY_UNTRACKED_HEADER_PRINTED TRUE)
                        endif()
                        
                        # Print concise message about this specific dependency
                        message(STATUS "cpp-library: Dependency ${LIB} (package: ${FIND_PACKAGE_NAME}) was not tracked.")
                        
                        # Track this as an unverified dependency for install-time validation
                        set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_UNVERIFIED_DEPS 
                            "${LIB}|${FIND_PACKAGE_NAME}")
                        
                        # Use a reasonable fallback for development builds
                        set(${OUTPUT_VAR} "${FIND_PACKAGE_NAME}" PARENT_SCOPE)
                        return()
                    endif()
                endif()
            endif()
        endif()
    else()
        # Non-namespaced target - requires explicit mapping
        message(FATAL_ERROR 
            "cpp-library: Non-namespaced dependency '${LIB}' cannot be automatically resolved.\n"
            "\n"
            "Non-namespaced targets (like 'opencv_core') don't indicate which package they came from.\n"
            "You must use cpp_library_map_dependency() to map the target to its package:\n"
            "\n"
            "    cpp_library_map_dependency(\"${LIB}\" \"<PACKAGE_NAME> <VERSION>\")\n"
            "\n"
            "For example, if ${LIB} comes from OpenCV:\n"
            "    find_package(OpenCV 4.5.0 REQUIRED)\n"
            "    cpp_library_map_dependency(\"${LIB}\" \"OpenCV 4.5.0\")\n"
            "\n"
            "Add this mapping after find_package() or CPMAddPackage() in your CMakeLists.txt.\n"
        )
    endif()
endfunction()

# Helper function to parse and store a dependency for later merging
# - Parses find_dependency() arguments to extract package, version, and components
# - Stores in global properties for merging by _cpp_library_get_merged_dependencies()
function(_cpp_library_add_dependency FIND_DEP_ARGS)
    # Parse: PackageName [Version] [COMPONENTS component1 component2 ...] [other args]
    string(REGEX MATCH "^([^ ]+)" PKG_NAME "${FIND_DEP_ARGS}")
    
    # Remove package name from args - use string(REPLACE) for literal match
    string(LENGTH "${PKG_NAME}" PKG_NAME_LEN)
    string(LENGTH "${FIND_DEP_ARGS}" TOTAL_LEN)
    if(TOTAL_LEN GREATER PKG_NAME_LEN)
        math(EXPR START_POS "${PKG_NAME_LEN}")
        string(SUBSTRING "${FIND_DEP_ARGS}" ${START_POS} -1 REMAINING_ARGS)
        string(STRIP "${REMAINING_ARGS}" REMAINING_ARGS)
    else()
        set(REMAINING_ARGS "")
    endif()
    
    # Extract version (first token that looks like a semantic version number: major.minor[.patch]...)
    set(VERSION "")
    if(REMAINING_ARGS MATCHES "^([0-9]+\\.[0-9]+(\\.[0-9]+)*)")
        set(VERSION "${CMAKE_MATCH_1}")
        # Remove version from args - use substring to avoid regex issues with dots
        string(LENGTH "${VERSION}" VERSION_LEN)
        string(LENGTH "${REMAINING_ARGS}" TOTAL_LEN)
        if(TOTAL_LEN GREATER VERSION_LEN)
            math(EXPR START_POS "${VERSION_LEN}")
            string(SUBSTRING "${REMAINING_ARGS}" ${START_POS} -1 REMAINING_ARGS)
            string(STRIP "${REMAINING_ARGS}" REMAINING_ARGS)
        else()
            set(REMAINING_ARGS "")
        endif()
    endif()
    
    # Extract COMPONENTS if present
    set(COMPONENTS "")
    set(BASE_ARGS "${REMAINING_ARGS}")
    if(REMAINING_ARGS MATCHES "COMPONENTS +(.+)")
        set(COMPONENTS_PART "${CMAKE_MATCH_1}")
        # Extract just the component names (until next keyword or end)
        string(REGEX REPLACE " +(REQUIRED|OPTIONAL_COMPONENTS|CONFIG|NO_MODULE).*$" "" COMPONENTS "${COMPONENTS_PART}")
        # Remove COMPONENTS and component names from base args
        # Escape all regex special characters in COMPONENTS for safe regex use
        # Must escape: \ first (to avoid double-escaping), then all other special chars
        string(REPLACE "\\" "\\\\" COMPONENTS_ESCAPED "${COMPONENTS}")
        string(REPLACE "." "\\." COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "*" "\\*" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "+" "\\+" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "?" "\\?" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "^" "\\^" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "$" "\\$" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "|" "\\|" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "(" "\\(" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE ")" "\\)" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "[" "\\[" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "]" "\\]" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "{" "\\{" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REPLACE "}" "\\}" COMPONENTS_ESCAPED "${COMPONENTS_ESCAPED}")
        string(REGEX REPLACE "COMPONENTS +${COMPONENTS_ESCAPED}" "" BASE_ARGS "${REMAINING_ARGS}")
        string(STRIP "${COMPONENTS}" COMPONENTS)
    endif()
    string(STRIP "${BASE_ARGS}" BASE_ARGS)
    
    # Create a key for this package (package_name + version + base_args)
    # Use <|> as delimiter (unlikely to appear in package arguments)
    set(PKG_KEY "${PKG_NAME}<|>${VERSION}<|>${BASE_ARGS}")
    
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
        # Parse the key: package_name<|>version<|>base_args
        # Use <|> as delimiter (unlikely to appear in package arguments)
        string(REPLACE "<|>" ";" KEY_PARTS "${PKG_KEY}")
        list(LENGTH KEY_PARTS PARTS_COUNT)
        if(PARTS_COUNT GREATER_EQUAL 3)
            list(GET KEY_PARTS 0 PKG_NAME)
            list(GET KEY_PARTS 1 VERSION)
            # Get remaining parts in case BASE_ARGS was split (shouldn't happen with <|> delimiter)
            list(SUBLIST KEY_PARTS 2 -1 BASE_ARGS_PARTS)
            list(JOIN BASE_ARGS_PARTS "<|>" BASE_ARGS)
        else()
            message(WARNING "Invalid package key format: ${PKG_KEY}")
            continue()
        endif()
        
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

# Deferred function to generate Config.cmake after all target_link_libraries() calls
# This runs at the end of CMakeLists.txt processing via cmake_language(DEFER)
function(_cpp_library_deferred_generate_config)
    # Include required modules
    include(CMakePackageConfigHelpers)
    
    # Retrieve stored arguments from global properties
    get_property(ARG_NAME GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_NAME)
    get_property(ARG_PACKAGE_NAME GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_PACKAGE_NAME)
    get_property(ARG_VERSION GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_VERSION)
    get_property(ARG_NAMESPACE GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_NAMESPACE)
    get_property(CPP_LIBRARY_ROOT GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_ROOT)
    get_property(BINARY_DIR GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_BINARY_DIR)
    
    # Now generate find_dependency() calls with complete link information
    _cpp_library_generate_dependencies(PACKAGE_DEPENDENCIES ${ARG_NAME} ${ARG_NAMESPACE})
    
    # Generate package version file
    write_basic_package_version_file(
        "${BINARY_DIR}/${ARG_PACKAGE_NAME}ConfigVersion.cmake"
        VERSION ${ARG_VERSION}
        COMPATIBILITY SameMajorVersion
    )
    
    # Generate package config file from template
    configure_file(
        "${CPP_LIBRARY_ROOT}/templates/Config.cmake.in"
        "${BINARY_DIR}/${ARG_PACKAGE_NAME}Config.cmake"
        @ONLY
    )
    
    # Save unverified dependencies to a file for install-time validation
    get_property(UNVERIFIED_DEPS GLOBAL PROPERTY _CPP_LIBRARY_UNVERIFIED_DEPS)
    if(UNVERIFIED_DEPS)
        set(UNVERIFIED_FILE "${BINARY_DIR}/${ARG_PACKAGE_NAME}_unverified_deps.cmake")
        file(WRITE "${UNVERIFIED_FILE}" "# Unverified dependencies for ${ARG_PACKAGE_NAME}\n")
        file(APPEND "${UNVERIFIED_FILE}" "set(_UNVERIFIED_DEPS_LIST [[${UNVERIFIED_DEPS}]])\n")
        set_property(GLOBAL PROPERTY _CPP_LIBRARY_HAS_UNVERIFIED_DEPS TRUE)
    else()
        set_property(GLOBAL PROPERTY _CPP_LIBRARY_HAS_UNVERIFIED_DEPS FALSE)
    endif()
    
    message(STATUS "cpp-library: Generated ${ARG_PACKAGE_NAME}Config.cmake with dependencies")
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
    
    # Include required CMake modules (deferred from top-level to avoid requiring project() before include)
    include(GNUInstallDirs)
    include(CMakePackageConfigHelpers)
    
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
    
    # Defer Config.cmake generation until end of CMakeLists.txt processing
    # This ensures all target_link_libraries() calls have been made first
    # Store arguments in global properties for the deferred function
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_NAME "${ARG_NAME}")
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_PACKAGE_NAME "${ARG_PACKAGE_NAME}")
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_VERSION "${ARG_VERSION}")
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_NAMESPACE "${ARG_NAMESPACE}")
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_ROOT "${CPP_LIBRARY_ROOT}")
    set_property(GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    
    cmake_language(DEFER DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} 
        CALL _cpp_library_deferred_generate_config)
    
    # Defer install validation setup until after config generation
    # This ensures the unverified deps file is created first
    cmake_language(DEFER DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        CALL _cpp_library_setup_install_validation)
    
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

# Deferred function to setup install validation after config generation
# This runs after _cpp_library_deferred_generate_config() has created the unverified deps file
function(_cpp_library_setup_install_validation)
    # Retrieve stored arguments from global properties (set by _cpp_library_setup_install)
    get_property(PACKAGE_NAME GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_PACKAGE_NAME)
    get_property(BINARY_DIR GLOBAL PROPERTY _CPP_LIBRARY_DEFERRED_INSTALL_BINARY_DIR)
    
    # Check if there are unverified dependencies
    get_property(HAS_UNVERIFIED GLOBAL PROPERTY _CPP_LIBRARY_HAS_UNVERIFIED_DEPS)
    
    if(HAS_UNVERIFIED)
        set(UNVERIFIED_FILE "${BINARY_DIR}/${PACKAGE_NAME}_unverified_deps.cmake")
        
        # Add install-time validation to ensure all dependencies are properly tracked
        # This runs before config files are installed and will fail if untracked dependencies exist
        install(CODE "
            message(STATUS \"cpp-library: Validating tracked dependencies for ${PACKAGE_NAME}...\")
            
            # Load the list of unverified dependencies
            include(\"${UNVERIFIED_FILE}\")
            
            if(_UNVERIFIED_DEPS_LIST)
                # Parse the unverified dependencies list
                string(REPLACE \";\" \"\\n  - \" FORMATTED_DEPS \"\${_UNVERIFIED_DEPS_LIST}\")
                string(REGEX REPLACE \"\\\\|[^;]+\" \"\" FORMATTED_DEPS \"\${FORMATTED_DEPS}\")
                
                message(FATAL_ERROR
                    \"cpp-library: Cannot install ${PACKAGE_NAME} - untracked dependencies detected:\\n\"
                    \"  - \${FORMATTED_DEPS}\\n\"
                    \"\\n\"
                    \"These dependencies were not captured by the dependency provider.\\n\"
                    \"Common causes:\\n\"
                    \"  - find_package() or CPMAddPackage() was called in a subdirectory\\n\"
                    \"  - Dependency was added before project() (must be after)\\n\"
                    \"\\n\"
                    \"Solution: Ensure dependencies are declared after project() in the top-level CMakeLists.txt.\\n\"
                    \"Or use cpp_library_map_dependency() to manually register each dependency.\\n\"
                )
            endif()
            
            message(STATUS \"cpp-library: Dependency validation passed for ${PACKAGE_NAME}\")
        ")
    else()
        install(CODE "
            message(STATUS \"cpp-library: All dependencies properly tracked for ${PACKAGE_NAME}\")
        ")
    endif()
endfunction()
