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

## Layout (bootstrap)

CMake, `hosts.json`, Inno generation, signing scripts, and the
`/add-runtime-target` skill land in later commits. This bootstrap is sources
and maintainer docs only.

```text
VERSION                      product version (source of truth)
ReadMe.txt                   author-facing stub readme (ships in LspLoad.zip)
src/LspLoad.cpp              stub implementation
src/RxExports.def            ARX/BRX exports
src/ZrxExports.def           ZRX exports
docs/gold/LspLoad-6.10-names.txt   6.10 PE name floor (63 binaries)
```

Rolling gold PE overlay will live in gitignored `gold/`. Do not commit
`.arx` / `.brx` / `.zrx` / `.grx` binaries.

## What not to do here

- Do not import the 42 `.vcxproj` folders, `LspLoad.sln`, `Win32/`, `X64/`,
  `.tlog`, or `_webprep`.
- Do not put PIN, PUK, or signing passwords in this tree.
- Public download zips must not contain signing scripts. Git/lab will keep
  signing separately in later commits.
