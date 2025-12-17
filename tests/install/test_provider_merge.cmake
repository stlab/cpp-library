# SPDX-License-Identifier: BSL-1.0
#
# Integration test for dependency provider component merging
# This test copies the tracking function to test it in isolation

cmake_minimum_required(VERSION 3.20)

# Copy of _cpp_library_track_find_package for testing
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
    set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_${package_name}" "${FIND_DEP_CALL}")
    
    # Also maintain a list of all tracked packages for iteration
    get_property(ALL_DEPS GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS)
    if(NOT package_name IN_LIST ALL_DEPS)
        set_property(GLOBAL APPEND PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "${package_name}")
    endif()
endfunction()

message(STATUS "===========================================")
message(STATUS "Provider Component Merging Integration Test")
message(STATUS "===========================================")

# Test: Multiple find_package calls with same package, different components
message(STATUS "Test: Calling find_package(Qt6 COMPONENTS Core) then find_package(Qt6 COMPONENTS Widgets)")

# Clear any existing state
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "")

# First call: find_package(Qt6 6.5.0 COMPONENTS Core)
_cpp_library_track_find_package("Qt6" "6.5.0" "COMPONENTS" "Core")

# Check what was stored
get_property(FIRST_CALL GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6")
message(STATUS "After first call:  ${FIRST_CALL}")

# Second call: find_package(Qt6 6.5.0 COMPONENTS Widgets)
_cpp_library_track_find_package("Qt6" "6.5.0" "COMPONENTS" "Widgets")

# Check what was stored after merge
get_property(MERGED_CALL GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6")
message(STATUS "After second call: ${MERGED_CALL}")

# Verify the result
set(EXPECTED "Qt6 6.5.0 COMPONENTS Core Widgets")
if("${MERGED_CALL}" STREQUAL "${EXPECTED}")
    message(STATUS "✓ PASS: Components correctly merged")
else()
    message(FATAL_ERROR "✗ FAIL: Expected '${EXPECTED}' but got '${MERGED_CALL}'")
endif()

# Test: Third call adds another component
message(STATUS "")
message(STATUS "Test: Adding Network component with third call")
_cpp_library_track_find_package("Qt6" "6.5.0" "COMPONENTS" "Network")

get_property(TRIPLE_CALL GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6")
message(STATUS "After third call:  ${TRIPLE_CALL}")

set(EXPECTED3 "Qt6 6.5.0 COMPONENTS Core Widgets Network")
if("${TRIPLE_CALL}" STREQUAL "${EXPECTED3}")
    message(STATUS "✓ PASS: Third component correctly merged")
else()
    message(FATAL_ERROR "✗ FAIL: Expected '${EXPECTED3}' but got '${TRIPLE_CALL}'")
endif()

# Test: Duplicate component should not be added twice
message(STATUS "")
message(STATUS "Test: Calling again with Core component (should not duplicate)")
_cpp_library_track_find_package("Qt6" "6.5.0" "COMPONENTS" "Core")

get_property(DEDUP_CALL GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6")
message(STATUS "After duplicate:   ${DEDUP_CALL}")

# Should still be the same (Core not duplicated)
if("${DEDUP_CALL}" STREQUAL "${EXPECTED3}")
    message(STATUS "✓ PASS: Duplicate component not added")
else()
    message(FATAL_ERROR "✗ FAIL: Expected '${EXPECTED3}' but got '${DEDUP_CALL}'")
endif()

# Test: CONFIG flag preserved when neither call has COMPONENTS
message(STATUS "")
message(STATUS "Test: CONFIG preserved when neither call has COMPONENTS")

# Clear state
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_MyPackage")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "")

# First call: find_package(MyPackage 1.0 CONFIG)
_cpp_library_track_find_package("MyPackage" "1.0" "CONFIG")

get_property(CONFIG_FIRST GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_MyPackage")
message(STATUS "After first call:  ${CONFIG_FIRST}")

# Verify CONFIG was stored
set(EXPECTED_CONFIG1 "MyPackage 1.0 CONFIG")
if(NOT "${CONFIG_FIRST}" STREQUAL "${EXPECTED_CONFIG1}")
    message(FATAL_ERROR "✗ FAIL: Expected '${EXPECTED_CONFIG1}' but got '${CONFIG_FIRST}'")
endif()

# Second call: find_package(MyPackage 1.0) - no CONFIG flag
_cpp_library_track_find_package("MyPackage" "1.0")

get_property(CONFIG_MERGED GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_MyPackage")
message(STATUS "After second call: ${CONFIG_MERGED}")

# Verify CONFIG was preserved (this was the bug - it would be lost)
set(EXPECTED_CONFIG2 "MyPackage 1.0 CONFIG")
if("${CONFIG_MERGED}" STREQUAL "${EXPECTED_CONFIG2}")
    message(STATUS "✓ PASS: CONFIG flag preserved without components")
else()
    message(FATAL_ERROR "✗ FAIL: Expected '${EXPECTED_CONFIG2}' but got '${CONFIG_MERGED}'")
endif()

# Test: CONFIG keyword in component list bug fix
message(STATUS "")
message(STATUS "Test: CONFIG not treated as component when merging")

# Clear state
set_property(GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6")
set_property(GLOBAL PROPERTY _CPP_LIBRARY_ALL_TRACKED_DEPS "")

# First call: find_package(Qt6 6.5.0 COMPONENTS Core CONFIG)
_cpp_library_track_find_package("Qt6" "6.5.0" "COMPONENTS" "Core" "CONFIG")

get_property(FIRST_CONFIG GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6")
message(STATUS "After first call:  ${FIRST_CONFIG}")

# Verify initial state
set(EXPECTED_FIRST "Qt6 6.5.0 COMPONENTS Core CONFIG")
if(NOT "${FIRST_CONFIG}" STREQUAL "${EXPECTED_FIRST}")
    message(FATAL_ERROR "✗ FAIL: Expected '${EXPECTED_FIRST}' but got '${FIRST_CONFIG}'")
endif()

# Second call: find_package(Qt6 6.5.0 COMPONENTS Widgets CONFIG)
# This should merge components but NOT treat CONFIG as a component
_cpp_library_track_find_package("Qt6" "6.5.0" "COMPONENTS" "Widgets" "CONFIG")

get_property(MERGED_CONFIG GLOBAL PROPERTY "_CPP_LIBRARY_TRACKED_DEP_Qt6")
message(STATUS "After second call: ${MERGED_CONFIG}")

# Verify CONFIG is at the end, not in the component list
set(EXPECTED_MERGED "Qt6 6.5.0 COMPONENTS Core Widgets CONFIG")
if("${MERGED_CONFIG}" STREQUAL "${EXPECTED_MERGED}")
    message(STATUS "✓ PASS: CONFIG keyword not treated as component")
else()
    message(FATAL_ERROR "✗ FAIL: Expected '${EXPECTED_MERGED}' but got '${MERGED_CONFIG}'")
endif()

message(STATUS "")
message(STATUS "===========================================")
message(STATUS "All provider merging tests passed!")
message(STATUS "===========================================")
