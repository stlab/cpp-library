# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-testing.cmake - Testing setup with doctest

function(_cpp_library_setup_testing)
    set(oneValueArgs
        NAME
        NAMESPACE
    )
    set(multiValueArgs
        TESTS
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Extract the clean library name for linking
    string(REPLACE "${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
    
    # Download doctest dependency via CPM
    if(NOT TARGET doctest::doctest)
        CPMAddPackage("gh:doctest/doctest@2.4.12")
    endif()
    
    # Add test executables
    foreach(test IN LISTS ARG_TESTS)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/${test}.cpp" OR 
           EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/test/${test}.cpp")
           
            # Check both tests/ and test/ directories (projects use different conventions)
            set(test_file "")
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/${test}.cpp")
                set(test_file "tests/${test}.cpp")
            elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/test/${test}.cpp")
                set(test_file "test/${test}.cpp")
            endif()
            
            add_executable(${test} ${test_file})
            target_link_libraries(${test} PRIVATE ${ARG_NAMESPACE}::${CLEAN_NAME} doctest::doctest)
            
            # Register the test with CTest
            add_test(NAME ${test} COMMAND ${test})
            
            # Set test properties for better IDE integration
            set_tests_properties(${test} PROPERTIES
                LABELS "doctest"
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            )
        else()
            message(WARNING "Test file for ${test} not found in tests/ or test/ directories")
        endif()
    endforeach()
    
endfunction()
