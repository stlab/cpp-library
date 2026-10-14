# SPDX-License-Identifier: BSL-1.0
# A separate directory keeps header language overrides off production targets.
cmake_minimum_required(VERSION 3.24)
set_source_files_properties(${headers} PROPERTIES LANGUAGE CXX HEADER_FILE_ONLY FALSE)
add_library("${index_target}" OBJECT EXCLUDE_FROM_ALL ${headers})
set_target_properties("${index_target}" PROPERTIES
    UNITY_BUILD OFF
    EXPORT_COMPILE_COMMANDS ON)
target_link_libraries("${index_target}" PRIVATE "${owner}")
