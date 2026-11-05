# LspLoad matrix: select rows, pin legacy Windows kits, add_library per enabled host.
include_guard(GLOBAL)

# List fields in LspLoadHosts.cmake use '|' so CMake ';' does not split values.
function(lspload_split_bar input out_var)
  set(_list)
  if(input)
    string(REPLACE "|" ";" _list "${input}")
  endif()
  set(${out_var} "${_list}" PARENT_SCOPE)
endfunction()

function(lspload_host_get id field out_var)
  set(${out_var} "${LSPLOAD_H_${id}_${field}}" PARENT_SCOPE)
endfunction()

function(lspload_toolset_number toolset out_var)
  if(toolset MATCHES "^[vV]([0-9]+)")
    set(${out_var} "${CMAKE_MATCH_1}" PARENT_SCOPE)
  else()
    set(${out_var} "0" PARENT_SCOPE)
  endif()
endfunction()

# JSON x86 → CMAKE_GENERATOR_PLATFORM Win32; JSON x64 → x64.
function(lspload_json_arch out_var)
  set(_arch "")
  if(CMAKE_GENERATOR_PLATFORM STREQUAL "x64")
    set(_arch "x64")
  elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "Win32")
    set(_arch "x86")
  endif()
  if(NOT _arch)
    message(FATAL_ERROR
      "CMAKE_GENERATOR_PLATFORM must be Win32 (JSON x86) or x64 (JSON x64); "
      "got '${CMAKE_GENERATOR_PLATFORM}'")
  endif()
  set(${out_var} "${_arch}" PARENT_SCOPE)
endfunction()

function(lspload_sdk_root sdk_env out_var)
  set(_root "")
  if(sdk_env AND DEFINED ENV{${sdk_env}})
    file(TO_CMAKE_PATH "$ENV{${sdk_env}}" _root)
  endif()
  set(${out_var} "${_root}" PARENT_SCOPE)
endfunction()

function(lspload_legacy_windows_sdk out_var)
  set(_ver "10.0.19041.0")
  if(LSPLOAD_LEGACY_WINDOWS_SDK)
    set(_ver "${LSPLOAD_LEGACY_WINDOWS_SDK}")
  elseif(DEFINED ENV{LSPLOAD_LEGACY_WINDOWS_SDK} AND NOT "$ENV{LSPLOAD_LEGACY_WINDOWS_SDK}" STREQUAL "")
    set(_ver "$ENV{LSPLOAD_LEGACY_WINDOWS_SDK}")
  endif()
  set(${out_var} "${_ver}" PARENT_SCOPE)
endfunction()

# ForceImportBeforeCppProps kit pin (not late VS_USER_PROPS — too late for UCRT).
# Regex ^v(60|70|80|90|100|110|120|140) so v110_xp matches.
function(lspload_vs_pin_windows_sdk target version)
  if(NOT target OR NOT version)
    message(FATAL_ERROR "lspload_vs_pin_windows_sdk(${target} ${version}): need target and version")
  endif()
  if(NOT CMAKE_GENERATOR MATCHES "Visual Studio")
    return()
  endif()

  set(_kits_root "")
  if(DEFINED ENV{WindowsSdkDir} AND EXISTS "$ENV{WindowsSdkDir}")
    file(TO_CMAKE_PATH "$ENV{WindowsSdkDir}" _kits_root)
  else()
    set(_kits_root "C:/Program Files (x86)/Windows Kits/10")
  endif()
  string(REGEX REPLACE "/$" "" _kits_root "${_kits_root}")

  set(_kit_ucrt "${_kits_root}/Include/${version}/ucrt")
  if(NOT EXISTS "${_kit_ucrt}")
    message(WARNING
      "lspload_vs_pin_windows_sdk(${target}): Windows SDK ${version} not found under "
      "Windows Kits Include\\${version}\\ucrt - pin may be ignored at build time")
  endif()

  set(_bin_x86 "${_kits_root}/bin/${version}/x86")
  set(_bin_x64 "${_kits_root}/bin/${version}/x64")
  if(NOT EXISTS "${_bin_x86}/mt.exe" AND NOT EXISTS "${_bin_x64}/mt.exe")
    set(_bin_x86 "${_kits_root}/bin/x86")
    set(_bin_x64 "${_kits_root}/bin/x64")
  endif()
  if(NOT EXISTS "${_bin_x86}/mt.exe" AND NOT EXISTS "${_bin_x64}/mt.exe")
    message(WARNING
      "lspload_vs_pin_windows_sdk(${target}): mt.exe not found under Windows Kits "
      "bin\\${version} or bin\\{x86,x64} - TRK0005 may still occur")
  endif()
  file(TO_NATIVE_PATH "${_bin_x86}" _bin_x86_n)
  file(TO_NATIVE_PATH "${_bin_x64}" _bin_x64_n)

  set(_sdk_props_early "${CMAKE_CURRENT_BINARY_DIR}/${target}.winsdk.props")
  set(_sdk_props_late "${CMAKE_CURRENT_BINARY_DIR}/${target}.winsdk-tools.props")
  file(TO_NATIVE_PATH "${_sdk_props_early}" _sdk_props_early_n)
  file(TO_NATIVE_PATH "${_sdk_props_late}" _sdk_props_late_n)

  set(_xml "")
  string(APPEND _xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
  string(APPEND _xml "<Project xmlns=\"http://schemas.microsoft.com/developer/msbuild/2003\">\n")
  string(APPEND _xml "  <!-- LspLoad: pin Windows SDK version BEFORE Microsoft.Cpp.props. -->\n")
  string(APPEND _xml "  <PropertyGroup>\n")
  string(APPEND _xml "    <WindowsTargetPlatformVersion>${version}</WindowsTargetPlatformVersion>\n")
  string(APPEND _xml "    <WindowsTargetPlatformMinVersion>${version}</WindowsTargetPlatformMinVersion>\n")
  string(APPEND _xml "  </PropertyGroup>\n")
  string(APPEND _xml "</Project>\n")
  file(WRITE "${_sdk_props_early}" "${_xml}")

  set(_xml "")
  string(APPEND _xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
  string(APPEND _xml "<Project xmlns=\"http://schemas.microsoft.com/developer/msbuild/2003\">\n")
  string(APPEND _xml "  <!-- LspLoad: AFTER Microsoft.Cpp.props (mt.exe path; no manifest). -->\n")
  string(APPEND _xml "  <PropertyGroup>\n")
  string(APPEND _xml "    <WindowsSDK_ExecutablePath_x86>${_bin_x86_n}</WindowsSDK_ExecutablePath_x86>\n")
  string(APPEND _xml "    <WindowsSDK_ExecutablePath_x64>${_bin_x64_n}</WindowsSDK_ExecutablePath_x64>\n")
  string(APPEND _xml "    <GenerateManifest>false</GenerateManifest>\n")
  string(APPEND _xml "    <EmbedManifest>false</EmbedManifest>\n")
  string(APPEND _xml "  </PropertyGroup>\n")
  string(APPEND _xml "  <PropertyGroup Condition=\"'$(Platform)'=='Win32' or '$(Platform)'=='x86'\">\n")
  string(APPEND _xml "    <WindowsSDK_ExecutablePath>$(WindowsSDK_ExecutablePath_x86)</WindowsSDK_ExecutablePath>\n")
  string(APPEND _xml "    <ExecutablePath>$(ExecutablePath);$(WindowsSDK_ExecutablePath_x86)</ExecutablePath>\n")
  string(APPEND _xml "  </PropertyGroup>\n")
  string(APPEND _xml "  <PropertyGroup Condition=\"'$(Platform)'=='x64'\">\n")
  string(APPEND _xml "    <WindowsSDK_ExecutablePath>$(WindowsSDK_ExecutablePath_x64)</WindowsSDK_ExecutablePath>\n")
  string(APPEND _xml "    <ExecutablePath>$(ExecutablePath);$(WindowsSDK_ExecutablePath_x64)</ExecutablePath>\n")
  string(APPEND _xml "  </PropertyGroup>\n")
  string(APPEND _xml "  <ItemDefinitionGroup>\n")
  string(APPEND _xml "    <Link>\n")
  string(APPEND _xml "      <GenerateManifest>false</GenerateManifest>\n")
  string(APPEND _xml "    </Link>\n")
  string(APPEND _xml "  </ItemDefinitionGroup>\n")
  string(APPEND _xml "</Project>\n")
  file(WRITE "${_sdk_props_late}" "${_xml}")

  set_property(TARGET ${target} PROPERTY VS_WINDOWS_TARGET_PLATFORM_VERSION "${version}")
  set_property(TARGET ${target} PROPERTY VS_GLOBAL_WindowsTargetPlatformVersion "${version}")
  set_property(TARGET ${target} PROPERTY
    VS_GLOBAL_ForceImportBeforeCppProps "${_sdk_props_early_n}")
  set_property(TARGET ${target} PROPERTY
    VS_GLOBAL_ForceImportAfterCppProps "${_sdk_props_late_n}")
endfunction()

# One shared AfterCppTargets sheet (CMake still emits per-config GenerateManifest=true).
set(LSPLOAD_NOMANIFEST_TARGETS_FILE "")
if(CMAKE_GENERATOR MATCHES "Visual Studio")
  set(_lspload_nm "${CMAKE_CURRENT_BINARY_DIR}/lspload.nomanifest.targets")
  set(_lspload_nm_xml "")
  string(APPEND _lspload_nm_xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
  string(APPEND _lspload_nm_xml "<Project xmlns=\"http://schemas.microsoft.com/developer/msbuild/2003\">\n")
  string(APPEND _lspload_nm_xml "  <Target Name=\"LspLoad_DisableManifest\"\n")
  string(APPEND _lspload_nm_xml "          BeforeTargets=\"BeforeLink;Link;Manifest;EmbedManifest;ManifestResourceCompile;_Link\">\n")
  string(APPEND _lspload_nm_xml "    <PropertyGroup>\n")
  string(APPEND _lspload_nm_xml "      <GenerateManifest>false</GenerateManifest>\n")
  string(APPEND _lspload_nm_xml "      <EmbedManifest>false</EmbedManifest>\n")
  string(APPEND _lspload_nm_xml "    </PropertyGroup>\n")
  string(APPEND _lspload_nm_xml "  </Target>\n")
  string(APPEND _lspload_nm_xml "</Project>\n")
  file(WRITE "${_lspload_nm}" "${_lspload_nm_xml}")
  file(TO_NATIVE_PATH "${_lspload_nm}" LSPLOAD_NOMANIFEST_TARGETS_FILE)
endif()

function(lspload_select_hosts out_enabled out_skipped)
  set(_candidates)
  set(_skipped)
  lspload_json_arch(_host_arch)

  set(_min_ts 0)
  if(LSPLOAD_MIN_TOOLSET)
    lspload_toolset_number("${LSPLOAD_MIN_TOOLSET}" _min_ts)
  endif()
  set(_max_ts 0)
  if(LSPLOAD_MAX_TOOLSET)
    lspload_toolset_number("${LSPLOAD_MAX_TOOLSET}" _max_ts)
  endif()

  set(_want_ids "${LSPLOAD_TARGETS}")

  foreach(_id IN LISTS LSPLOAD_HOST_IDS)
    lspload_host_get("${_id}" ARCH _rt_arch)
    lspload_host_get("${_id}" TOOLSET _toolset)
    lspload_host_get("${_id}" SDK_ENV _sdk_env)
    lspload_host_get("${_id}" SHIP _ship)

    if(NOT _rt_arch STREQUAL _host_arch)
      list(APPEND _skipped "${_id}|arch_mismatch:${_rt_arch}!=${_host_arch}")
      continue()
    endif()

    if(_want_ids)
      list(FIND _want_ids "${_id}" _idx)
      if(_idx LESS 0)
        list(APPEND _skipped "${_id}|not_in_LSPLOAD_TARGETS")
        continue()
      endif()
    elseif(LSPLOAD_SHIP_ONLY AND NOT _ship)
      list(APPEND _skipped "${_id}|not_ship")
      continue()
    endif()

    lspload_toolset_number("${_toolset}" _ts_num)
    if(_min_ts GREATER 0 AND _ts_num LESS _min_ts)
      list(APPEND _skipped "${_id}|toolset_below_min:${_toolset}<${LSPLOAD_MIN_TOOLSET}")
      continue()
    endif()
    if(_max_ts GREATER 0 AND _ts_num GREATER _max_ts)
      list(APPEND _skipped "${_id}|toolset_above_max:${_toolset}>${LSPLOAD_MAX_TOOLSET}")
      continue()
    endif()

    lspload_sdk_root("${_sdk_env}" _root)
    if(NOT _root OR NOT EXISTS "${_root}")
      list(APPEND _skipped "${_id}|sdk_missing:${_sdk_env}")
      continue()
    endif()

    list(APPEND _candidates "${_id}")
  endforeach()

  set(_max_pf 0)
  if(NOT _want_ids AND LSPLOAD_PER_FAMILY_MAX MATCHES "^[0-9]+$")
    set(_max_pf "${LSPLOAD_PER_FAMILY_MAX}")
  endif()

  set(_enabled)
  if(_max_pf GREATER 0)
    set(_fams)
    foreach(_id IN LISTS LSPLOAD_HOST_IDS)
      lspload_host_get("${_id}" FAMILY _f)
      if(_f)
        list(APPEND _fams "${_f}")
      endif()
    endforeach()
    list(REMOVE_DUPLICATES _fams)
    foreach(_fam IN LISTS _fams)
      set(_pairs)
      foreach(_id IN LISTS _candidates)
        lspload_host_get("${_id}" FAMILY _f)
        if(NOT _f STREQUAL _fam)
          continue()
        endif()
        lspload_host_get("${_id}" VERSION _ver)
        list(APPEND _pairs "${_ver}|${_id}")
      endforeach()
      if(NOT _pairs)
        continue()
      endif()
      list(SORT _pairs COMPARE NATURAL ORDER DESCENDING)
      set(_kept 0)
      foreach(_pair IN LISTS _pairs)
        string(REGEX REPLACE "^[^|]+\\|" "" _id "${_pair}")
        if(_kept LESS _max_pf)
          list(APPEND _enabled "${_id}")
          math(EXPR _kept "${_kept}+1")
        else()
          list(APPEND _skipped "${_id}|per_family_max:${_max_pf}")
        endif()
      endforeach()
    endforeach()
  else()
    set(_enabled "${_candidates}")
  endif()

  set(${out_enabled} "${_enabled}" PARENT_SCOPE)
  set(${out_skipped} "${_skipped}" PARENT_SCOPE)
endfunction()

function(lspload_add_host id)
  lspload_host_get("${id}" FAMILY _family)
  lspload_host_get("${id}" EXT _ext)
  lspload_host_get("${id}" DEF _def)
  lspload_host_get("${id}" OUTPUT_NAME _output)
  lspload_host_get("${id}" TOOLSET _toolset)
  lspload_host_get("${id}" CHARACTER_SET _charset)
  lspload_host_get("${id}" SDK_ENV _sdk_env)
  lspload_host_get("${id}" SDK_INC _sdk_inc)
  lspload_host_get("${id}" SDK_LIB _sdk_lib)
  lspload_host_get("${id}" DEFINES _defines)
  lspload_host_get("${id}" LIBS _libs)
  lspload_host_get("${id}" CXX_STANDARD _cxxstd)
  lspload_host_get("${id}" PIN_WINDOWS_SDK _pin)

  lspload_sdk_root("${_sdk_env}" _sdk_root)
  if(NOT _sdk_root OR NOT EXISTS "${_sdk_root}")
    message(WARNING "LspLoad ${id}: SDK ${_sdk_env} not found; skip add_library")
    return()
  endif()

  string(REPLACE "." "_" _safe "${id}")
  set(_target "LspLoad_${_safe}")

  set(_src "${CMAKE_SOURCE_DIR}/src/LspLoad.cpp")
  set(_def_path "${CMAKE_SOURCE_DIR}/${_def}")
  add_library(${_target} SHARED "${_src}")
  if(EXISTS "${_def_path}")
    target_sources(${_target} PRIVATE "${_def_path}")
  else()
    message(WARNING "LspLoad ${id}: module-definition file missing: ${_def_path}")
  endif()

  lspload_split_bar("${_defines}" _def_list)
  lspload_split_bar("${_sdk_inc}" _sdk_inc_list)
  lspload_split_bar("${_sdk_lib}" _sdk_lib_list)
  lspload_split_bar("${_libs}" _lib_list)

  foreach(_rel IN LISTS _sdk_inc_list)
    if(_rel)
      target_include_directories(${_target} PRIVATE "${_sdk_root}/${_rel}")
    endif()
  endforeach()

  set(_charset_defs)
  if(_charset STREQUAL "MultiByte")
    set(_vs_charset "MultiByte")
  else()
    set(_vs_charset "Unicode")
    list(APPEND _charset_defs UNICODE _UNICODE)
  endif()

  target_compile_definitions(${_target} PRIVATE
    WIN32
    _WINDOWS
    _USRDLL
    ACRXAPP
    ${_def_list}
    ${_charset_defs}
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:NDEBUG>
  )

  set_target_properties(${_target} PROPERTIES
    OUTPUT_NAME "${_output}"
    PREFIX ""
    SUFFIX "${_ext}"
    MSVC_RUNTIME_LIBRARY "MultiThreadedDLL"
    VS_GLOBAL_CharacterSet "${_vs_charset}"
    VS_GLOBAL_GenerateManifest "false"
    FOLDER "${_family}"
  )
  if(LSPLOAD_NOMANIFEST_TARGETS_FILE)
    set_property(TARGET ${_target} PROPERTY
      VS_GLOBAL_ForceImportAfterCppTargets "${LSPLOAD_NOMANIFEST_TARGETS_FILE}")
  endif()

  if(_toolset)
    set_property(TARGET ${_target} PROPERTY VS_PLATFORM_TOOLSET "${_toolset}")
  endif()

  if(_cxxstd)
    set_target_properties(${_target} PROPERTIES
      CXX_STANDARD ${_cxxstd}
      CXX_STANDARD_REQUIRED ON
    )
  endif()

  if(MSVC)
    target_compile_options(${_target} PRIVATE "/W3")
    set(_fs TRUE)
    if(_toolset MATCHES "^v([0-9]+)")
      if(CMAKE_MATCH_1 LESS 120)
        set(_fs FALSE)
      endif()
    endif()
    if(_fs)
      target_compile_options(${_target} PRIVATE "/FS")
    endif()
    target_link_options(${_target} PRIVATE
      "/SUBSYSTEM:WINDOWS"
      "/DYNAMICBASE:NO"
      "/IGNORE:4099"
      "/MANIFEST:NO"
    )
    foreach(_rel IN LISTS _sdk_lib_list)
      if(NOT _rel)
        continue()
      endif()
      # /LIBPATH avoids VS generator appending $(Configuration) to target_link_directories.
      file(TO_NATIVE_PATH "${_sdk_root}/${_rel}" _libdir_n)
      target_link_options(${_target} PRIVATE "/LIBPATH:\"${_libdir_n}\"")
    endforeach()
  else()
    foreach(_rel IN LISTS _sdk_lib_list)
      if(_rel)
        target_link_directories(${_target} PRIVATE "${_sdk_root}/${_rel}")
      endif()
    endforeach()
  endif()

  target_link_libraries(${_target} PRIVATE ${_lib_list})

  set(_do_pin FALSE)
  if(_pin)
    set(_do_pin TRUE)
  endif()
  if(_toolset MATCHES "^v(60|70|80|90|100|110|120|140)")
    set(_do_pin TRUE)
  endif()
  if(_do_pin)
    lspload_legacy_windows_sdk(_kit)
    lspload_vs_pin_windows_sdk(${_target} "${_kit}")
  endif()

  if(LSPLOAD_SIGN AND LSPLOAD_SIGN_SCRIPT)
    add_custom_command(TARGET ${_target} POST_BUILD
      COMMAND "${LSPLOAD_PWSH}" -NoProfile -NonInteractive -ExecutionPolicy Bypass
        -File "${LSPLOAD_SIGN_SCRIPT}" -Path "$<TARGET_FILE:${_target}>"
      COMMENT "Authenticode sign $<TARGET_FILE:${_target}>"
      VERBATIM)
  endif()

  if(_family STREQUAL "ZRX")
    file(TO_NATIVE_PATH "${_sdk_root}/Tools/ZRXCheck/ZRXCheck.exe" _zrxcheck_n)
    add_custom_command(TARGET ${_target} POST_BUILD
      COMMAND cmd.exe /c IF EXIST "${_zrxcheck_n}" "${_zrxcheck_n}" "$<TARGET_FILE:${_target}>"
      COMMENT "ZRXCheck ${id} (if present)"
      VERBATIM)
  endif()
endfunction()

function(lspload_add_selected_hosts)
  find_program(LSPLOAD_PWSH NAMES pwsh powershell)
  set(_sign "${CMAKE_SOURCE_DIR}/scripts/sign-files.ps1")
  set(_sign_script "")
  if(LSPLOAD_SIGN)
    if(EXISTS "${_sign}")
      if(NOT LSPLOAD_PWSH)
        message(WARNING "LSPLOAD_SIGN is ON but pwsh/powershell was not found; signing is a no-op")
      else()
        set(_sign_script "${_sign}")
      endif()
    else()
      message(WARNING
        "LSPLOAD_SIGN is ON but scripts/sign-files.ps1 is missing; signing is a no-op")
    endif()
  endif()
  set(LSPLOAD_SIGN_SCRIPT "${_sign_script}" CACHE INTERNAL "Path to sign-files.ps1 when signing is armed")

  lspload_select_hosts(_enabled _skipped)
  lspload_json_arch(_arch)
  list(LENGTH _enabled _ne)
  list(LENGTH _skipped _ns)
  message(STATUS "LspLoad arch=${_arch}  enabled ${_ne}  skipped ${_ns}  sign=${LSPLOAD_SIGN}")
  foreach(_id IN LISTS _enabled)
    lspload_host_get("${_id}" SDK_ENV _env)
    lspload_host_get("${_id}" TOOLSET _ts)
    lspload_sdk_root("${_env}" _root)
    message(STATUS "  ENABLED  ${_id}  SDK=${_root}  toolset=${_ts}")
    lspload_add_host("${_id}")
  endforeach()
  foreach(_s IN LISTS _skipped)
    if(_s MATCHES "\\|sdk_missing:")
      message(WARNING "  SKIPPED (no SDK)  ${_s}")
    elseif(_s MATCHES "\\|toolset_")
      message(STATUS "  SKIPPED (toolset)  ${_s}")
    else()
      message(STATUS "  SKIPPED  ${_s}")
    endif()
  endforeach()
endfunction()
