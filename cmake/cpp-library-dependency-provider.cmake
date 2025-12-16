# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-dependency-provider.cmake - Dependency tracking via CMake dependency provider
#
# This file is meant to be included via CMAKE_PROJECT_TOP_LEVEL_INCLUDES during the first
# project() call. It installs a dependency provider that tracks all find_package() and
# FetchContent calls, recording the exact syntax used so that accurate find_dependency()
# calls can be generated during installation.
#
# Usage:
#   cmake_minimum_required(VERSION 3.24)
#   include(cmake/CPM.cmake)
#   CPMAddPackage("gh:stlab/cpp-library@5.0.0")
#   
#   # Enable dependency tracking
#   list(APPEND CMAKE_PROJECT_TOP_LEVEL_INCLUDES 
#       "${cpp-library_SOURCE_DIR}/cmake/cpp-library-dependency-provider.cmake")
#   
#   project(my-library)  # Provider is installed here
#   
#   # All subsequent dependency requests are tracked
#   CPMAddPackage("gh:stlab/stlab-enum-ops@1.0.0")
#   find_package(Boost 1.79 COMPONENTS filesystem)

# Require CMake 3.24+ for dependency provider support
if(CMAKE_VERSION VERSION_LESS "3.24")
    message(FATAL_ERROR 
        "cpp-library requires CMake 3.24+ for dependency tracking.\n"
        "Current version is ${CMAKE_VERSION}.\n"
        "Please upgrade CMake or use an older version of cpp-library.")
endif()

# Check if provider is already installed (avoid double-installation)
get_property(_CPP_LIBRARY_PROVIDER_INSTALLED GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED)
if(_CPP_LIBRARY_PROVIDER_INSTALLED)
    return()
endif()

# Define all functions BEFORE installing the provider
# The dependency provider implementation
# This function is called before every find_package() and FetchContent_MakeAvailable()
# It tracks dependency information; CMake automatically falls back to default behavior after return
function(_cpp_library_dependency_provider method)
    if(method STREQUAL "FIND_PACKAGE")
        _cpp_library_track_find_package(${ARGN})
    elseif(method STREQUAL "FETCHCONTENT_MAKEAVAILABLE_SERIAL")
        _cpp_library_track_fetchcontent(${ARGN})
    endif()
    
    # Return without satisfying the dependency - CMake automatically falls back to default behavior
    # (find_package() or FetchContent_MakeAvailable() will proceed normally)
endfunction()

# Track a find_package() call
# Records: package name, version, components, and full call syntax
function(_cpp_library_track_find_package package_name)
    # Parse find_package arguments
    set(options QUIET REQUIRED NO_MODULE CONFIG)
    set(oneValueArgs)
    set(multiValueArgs COMPONENTS OPTIONAL_COMPONENTS)
    
    cmake_parse_arguments(FP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Extract version if present (first unparsed argument that looks like a version)
    # Pattern requires at least major.minor format (e.g., "1.2", "1.23", "1.2.3")
    set(VERSION "")
    foreach(arg IN LISTS FP_UNPARSED_ARGUMENTS)
        if(arg MATCHES "^[0-9]+\\.[0-9]+")
            set(VERSION "${arg}")
            break()
        endif()
    endforeach()
    
    # Build the canonical find_dependency() call syntax
    set(FIND_DEP_CALL "${package_name}")
    
    if(VERSION)
        string(APPEND FIND_DEP_CALL " ${VERSION}")
    endif()
    
    # Add components if present
    if(FP_COMPONENTS)
        list(JOIN FP_COMPONENTS " " COMPONENTS_STR)
        string(APPEND FIND_DEP_CALL " COMPONENTS ${COMPONENTS_STR}")
    endif()
    
    if(FP_OPTIONAL_COMPONENTS)
        list(JOIN FP_OPTIONAL_COMPONENTS " " OPT_COMPONENTS_STR)
        string(APPEND FIND_DEP_CALL " OPTIONAL_COMPONENTS ${OPT_COMPONENTS_STR}")
    endif()
    
    # Add other flags
    if(FP_CONFIG OR FP_NO_MODULE)
        string(APPEND FIND_DEP_CALL " CONFIG")
    endif()
    
    # Check if this package was already tracked and merge components if needed
    get_property(EXISTING_CALL GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_${package_name}")
    if(EXISTING_CALL)
        # Parse existing components (match until ) or OPTIONAL_COMPONENTS)
        set(EXISTING_COMPONENTS "")
        if(EXISTING_CALL MATCHES "COMPONENTS +([^ )]+( +[^ )]+)*)")
            set(TEMP_MATCH "${CMAKE_MATCH_1}")
            # If OPTIONAL_COMPONENTS is present, only take everything before it
            if(TEMP_MATCH MATCHES "^(.+) +OPTIONAL_COMPONENTS")
                set(TEMP_MATCH "${CMAKE_MATCH_1}")
            endif()
            # Strip keywords (CONFIG, NO_MODULE, REQUIRED) that aren't component names
            string(REGEX REPLACE " +(REQUIRED|CONFIG|NO_MODULE).*$" "" TEMP_MATCH "${TEMP_MATCH}")
            string(REGEX REPLACE " +" ";" EXISTING_COMPONENTS "${TEMP_MATCH}")
        endif()
        
        # Merge new components with existing ones (deduplicate)
        set(MERGED_COMPONENTS ${EXISTING_COMPONENTS})
        foreach(comp IN LISTS FP_COMPONENTS)
            if(NOT comp IN_LIST MERGED_COMPONENTS)
                list(APPEND MERGED_COMPONENTS "${comp}")
            endif()
        endforeach()
        
        # Rebuild FIND_DEP_CALL with merged components if we have any
        if(MERGED_COMPONENTS)
            # Extract base call (package name, version, and flags without components)
            string(REGEX REPLACE " COMPONENTS.*$" "" BASE_CALL "${EXISTING_CALL}")
            string(REGEX REPLACE " OPTIONAL_COMPONENTS.*$" "" BASE_CALL "${BASE_CALL}")
            
            set(FIND_DEP_CALL "${BASE_CALL}")
            list(JOIN MERGED_COMPONENTS " " MERGED_COMPONENTS_STR)
            string(APPEND FIND_DEP_CALL " COMPONENTS ${MERGED_COMPONENTS_STR}")
            
            message(DEBUG "cpp-library: Merged find_package(${package_name}) components: ${MERGED_COMPONENTS_STR}")
        endif()
        
        # Preserve OPTIONAL_COMPONENTS if present in either old or new
        # This must be done outside the MERGED_COMPONENTS block to handle cases
        # where there are no regular COMPONENTS but OPTIONAL_COMPONENTS exist
        set(OPT_COMPONENTS ${FP_OPTIONAL_COMPONENTS})
        if(EXISTING_CALL MATCHES "OPTIONAL_COMPONENTS +([^ ]+( +[^ ]+)*)")
            string(REGEX REPLACE " +" ";" EXISTING_OPT "${CMAKE_MATCH_1}")
            foreach(comp IN LISTS EXISTING_OPT)
                if(NOT comp IN_LIST OPT_COMPONENTS)
                    list(APPEND OPT_COMPONENTS "${comp}")
                endif()
            endforeach()
        endif()
        if(OPT_COMPONENTS)
            # Remove existing OPTIONAL_COMPONENTS to avoid duplication
            string(REGEX REPLACE " OPTIONAL_COMPONENTS.*$" "" FIND_DEP_CALL "${FIND_DEP_CALL}")
            list(JOIN OPT_COMPONENTS " " OPT_COMPONENTS_STR)
            string(APPEND FIND_DEP_CALL " OPTIONAL_COMPONENTS ${OPT_COMPONENTS_STR}")
        endif()
        
        # Preserve CONFIG flag if present in either old or new call
        # This must be done outside the MERGED_COMPONENTS block to handle cases
        # where neither call has COMPONENTS but one has CONFIG
        if(EXISTING_CALL MATCHES "CONFIG" OR FP_CONFIG OR FP_NO_MODULE)
            if(NOT FIND_DEP_CALL MATCHES "CONFIG")
                string(APPEND FIND_DEP_CALL " CONFIG")
            endif()
        endif()
    endif()
    
    # Store the dependency information globally
    # Key: package_name, Value: find_dependency() call syntax
    set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_${package_name}" "${FIND_DEP_CALL}")
    
    # Also maintain a list of all tracked packages for iteration
    get_property(ALL_DEPS GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS)
    if(NOT package_name IN_LIST ALL_DEPS)
        set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "${package_name}")
    endif()
    
    message(DEBUG "cpp-library: Tracked find_package(${package_name}) → find_dependency(${FIND_DEP_CALL})")
endfunction()

# Track a FetchContent_MakeAvailable() call
# This is more complex because we need to extract info from prior FetchContent_Declare() calls
function(_cpp_library_track_fetchcontent)
    # FetchContent_MakeAvailable can take multiple package names
    foreach(package_name IN LISTS ARGN)
        # Try to extract useful information from FetchContent variables
        # FetchContent stores info in variables like FETCHCONTENT_SOURCE_DIR_<name>
        # However, for CPM, we need different handling
        
        # Check if this looks like a CPM-added package
        # CPM sets <package>_SOURCE_DIR and <package>_VERSION
        string(TOLOWER "${package_name}" package_lower)
        string(TOUPPER "${package_name}" package_upper)
        string(REPLACE "-" "_" package_var "${package_lower}")
        
        # Try to get version from various places
        set(VERSION "")
        if(DEFINED ${package_name}_VERSION AND NOT "${${package_name}_VERSION}" STREQUAL "")
            set(VERSION "${${package_name}_VERSION}")
        elseif(DEFINED ${package_var}_VERSION AND NOT "${${package_var}_VERSION}" STREQUAL "")
            set(VERSION "${${package_var}_VERSION}")
        elseif(DEFINED ${package_upper}_VERSION AND NOT "${${package_upper}_VERSION}" STREQUAL "")
            set(VERSION "${${package_upper}_VERSION}")
        endif()
        
        # Build find_dependency() call
        set(FIND_DEP_CALL "${package_name}")
        if(VERSION)
            string(APPEND FIND_DEP_CALL " ${VERSION}")
        endif()
        
        # Store the dependency
        set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_${package_name}" "${FIND_DEP_CALL}")
        
        get_property(ALL_DEPS GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS)
        if(NOT package_name IN_LIST ALL_DEPS)
            set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "${package_name}")
        endif()
        
        message(DEBUG "cpp-library: Tracked FetchContent(${package_name}) → find_dependency(${FIND_DEP_CALL})")
    endforeach()
endfunction()

# Helper function to retrieve tracked dependency information for a specific package
# Used by the install module to look up the correct find_dependency() syntax
function(_cpp_library_get_tracked_dependency OUTPUT_VAR package_name)
    get_property(FIND_DEP_CALL GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_${package_name}")
    set(${OUTPUT_VAR} "${FIND_DEP_CALL}" PARENT_SCOPE)
endfunction()

# Helper function to get all tracked dependencies
# Returns a list of package names that have been tracked
function(_cpp_library_get_all_tracked_deps OUTPUT_VAR)
    get_property(ALL_DEPS GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS)
    set(${OUTPUT_VAR} "${ALL_DEPS}" PARENT_SCOPE)
endfunction()

# Now install the dependency provider (after all functions are defined)
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)

cmake_language(SET_DEPENDENCY_PROVIDER _cpp_library_dependency_provider
    SUPPORTED_METHODS 
        FIND_PACKAGE
        FETCHCONTENT_MAKEAVAILABLE_SERIAL
)

message(STATUS "cpp-library: Dependency tracking enabled")

