# SPDX-License-Identifier: BSL-1.0
#
# cpp-library-setup.cmake - Core library setup functionality

function(_cpp_library_setup_core)
    set(oneValueArgs
        NAME
        VERSION 
        DESCRIPTION
        NAMESPACE
        HEADER_DIR
        REQUIRES_CPP_VERSION
        TOP_LEVEL
    )
    set(multiValueArgs
        HEADERS
        SOURCES
    )
    
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Extract the library name without namespace prefix for target naming
    string(REPLACE "${ARG_NAMESPACE}-" "" CLEAN_NAME "${ARG_NAME}")
    
    if(ARG_SOURCES)
        # Create a regular library if sources are present
        add_library(${ARG_NAME} STATIC ${ARG_SOURCES})
        add_library(${ARG_NAMESPACE}::${CLEAN_NAME} ALIAS ${ARG_NAME})
        target_include_directories(${ARG_NAME} PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:include>
        )
        target_compile_features(${ARG_NAME} PUBLIC cxx_std_${ARG_REQUIRES_CPP_VERSION})
        if(ARG_HEADERS)
            target_sources(${ARG_NAME} PUBLIC
                FILE_SET headers
                TYPE HEADERS
                BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/include
                FILES ${ARG_HEADERS}
            )
        endif()
    else()
        # Header-only INTERFACE target
        add_library(${ARG_NAME} INTERFACE)
        add_library(${ARG_NAMESPACE}::${CLEAN_NAME} ALIAS ${ARG_NAME})
        target_include_directories(${ARG_NAME} INTERFACE
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:include>
        )
        target_compile_features(${ARG_NAME} INTERFACE cxx_std_${ARG_REQUIRES_CPP_VERSION})
        if(ARG_HEADERS)
            target_sources(${ARG_NAME} INTERFACE
                FILE_SET headers
                TYPE HEADERS
                BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/include
                FILES ${ARG_HEADERS}
            )
        endif()
    endif()
    
    # Only set up full installation when building as top-level project
    if(ARG_TOP_LEVEL)
        include(GNUInstallDirs)
        include(CMakePackageConfigHelpers)
        
        # Install the target
        install(TARGETS ${ARG_NAME}
            EXPORT ${ARG_NAME}Targets
            FILE_SET headers DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        )
        
        # Install header directory if specified (fallback for older CMake)
        if(ARG_HEADER_DIR)
            install(DIRECTORY ${ARG_HEADER_DIR}/
                DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                FILES_MATCHING PATTERN "*.hpp" PATTERN "*.h"
            )
        endif()
        
        # Generate package config files
        write_basic_package_version_file(
            "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}ConfigVersion.cmake"
            VERSION ${ARG_VERSION}
            COMPATIBILITY SameMajorVersion
        )
        
        configure_file(
            "${CPP_LIBRARY_ROOT}/templates/Config.cmake.in"
            "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}Config.cmake"
            @ONLY
        )
        
        # Install export targets
        install(EXPORT ${ARG_NAME}Targets
            FILE ${ARG_NAME}Targets.cmake
            NAMESPACE ${ARG_NAMESPACE}::
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${ARG_NAME}
        )
        
        # Install config files
        install(FILES
            "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}Config.cmake"
            "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}ConfigVersion.cmake"
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${ARG_NAME}
        )
    endif()
    
endfunction()
