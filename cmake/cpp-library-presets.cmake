# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-presets.cmake - CMakePresets.json generation

function(_cpp_library_generate_presets)
    set(options FORCE_INIT)
    cmake_parse_arguments(ARG "${options}" "" "" ${ARGN})
    
    # Only generate if CMakePresets.json doesn't already exist (unless forcing)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CMakePresets.json" AND NOT ARG_FORCE_INIT)
        return()
    endif()
    
    if(ARG_FORCE_INIT)
        message(STATUS "Force regenerating CMakePresets.json")
    endif()
    
    set(PRESETS_TEMPLATE ${CPP_LIBRARY_ROOT}/templates/CMakePresets.json.in)
    set(PRESETS_OUT ${CMAKE_CURRENT_SOURCE_DIR}/CMakePresets.json)
    
    # Configure the presets template
    configure_file(${PRESETS_TEMPLATE} ${PRESETS_OUT} @ONLY)
    
    message(STATUS "Generated CMakePresets.json from template")
    
endfunction()
