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

# Only install the provider once, and only if we're using CMake 3.24+
if(CMAKE_VERSION VERSION_LESS "3.24")
    message(WARNING 
        "cpp-library dependency tracking requires CMake 3.24+, current version is ${CMAKE_VERSION}.\n"
        "Dependency tracking will be disabled. Install will use fallback introspection method.")
    return()
endif()

# Check if provider is already installed (avoid double-installation)
get_property(_CPP_LIBRARY_PROVIDER_INSTALLED GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED)
if(_CPP_LIBRARY_PROVIDER_INSTALLED)
    return()
endif()
set_property(GLOBAL PROPERTY _CPP_LIBRARY_PROVIDER_INSTALLED TRUE)

# Install the dependency provider
cmake_language(SET_DEPENDENCY_PROVIDER _cpp_library_dependency_provider
    SUPPORTED_METHODS 
        FIND_PACKAGE
        FETCHCONTENT_MAKEAVAILABLE_SERIAL
)

message(STATUS "cpp-library: Dependency tracking enabled")

# The dependency provider implementation
# This function is called before every find_package() and FetchContent_MakeAvailable()
function(_cpp_library_dependency_provider method)
    if(method STREQUAL "FIND_PACKAGE")
        _cpp_library_track_find_package(${ARGN})
    elseif(method STREQUAL "FETCHCONTENT_MAKEAVAILABLE_SERIAL")
        _cpp_library_track_fetchcontent(${ARGN})
    endif()
    
    # CRITICAL: Delegate to the default implementation
    # This actually performs the find_package or FetchContent operation
    cmake_language(CALL ${method} ${ARGN})
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
    set(VERSION "")
    foreach(arg IN LISTS FP_UNPARSED_ARGUMENTS)
        if(arg MATCHES "^[0-9]+\\.[0-9]")
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

