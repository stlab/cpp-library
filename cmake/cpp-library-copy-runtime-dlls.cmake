# SPDX-License-Identifier: BSL-1.0

cmake_minimum_required(VERSION 3.24)

if(NOT DEFINED CPP_LIBRARY_RUNTIME_DLLS
    OR NOT IS_DIRECTORY "${CPP_LIBRARY_RUNTIME_DESTINATION}")
    message(FATAL_ERROR "cpp-library: Runtime DLL deployment requires a DLL list and an existing destination directory")
endif()

file(REAL_PATH "${CPP_LIBRARY_RUNTIME_DESTINATION}" destination)
foreach(dll IN LISTS CPP_LIBRARY_RUNTIME_DLLS)
    if(NOT EXISTS "${dll}")
        message(FATAL_ERROR "cpp-library: Runtime DLL does not exist: ${dll}")
    endif()
    file(REAL_PATH "${dll}" source)
    get_filename_component(filename "${source}" NAME)
    # A source-built DLL may already share the executable's output directory.
    if(NOT source STREQUAL "${destination}/${filename}")
        file(COPY_FILE "${source}" "${destination}/${filename}" ONLY_IF_DIFFERENT)
    endif()
endforeach()
