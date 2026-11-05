# LspLoad (maintainer tree)

Demand-load stub for AutoCAD (ARX), BricsCAD (BRX), and ZWCAD (ZRX). LISP plugin
authors rename the module to match their `.lsp` and ship it from an installer.

This git tree is the **maintainer work copy**. The intended lab path is
`P:\Work\LspLoad\GitHub\lspload`. Leave `P:\Work\LspLoad` as the 6.10 gold tree
(read-only) until cutover.

Product version is the single line in [`VERSION`](VERSION) (currently 6.10).
Author-facing stub notes are in [`ReadMe.txt`](ReadMe.txt).

## Licenses

Two licenses apply; do not collapse them.

| Tree | License |
|------|---------|
| Stub (`src/`), CMake, `hosts/`, `scripts/` | Public domain — [`PUBLIC-DOMAIN.txt`](PUBLIC-DOMAIN.txt) (Unlicense) |
| `InnoSetup/` (sample installer kit) | ManuSoft LEGAL NOTICE — **not** public domain |

Do not stamp UNLICENSE on the Inno sample.

## Layout

```text
VERSION                      product version (source of truth)
CMakeLists.txt / CMakePresets.json
cmake/LspLoadHosts.cmake     GENERATED from hosts.json (committed)
cmake/LspLoadTargets.cmake   add_library + Windows SDK pin
hosts/hosts.json             host matrix (no productVersion)
scripts/sync-from-hosts.ps1  JSON → LspLoadHosts.cmake + docs/HOSTS.md
src/LspLoad.cpp              stub implementation
src/RxExports.def            ARX/BRX exports
src/ZrxExports.def           ZRX exports
src/GrxExports.def           GRX scaffolding (no ship row)
docs/gold/LspLoad-6.10-names.txt   6.10 PE name floor (63 binaries)
```

Rolling gold PE overlay lives in gitignored `gold/`. Do not commit
`.arx` / `.brx` / `.zrx` / `.grx` binaries.

## Building stubs (maintainers)

CMake 3.24+ and Visual Studio. **One configure = one arch** (no combined
`vs2022-dev` / `vs2022-full`). After any `hosts.json` edit:

```text
pwsh -File scripts/sync-from-hosts.ps1
pwsh -File scripts/validate-hosts.ps1
cmake --preset vs2022-dev-x64
```

| Preset | Arch | Intent |
|--------|------|--------|
| `vs2022-dev-x64` | x64 | Latest per family, toolset v141–v143 (not ARX.26). `LSPLOAD_SIGN=OFF` |
| `vs2022-dev-win32` | Win32 | Historic x86 ship rows. `LSPLOAD_SIGN=OFF` |
| `vs2022-full-x64` | x64 | Every ship:true x64 with toolset ≤ v143 |
| `vs2022-full-win32` | Win32 | Every ship:true x86 row |
| `vs2026-dev-x64` | x64 | Latest v145+ (ARX.26). `LSPLOAD_SIGN=OFF` |
| `vs2026-full-x64` | x64 | Every ship:true v145+ x64 (required to package ARX.26) |

PE land in `build/<preset>/out/<CONFIG>/`. Missing CAD SDKs **warn**; configure
still succeeds. Historic `v60`–`v140` rows pin Windows SDK **10.0.19041.0**
via `ForceImportBeforeCppProps` (`LSPLOAD_LEGACY_WINDOWS_SDK` cache/env).
Those toolsets need Daffodil / old Platform Toolsets on the lab box.

GRX has `src/GrxExports.def` and a `_GRXTARGET` remap; there is **no**
`add_library` until a GRX target row exists.

Signing (`scripts/sign-files.ps1`) is a later commit. `LSPLOAD_SIGN=ON` with
that script missing is a no-op, not a configure error.

## What not to do here

- Do not import the 42 `.vcxproj` folders, `LspLoad.sln`, `Win32/`, `X64/`,
  `.tlog`, or `_webprep`.
- Do not put PIN, PUK, or signing passwords in this tree.
- Public download zips must not contain signing scripts. Git/lab will keep
  signing separately in later commits.
