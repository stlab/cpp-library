# SPDX-License-Identifier: BSL-1.0
#
# package.cmake - Package cpp-library into a single distributable file

cmake_minimum_required(VERSION 3.20)

set(SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR})
set(OUTPUT_FILE ${CMAKE_CURRENT_LIST_DIR}/dist/cpp-library.cmake)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/dist)

# Read all component files
file(READ ${SOURCE_DIR}/cmake/cpp-library-setup.cmake SETUP_CONTENT)
file(READ ${SOURCE_DIR}/cmake/cpp-library-testing.cmake TESTING_CONTENT)  
file(READ ${SOURCE_DIR}/cmake/cpp-library-docs.cmake DOCS_CONTENT)
file(READ ${SOURCE_DIR}/cmake/cpp-library-presets.cmake PRESETS_CONTENT)

# Read template files
file(READ ${SOURCE_DIR}/templates/CMakePresets.json.in PRESETS_TEMPLATE)
file(READ ${SOURCE_DIR}/templates/Config.cmake.in CONFIG_TEMPLATE)
file(READ ${SOURCE_DIR}/templates/Doxyfile.in DOXYFILE_TEMPLATE)

# Escape templates for embedding
string(REPLACE "\\" "\\\\" PRESETS_TEMPLATE "${PRESETS_TEMPLATE}")
string(REPLACE "\"" "\\\"" PRESETS_TEMPLATE "${PRESETS_TEMPLATE}")
string(REPLACE "\\" "\\\\" CONFIG_TEMPLATE "${CONFIG_TEMPLATE}")  
string(REPLACE "\"" "\\\"" CONFIG_TEMPLATE "${CONFIG_TEMPLATE}")
string(REPLACE "\\" "\\\\" DOXYFILE_TEMPLATE "${DOXYFILE_TEMPLATE}")
string(REPLACE "\"" "\\\"" DOXYFILE_TEMPLATE "${DOXYFILE_TEMPLATE}")

# Clean up module content (remove duplicate headers)
string(REGEX REPLACE "^# SPDX-License-Identifier: BSL-1\\.0[^\n]*\n#[^\n]*\n#[^\n]*\n\n?" "" SETUP_CLEAN "${SETUP_CONTENT}")
string(REGEX REPLACE "^# SPDX-License-Identifier: BSL-1\\.0[^\n]*\n#[^\n]*\n#[^\n]*\n\n?" "" TESTING_CLEAN "${TESTING_CONTENT}")
string(REGEX REPLACE "^# SPDX-License-Identifier: BSL-1\\.0[^\n]*\n#[^\n]*\n#[^\n]*\n\n?" "" DOCS_CLEAN "${DOCS_CONTENT}")
string(REGEX REPLACE "^# SPDX-License-Identifier: BSL-1\\.0[^\n]*\n#[^\n]*\n#[^\n]*\n\n?" "" PRESETS_CLEAN "${PRESETS_CONTENT}")

# Fix template paths in setup module
string(REPLACE "\"\${CPP_LIBRARY_ROOT}/templates/Config.cmake.in\"" "\"\${CMAKE_CURRENT_BINARY_DIR}/cpp-library-config.cmake.in\"" SETUP_CLEAN "${SETUP_CLEAN}")
string(REPLACE "function(_cpp_library_setup_core)" "function(_cpp_library_setup_core)
    # Write embedded template to temporary file
    file(WRITE \"\${CMAKE_CURRENT_BINARY_DIR}/cpp-library-config.cmake.in\" \"\${CPP_LIBRARY_CONFIG_TEMPLATE}\")" SETUP_CLEAN "${SETUP_CLEAN}")

# Fix template paths and add template writing to docs module
string(REPLACE "\${CPP_LIBRARY_ROOT}/templates/Doxyfile.in" "\${CMAKE_CURRENT_BINARY_DIR}/cpp-library-doxyfile.in" DOCS_CLEAN "${DOCS_CLEAN}")
string(REPLACE "function(_cpp_library_setup_docs)" "function(_cpp_library_setup_docs)
    # Write embedded template to temporary file
    file(WRITE \"\${CMAKE_CURRENT_BINARY_DIR}/cpp-library-doxyfile.in\" \"\${CPP_LIBRARY_DOXYFILE_TEMPLATE}\")" DOCS_CLEAN "${DOCS_CLEAN}")

# Fix template paths and add template writing to presets module  
string(REPLACE "\${CPP_LIBRARY_ROOT}/templates/CMakePresets.json.in" "\${CMAKE_CURRENT_BINARY_DIR}/cpp-library-presets.json.in" PRESETS_CLEAN "${PRESETS_CLEAN}")
string(REPLACE "function(_cpp_library_generate_presets)" "function(_cpp_library_generate_presets)
    # Write embedded template to temporary file
    file(WRITE \"\${CMAKE_CURRENT_BINARY_DIR}/cpp-library-presets.json.in\" \"\${CPP_LIBRARY_PRESETS_TEMPLATE}\")" PRESETS_CLEAN "${PRESETS_CLEAN}")

# Read main function from cpp-library.cmake
file(READ ${SOURCE_DIR}/cpp-library.cmake MAIN_CONTENT)
string(REGEX REPLACE "^# SPDX-License-Identifier: BSL-1\\.0.*\n\n# Determine the directory.*get_filename_component.*\n\n# Include CTest.*\ninclude\\(CTest\\)\n\n# Include all the component modules.*\ninclude.*\ninclude.*\ninclude.*\ninclude.*\n\n" "" MAIN_CLEAN "${MAIN_CONTENT}")

# Write the packaged file
file(WRITE ${OUTPUT_FILE} "# SPDX-License-Identifier: BSL-1.0
#
# cpp-library.cmake - Modern C++ Header-Only Library Template (Single File Distribution)
# Generated from: https://github.com/stlab/cpp-library
#
# Usage: Download and include this file, then call cpp_library_setup(...)

cmake_minimum_required(VERSION 3.20)
include(CTest)

# Embedded templates
set(CPP_LIBRARY_PRESETS_TEMPLATE \"${PRESETS_TEMPLATE}\")
set(CPP_LIBRARY_CONFIG_TEMPLATE \"${CONFIG_TEMPLATE}\")  
set(CPP_LIBRARY_DOXYFILE_TEMPLATE \"${DOXYFILE_TEMPLATE}\")

# === cpp-library-setup.cmake ===
${SETUP_CLEAN}

# === cpp-library-testing.cmake ===
${TESTING_CLEAN}

# === cpp-library-docs.cmake ===
${DOCS_CLEAN}

# === cpp-library-presets.cmake ===
${PRESETS_CLEAN}

# === Main cpp_library_setup function ===
${MAIN_CLEAN}")

# Calculate hash and report
file(SHA256 ${OUTPUT_FILE} HASH)
message(STATUS "✅ Packaged cpp-library.cmake created!")
message(STATUS "📁 Location: ${OUTPUT_FILE}")
message(STATUS "🔐 SHA256: ${HASH}")
message(STATUS "📦 Size: $(wc -c < ${OUTPUT_FILE}) bytes")
