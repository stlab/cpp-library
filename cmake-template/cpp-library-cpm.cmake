# SPDX-License-Identifier: BSL-1.0
#
# cpp-library.cmake - CPM-based inclusion of cpp-library template
#
# This file uses CPMAddPackage to fetch cpp-library from GitHub
# Usage: include(cmake/cpp-library.cmake) then call cpp_library_setup(...)
#
# Prerequisites: CPM.cmake must be included before this file

# Check if CPMAddPackage is available
if(NOT COMMAND CPMAddPackage)
    message(FATAL_ERROR "cpp-library.cmake requires CPM.cmake to be included first. Please include cmake/CPM.cmake before cmake/cpp-library.cmake")
endif()

# Fetch cpp-library via CPM
CPMAddPackage(
    NAME cpp-library
    GITHUB_REPOSITORY stlab/cpp-library
    GIT_TAG v1.0.0
    DOWNLOAD_ONLY YES
)

# Include the main cpp-library functionality
include(${cpp-library_SOURCE_DIR}/cpp-library.cmake)
