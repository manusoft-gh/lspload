cmake_minimum_required(VERSION 3.24)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" _lspload_ver_raw)
string(STRIP "${_lspload_ver_raw}" LSPLOAD_FILE_VERSION)
if(NOT LSPLOAD_FILE_VERSION MATCHES "^[0-9]+(\\.[0-9]+)*$")
  message(FATAL_ERROR "VERSION must contain a dotted numeric version (got '${LSPLOAD_FILE_VERSION}')")
endif()

project(LspLoad VERSION ${LSPLOAD_FILE_VERSION} LANGUAGES CXX)

if(NOT WIN32)
  message(FATAL_ERROR "LspLoad builds only on Windows")
endif()

get_property(_lspload_multi GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(_lspload_multi)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "" FORCE)
endif()

# Flat PE dir: build/<preset>/out/<CONFIG>/<outputName><ext>
foreach(_lspload_cfg IN ITEMS Debug Release)
  string(TOUPPER "${_lspload_cfg}" _lspload_cfg_u)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${_lspload_cfg_u} "${CMAKE_BINARY_DIR}/out/${_lspload_cfg}")
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${_lspload_cfg_u} "${CMAKE_BINARY_DIR}/out/${_lspload_cfg}")
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${_lspload_cfg_u} "${CMAKE_BINARY_DIR}/out/${_lspload_cfg}")
  set(CMAKE_PDB_OUTPUT_DIRECTORY_${_lspload_cfg_u} "${CMAKE_BINARY_DIR}/out/${_lspload_cfg}")
endforeach()

option(LSPLOAD_SIGN "Authenticode-sign PE after link via scripts/sign-files.ps1" OFF)
set(LSPLOAD_TARGETS "" CACHE STRING "Optional semicolon-separated host ids (empty = matrix filter)")
set(LSPLOAD_PER_FAMILY_MAX "0" CACHE STRING "Keep at most N latest ids per family (0 = unlimited)")
set(LSPLOAD_MIN_TOOLSET "" CACHE STRING "Minimum VS toolset (e.g. v141); empty = none")
set(LSPLOAD_MAX_TOOLSET "" CACHE STRING "Maximum VS toolset (e.g. v143); empty = none")
option(LSPLOAD_SHIP_ONLY "Consider only ship:true rows unless LSPLOAD_TARGETS is set" ON)
set(LSPLOAD_LEGACY_WINDOWS_SDK "" CACHE STRING
  "Windows kit pin for historic toolsets (default 10.0.19041.0; override via env LSPLOAD_LEGACY_WINDOWS_SDK)")

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/LspLoadHosts.cmake")
  message(FATAL_ERROR
    "cmake/LspLoadHosts.cmake is missing. Run: pwsh -File scripts/sync-from-hosts.ps1")
endif()

include(cmake/LspLoadHosts.cmake)
include(cmake/LspLoadTargets.cmake)

lspload_add_selected_hosts()
