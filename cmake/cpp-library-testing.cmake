# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-testing.cmake - Testing setup with doctest
# 
# Note: Testing logic has been consolidated into the main cpp-library.cmake file
# This file is kept for backward compatibility but the actual implementation
# is now in the _cpp_library_setup_executables function.

# Delegates to _cpp_library_setup_executables for backward compatibility.
# - Postcondition: test executables configured via _cpp_library_setup_executables
function(_cpp_library_setup_testing)
    set(oneValueArgs
        NAME
        NAMESPACE
    )
    set(multiValueArgs
        TESTS
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Delegate to the consolidated implementation
    _cpp_library_setup_executables(
        NAME "${ARG_NAME}"
        NAMESPACE "${ARG_NAMESPACE}" 
        TYPE "tests"
        EXECUTABLES "${ARG_TESTS}"
    )
    
endfunction()
