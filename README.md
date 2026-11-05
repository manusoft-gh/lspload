# LspLoad

Demand-load stub for AutoCAD (ARX), BricsCAD (BRX), and ZWCAD (ZRX). LISP plugin
authors rename the module to match their `.lsp` and ship it from an installer.

Product version is the single line in [`VERSION`](VERSION). Author-facing stub
notes are in [`ReadMe.txt`](ReadMe.txt).

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
scripts/sign-files.ps1       git/lab Authenticode (jsign); not packed in public zips
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

## Signing (lab / git only)

Official PE are Authenticode-signed after link with `scripts/sign-files.ps1`
(jsign `--storetype YUBIKEY`, RFC3161 `http://ts.ssl.com`). PIN is **never**
on the command line and **never** in this tree.

Set one of (first match wins):

- `SIGN_STORE_PASSWORD`
- `SIGN_PIN`
- `YUBIKEY_PIN`

Optional: `SIGN_STORE_TYPE` (default `YUBIKEY`), `SIGN_CERT_ALIAS`,
`SIGN_CERT_FILE`, `SIGN_PFX_PATH`, `SIGN_PFX_PASSWORD`, `SIGN_TIMESTAMP_URL`.

CMake post-build runs the script when `LSPLOAD_SIGN` is ON (full presets),
`scripts/sign-files.ps1` exists, pwsh is found, and a PIN (or PFX) env var is
set. Missing script, missing PIN, or `LSPLOAD_SIGN=OFF` is a **no-op**
(warning, not a configure error). `*-dev-*` presets set `LSPLOAD_SIGN=OFF`.
Already-Valid signatures are skipped.

This script is git/lab only. `package-zips.ps1` omits it from public zips.

## What not to do here

- Do not put PIN, PUK, or signing passwords in this tree.
- Public download zips must not contain signing scripts.
