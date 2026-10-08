# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-testing.cmake - Runtime DLL deployment and testing compatibility
# 
# Provides cpp_library_copy_runtime_dlls for custom and toolkit-created executables.
# _cpp_library_setup_testing delegates to _cpp_library_setup_executables for compatibility.

# Deploys runtime DLLs beside a custom target on Windows; empty lists need no copy.
# Call in the directory that created the target, as required by POST_BUILD commands.
function(cpp_library_copy_runtime_dlls target)
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "cpp_library_copy_runtime_dlls: Target does not exist: ${target}")
    endif()
    if(WIN32)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND "${CMAKE_COMMAND}"
                "-DCPP_LIBRARY_RUNTIME_DLLS=$<TARGET_RUNTIME_DLLS:${target}>"
                "-DCPP_LIBRARY_RUNTIME_DESTINATION=$<TARGET_FILE_DIR:${target}>"
                -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cpp-library-copy-runtime-dlls.cmake"
            VERBATIM)
    endif()
endfunction()

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
