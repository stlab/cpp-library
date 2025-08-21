# SPDX-License-Identifier: BSL-1.0
#
# cpp-library.cmake - Download and include cpp-library template
#
# This file downloads the cpp-library template system from GitHub releases
# Usage: include(cmake/cpp-library.cmake) then call cpp_library_setup(...)

set(CPP_LIBRARY_VERSION 1.0.0)
set(CPP_LIBRARY_HASH_SUM "efef2aee38ddd8a39de3e51db9efb3ab0ce123987260af2d130ae40be3ea85b9")

if(CPP_LIBRARY_CACHE)
  set(CPP_LIBRARY_LOCATION "${CPP_LIBRARY_CACHE}/cpp-library/cpp-library_${CPP_LIBRARY_VERSION}.cmake")
elseif(DEFINED ENV{CPP_LIBRARY_CACHE})
  set(CPP_LIBRARY_LOCATION "$ENV{CPP_LIBRARY_CACHE}/cpp-library/cpp-library_${CPP_LIBRARY_VERSION}.cmake")
else()
  set(CPP_LIBRARY_LOCATION "${CMAKE_BINARY_DIR}/cmake/cpp-library_${CPP_LIBRARY_VERSION}.cmake")
endif()

get_filename_component(CPP_LIBRARY_LOCATION ${CPP_LIBRARY_LOCATION} ABSOLUTE)

# Check if we already have the file and it's valid
set(NEED_DOWNLOAD TRUE)
if(EXISTS ${CPP_LIBRARY_LOCATION})
    file(SHA256 ${CPP_LIBRARY_LOCATION} existing_hash)
    if(existing_hash STREQUAL CPP_LIBRARY_HASH_SUM)
        set(NEED_DOWNLOAD FALSE)
    endif()
endif()

if(NEED_DOWNLOAD)
    message(STATUS "Downloading cpp-library.cmake v${CPP_LIBRARY_VERSION}...")
    file(DOWNLOAD
         https://github.com/stlab/cpp-library/releases/download/v${CPP_LIBRARY_VERSION}/cpp-library.cmake
         ${CPP_LIBRARY_LOCATION} 
         EXPECTED_HASH SHA256=${CPP_LIBRARY_HASH_SUM}
         SHOW_PROGRESS
    )
endif()

include(${CPP_LIBRARY_LOCATION})
