# Test for Bug 1: Components starting with 'O' are incorrectly excluded

function(test_regex TEST_NAME TEST_CALL EXPECTED)
    message(STATUS "\nTest: ${TEST_NAME}")
    message(STATUS "Input: ${TEST_CALL}")
    
    # Current buggy regex
    if(TEST_CALL MATCHES "COMPONENTS +([^O][^ ]*( +[^O][^ ]*)*)")
        string(REGEX REPLACE " +" ";" COMPONENTS "${CMAKE_MATCH_1}")
        message(STATUS "  Buggy regex: ${COMPONENTS}")
    else()
        set(COMPONENTS "")
        message(STATUS "  Buggy regex: NO MATCH")
    endif()
    
    # Fixed regex - match everything after COMPONENTS until ) or OPTIONAL_COMPONENTS
    set(FIXED_COMPONENTS "")
    if(TEST_CALL MATCHES "COMPONENTS +([^ )]+( +[^ )]+)*)")
        set(TEMP_MATCH "${CMAKE_MATCH_1}")
        # If OPTIONAL_COMPONENTS is present, only take everything before it
        if(TEMP_MATCH MATCHES "^(.+) +OPTIONAL_COMPONENTS")
            set(TEMP_MATCH "${CMAKE_MATCH_1}")
        endif()
        string(REGEX REPLACE " +" ";" FIXED_COMPONENTS "${TEMP_MATCH}")
        message(STATUS "  Fixed regex: ${FIXED_COMPONENTS}")
    endif()
    
    # Check if fixed version matches expected
    if("${FIXED_COMPONENTS}" STREQUAL "${EXPECTED}")
        message(STATUS "  ✓ PASS")
    else()
        message(STATUS "  ✗ FAIL - Expected: ${EXPECTED}")
    endif()
endfunction()

test_regex("Components with OpenGL" 
    "find_dependency(Qt6 6.0 COMPONENTS OpenGL Widgets)" 
    "OpenGL;Widgets")

test_regex("Components with OPTIONAL_COMPONENTS" 
    "find_dependency(Boost 1.79 COMPONENTS filesystem system OPTIONAL_COMPONENTS test)" 
    "filesystem;system")

test_regex("Normal components" 
    "find_dependency(Qt6 COMPONENTS Core Gui Widgets)" 
    "Core;Gui;Widgets")

test_regex("Single component starting with O" 
    "find_dependency(MyLib COMPONENTS Optional)" 
    "Optional")

test_regex("Component OpenMP" 
    "find_dependency(MyLib COMPONENTS OpenMP Other)" 
    "OpenMP;Other")
