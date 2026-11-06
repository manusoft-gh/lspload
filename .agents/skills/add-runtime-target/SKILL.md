---
name: add-runtime-target
description: >
  Add a new CAD host (AutoCAD/ObjectARX, BricsCAD/BRX, ZWCAD/ZRX, or
  GstarCAD/GRX) as a hosts.json row, regenerate CMake/Inno from that matrix,
  bump VERSION, signed-build the matching full preset row, and zip with
  package-zips.ps1 -Official. Use when adding support for a new host year, or
  when the user runs /add-runtime-target. Triggers: "add runtime", "new AutoCAD",
  "support BricsCAD Vn", "ZWCAD 20xx", "GstarCAD", "ARX.xx", "BRX.xx", "ZRX.20xx",
  "GRX.20xx".
---

# Add Runtime Target (LspLoad)

Git-only maintainer procedure. This file lives at
`.agents/skills/add-runtime-target/SKILL.md`. `scripts/package-zips.ps1` already
excludes `.agents` from `LspLoadSource.zip` — do not pack the skill.

LspLoad is a demand-load stub (`src/LspLoad.cpp`), not OpenDCL Runtime. Do
**not** clone `Runtime/*/VI/*.props`, `RxInstall.cpp`, WiX catalogs, languages,
or Studio. There is no `.vcxproj` to copy.

Never access drives X: or B:.

## One-home-per-fact

| Fact | File | Notes |
|------|------|--------|
| Host inventory | `hosts/hosts.json` | Only matrix. **No** `productVersion`. |
| Product version | `VERSION` | Single line. Patch bump default (`6.10` → `6.11`). |
| CMake rows | `cmake/LspLoadHosts.cmake` | **GENERATED.** Do not hand-edit. |
| Inno `[Files]` | `InnoSetup/generated/HostsFiles.iss` | **GENERATED.** DestName is row-level. |
| Inno Pascal | `InnoSetup/generated/HostsCode.iss` | **GENERATED.** Detect / write / uninstall. |
| Presets | `CMakePresets.json` | One configure = one arch. No combined `vs2022-full`. |
| Zipper | `scripts/package-zips.ps1` | **The only copier/zipper.** Do not copy PE into `InnoSetup/LspLoad/` yourself. |
| Kit header | `InnoSetup/ReadMe.txt` | `Installer Script 3.0` — independent of `VERSION`. Do not bump it for a host add. |

After every JSON edit: `pwsh -File scripts/sync-from-hosts.ps1` then
`pwsh -File scripts/validate-hosts.ps1` **before** configure. CMake includes
the generated cmake file; it does not parse JSON.

## Inputs to collect (do not proceed without)

1. **Family:** `ARX` / `BRX` / `ZRX` / `GRX`. GRX is allowed when SDK env,
   directory, **and operator-supplied registry probes** are present. Do **not**
   invent GstarCAD keys. First GRX row has no same-family LspLoad clone — fill
   every required field from the SDK + operator probes. That first row **must
   also relax** the v1 freeze in `scripts/validate-hosts.ps1` (the two checks
   `GRX family must have zero targets` and `GRX ship:true is not allowed`).
   Keep `ship: true` only when that real SDK row exists. Keep refusing
   invented registry keys. Do not add a GRX target while those checks still
   require zero rows.
2. **Marketing product** (AutoCAD 2028, BricsCAD V28, ZWCAD 2027, GstarCAD 20xx).
3. **Matrix `version` token:**
   - ARX: ObjectARX **major** (worked 6.10 example: **`26`**, not the year).
   - BRX: BricsCAD major (`27`).
   - ZRX: **calendar year** (`2025`).
   - GRX: **calendar year** (OpenDCL pattern `2027` — confirm with the SDK).
   **Ask. Do not infer ARX major from marketing year.** There is no ARX.27
   example in this product.
4. **Arch:** default **x64-only**. Do not add Win32 unless asked. Unsigned
   iteration uses the matching `*-dev-*` preset. Packaging / `-Official` uses
   the matching **full** preset (never `*-dev-*`).
5. **SDK env var** (worked: `ARX2027` for ARX.26 — **not** `ARX26`) and that it
   is set to a **real directory**. **Refuse** if unset or the path is missing.
   Env var **names** only — never PIN / PUK / passwords.
6. **Clone source:** latest **same-family** `ship: true` row (default). Clone
   the whole JSON object, then patch only SDK-documented deltas. First GRX:
   no clone.
7. **Registry probes:** full `Software\...\R<major>.<minor>` / `V<n>x64` /
   `ZWCAD\<year>` list with `key`, `curVerName`, `curVerHive`, `appsHive`,
   `writeRoot`. Extra years are extra **probes on the same row** (same DestName).
   Probes never carry a Loader filename.
8. **Toolset:** from the previous same-family row **or** SDK docs. Never
   default `v142`. **ARX.26 is `v145`** and requires **`vs2026-full-x64`**.
   Historic v143 (BRX.27, …) stay on vs2022. Do **not** copy OpenDCL
   `_ARXTARGET`, WiX, or RxInstall. LspLoad ARX is `_ACADTARGET` only.
9. **Defines collected, not inferred:**
   - ARX: `_ACADTARGET=<major>`
   - BRX: `_ACADTARGET` **compatibility** value (`26` on BRX.27 — **not** the
     BricsCAD major). There is **no** `_BRXTARGET` in `src/LspLoad.cpp`.
   - ZRX: `_ZRXTARGET` **short code** (`25` for 2025) **and** `_ACADTARGET`
     compatibility (`23` on the 2025 row).
   - GRX: `_GRXTARGET` (and compatibility `_ACADTARGET` from the SDK).
   Ask if the clone’s values should change.
10. **Libs / includes:** clone previous (`sdkInc` / `sdkLib` / `libs`). ZRX is
    `arxport/inc` + `inc` + `lib-x64` on the 2025 row, **not** ARX `Inc` /
    `Lib-x64`. Patch lib names only if the SDK renamed them.
11. **Product version:** bump **`VERSION` only** (default patch). Confirm.
    Do not edit a JSON version field (there isn’t one). Do not couple
    `#define MyAppVersion` (`InnoSetup/MyLispPlugin.iss`, sample plugin `2.0`)
    or the Inno kit header to this bump.

### Required JSON fields (every row)

`id`, `family`, `version`, `arch` (`x86` or `x64` only — never `Win32`),
`ext`, `def`, `outputName`, `toolset`, `sdkEnv`, `sdkInc`, `sdkLib`, `libs`,
`defines`, `characterSet`, `cxxStandard` (`17` or `null`), `pinWindowsSdk`,
`ship`, `reg.appsSuffix`, `reg.loaderStyle`, `reg.probes[]`.

Every probe: `key`, `curVerName`, `curVerHive`, `appsHive`, `writeRoot`.
`writeRoot` is `preferred32` | `preferred64` | `hklm32`.
Hives: `HKCU32`, `HKCU64`, `HKLM32`, `HKLM64`.

`outputName` regex: `^LspLoad\.(ARX|BRX|ZRX|GRX)\.[0-9]+(\.x64)?$`

| Arch | `outputName` + ext | Inno DestName |
|------|--------------------|---------------|
| x86 | `LspLoad.{FAM}.{ver}{ext}` | `{#MyAppBaseName}.{FAM}.{ver}{ext}` |
| x64 | `LspLoad.{FAM}.{ver}.x64{ext}` | `{#MyAppBaseName}.{FAM}.{ver}.x64{ext}` |

## Worked 6.10 example (do not invent ARX.27)

These values exist in `hosts/hosts.json` today. Use them as the clone pattern
for the **next** AutoCAD — after the operator supplies the new major / SDK /
`R<major>.<minor>` list.

| Field | Value |
|-------|--------|
| `id` | `ARX.26.x64` |
| `version` | `26` |
| marketing | AutoCAD **2027** |
| `sdkEnv` | `ARX2027` |
| probe `key` | `Software\Autodesk\AutoCAD\R26.0` |
| `toolset` | `v145` |
| `defines` | `_ACADTARGET=26` |
| `outputName` | `LspLoad.ARX.26.x64` |
| PE | `LspLoad.ARX.26.x64.arx` |
| packaging preset | `vs2026-full-x64` |
| CMake target | `LspLoad_ARX_26_x64` |

Placeholder for a **new** AutoCAD (operator supplies `<major>`):
`LspLoad.ARX.<major>.x64.arx`. **Do not** write ARX.27 / AutoCAD 2028 as if
they were verified.

BRX.27 clone facts: `sdkEnv` `BRX27`, `libs` `BRX27.lib`, `sdkInc`
`Inc64;Inc`, `_ACADTARGET=26` (compat), `toolset` `v143`, registry
`Software\Bricsys\Bricscad\V27x64`, `curVerName` `CURVER`.

ZRX.2025 clone facts: `sdkEnv` `ZRX2025`, `_ZRXTARGET=25`, `_ACADTARGET=23`,
`toolset` `v141`, extra probe `Software\ZWSOFT\ZWCAD\2026` still DestNames the
**2025** module. `ZRX.2024` is `ship: false`; ZWCAD 2024 is an extra probe on
`ZRX.2023`.

## Workflow

### 1. Confirm inputs

Refuse if:

- ObjectARX major was guessed from a marketing year
- `sdkEnv` is unset, or `$env:<sdkEnv>` is missing / not a directory
- GRX probes were invented instead of supplied
- The operator asked to default `toolset` to `v142`

### 2. Clone the JSON row

**Hand-edit** `hosts/hosts.json` (and, on the **first GRX row only**,
`scripts/validate-hosts.ps1` as below). Do **not** hand-edit generated files.
Copy the latest same-family `ship: true` object. New `id` (`ARX.<major>.x64`,
`BRX.<ver>.x64`, `ZRX.<year>.x64`, `GRX.<year>.x64`). Patch SDK / defines /
libs / `reg.probes` / `marketing`. Loader stays row-level (`outputName` +
`ext`). Shared-binary years = extra probes, not a second PE.

`pinWindowsSdk` is `true` when `toolset` matches `^v(60|70|80|90|100|110|120|140)`
(includes `_xp`). New x64 hosts are almost always `false`.

**First GRX row:** before validate will pass, lift the v1 freeze in
`scripts/validate-hosts.ps1`:

```powershell
if ($grxRows -ne 0) { Add-Err "GRX family must have zero targets (found $grxRows)" }
if ($grxShip -ne 0) { Add-Err "GRX ship:true is not allowed (found $grxShip)" }
```

Replace those with schema that still requires operator-supplied probes and a
real `sdkEnv` directory, and that still forbids `ship: true` without that SDK
row. Do **not** invent registry keys. Later GRX years clone the first row and
do not re-introduce a zero-target freeze.

### 3. Sync and validate

```powershell
pwsh -File scripts/sync-from-hosts.ps1
pwsh -File scripts/validate-hosts.ps1
```

Re-run sync after **every** JSON edit, before configure. Sync **rewrites**
committed generated files — never hand-edit them:

- `cmake/LspLoadHosts.cmake`
- `InnoSetup/generated/HostsFiles.iss`
- `InnoSetup/generated/HostsCode.iss`
- `docs/HOSTS.md`

**Commit that sync output with** `hosts/hosts.json` (and `VERSION` /
product `ReadMe.txt` when bumped). Omitting the generated files leaves
CMake/Inno stale for the next clone.

### 4. Bump product version

- `VERSION` (patch unless the operator chooses otherwise)
- Product `ReadMe.txt` first line (`LspLoad 6.11   <date>`) — it consumes
  `VERSION`, not a JSON field

Do **not** bump `InnoSetup/ReadMe.txt` (`Installer Script 3.0`) for a host add.

### 5. Configure the matching **full** preset and build that row signed

| New row toolset | Packaging configure | Build preset |
|-----------------|---------------------|--------------|
| v143 and below (e.g. BRX.27, ZRX.2025) | `vs2022-full-x64` | `vs2022-full-x64-release` |
| v145+ / ARX.26 | `vs2026-full-x64` | `vs2026-full-x64-release` |
| x86 (only if asked) | `vs2022-full-win32` | `vs2022-full-win32-release` |

```powershell
cmake --preset vs2026-full-x64 --fresh
cmake --build --preset vs2026-full-x64-release --target LspLoad_ARX_26_x64
```

Replace the preset/target for the new row. CMake target = `LspLoad_` + `id`
with `.` → `_` (see `cmake/LspLoadTargets.cmake`). Full presets set
`LSPLOAD_SIGN=ON`. Do **not** leave `LSPLOAD_SIGN=OFF`.

`*-dev-*` (`vs2022-dev-x64`, `vs2022-dev-win32`, `vs2026-dev-x64`) is unsigned
iteration only. **Do not** run `-Official` after a `*-dev-*` build.
`package-zips.ps1` harvests **only**:

- `build/vs2022-full-x64/out/Release/`
- `build/vs2022-full-win32/out/Release/`
- `build/vs2026-full-x64/out/Release/`

Never glob `**/Release/`. Never harvest `*-dev-*`.

**Do not pass `-RequireAllShip`** on a normal host-add (that flag means every
`ship: true` PE was rebuilt this run — a rebuild-all lab job).

### 6. Confirm PE path and Authenticode

Expected: `build/<full-preset>/out/Release/<outputName><ext>`.

Worked: `build/vs2026-full-x64/out/Release/LspLoad.ARX.26.x64.arx`.
New AutoCAD placeholder: `LspLoad.ARX.<major>.x64.arx`.

Authenticode must be `Valid` unless the operator explicitly chose
`LSPLOAD_SIGN=OFF` (not for `-Official`).

### 7. ZRXCheck

Do **not** run SDK `ZRXCheck.exe`. Historic Win32 ZRXCheck (2014/2015)
access-violates and overwrites the stub. CMake does not invoke it.

### 8. Package (only zipper)

```powershell
pwsh -File scripts/package-zips.ps1 -Official
```

That script harvests this row from the matching `full-*` `out/Release/`,
overlays rolling `gold/` for the rest, fills lab `InnoSetup/LspLoad/` (not
packed), writes `dist/LspLoad.zip` (PE), `dist/LspLoadSource.zip`, and
`dist/LispPluginSetup.zip` (kit sources + `generated/` only — **no PE**),
and `dist/SHA256SUMS.txt` (`rebuilt` vs `reused-gold`), **then refreshes
`gold/`** from `dist/LspLoad.zip`.

No parallel copy step. Do not run WinZip. Do not pass `-RequireAllShip`.

Git/lab keeps `SignTool=manusoft`, `scripts/sign-files.ps1`, and
`InnoSetup/SignLispFiles.bat`. Public zips must not. PIN env names only
(`SIGN_STORE_PASSWORD` / `SIGN_PIN` / `YUBIKEY_PIN`) — **never** write a PIN
into this skill or the tree.

### 9. Lab ISCC smoke (if `ISCC` exists)

Compile **git** `InnoSetup/MyLispPlugin.iss` **with** `SignTool=manusoft`
(signed `MyLispPluginSetup.exe`, Authenticode Valid). That exe is **not**
packed. Assert `LispPluginSetup.zip` `.iss` has no `SignTool=`, no PE, and
the kit / source zips contain no `sign-files.ps1` / `SignLispFiles.bat` /
`#Sign.bat` / `.agents`.

### 10. Capture lessons

Append anything newly learned (SDK env, registry mapping, toolset, defines,
clone pitfalls) to **this** `SKILL.md`. Delete contradictions. Skip if nothing
new.

### 11. Commit

Only if the user asked. Include `hosts/hosts.json`, `VERSION`, product
`ReadMe.txt`, **and the sync output** (`cmake/LspLoadHosts.cmake`,
`InnoSetup/generated/HostsFiles.iss`, `InnoSetup/generated/HostsCode.iss`,
`docs/HOSTS.md`). First GRX also includes the `validate-hosts.ps1` freeze
change. Never commit hand-edits of generated files.

Suggested message:

```text
feat: <AutoCAD 20xx / BricsCAD Vn / ZWCAD 20xx> via hosts.json

LspLoad <new VERSION>. New x64 row; package-zips -Official (no -RequireAllShip).
```

## Platform notes

### AutoCAD (ARX)

- `id` = `ARX.<major>[.x64]`; filename uses major, **not** year.
- SDK env is often `ARX<year>` (`ARX2027` for major 26).
- Registry: `Software\Autodesk\AutoCAD\R<major>.<minor>` + `CurVer` +
  `\<ProductKey>\Applications`. Several years may share one module
  (`R24.0`–`R24.3` → one `ARX.24` binary) — extra probes, same DestName.
- x64 from ARX 17; x86 ended after 23 in this product. New hosts: x64-only.
- `src/LspLoad.cpp`: local `ads_queueexpr` when `_ACADTARGET < 18`; ACHAR
  typedef when `_ACADTARGET <= 16`.
- **ARX.26 toolset is v145**; packaging configure is `vs2026-full-x64`.
- Still `_ACADTARGET` only (no `_ARXTARGET`).

### BricsCAD (BRX)

- `id` = `BRX.<ver>[.x64]`; env `BRX27`; libs `BRX27.lib`; includes `Inc64` +
  `Inc`; `sdkLib` `Lib64`.
- `_ACADTARGET` is a **compatibility** value (26 on BRX.27), not the BricsCAD
  major. Do not add `_BRXTARGET` unless the stub starts needing it.
- Registry: `Software\Bricsys\Bricscad\V27x64`, value `CURVER` (not `CurVer`).
- **BRX.27 stays `v143`** / vs2022. Do not bump it to v145 with ARX.26.

### ZWCAD (ZRX)

- Calendar year in `id` and filename; `_ZRXTARGET` is a **short** code (`25`
  for 2025) plus `_ACADTARGET` compatibility.
- Must use `src/ZrxExports.def` and `_ZRXTARGET` so `LspLoad.cpp` remaps
  `acrxEntryPoint` → `zcrxEntryPoint` / `ads_queueexpr` → `zds_queueexpr`.
- Years can skip (2016 absent; 2024 unshipped). Extra probes on neighbor years
  are how 2024 / 2026 still install. **Never** write a Loader that names a
  year with no shipped PE (the old ISS ZRX.2026 DestName bug).

### GstarCAD (GRX)

Scaffolding is in v1: `family: GRX` in `hosts/hosts.json`, `src/GrxExports.def`
(`gcrxEntryPoint`, `gcrxGetApiVersion`), `_GRXTARGET` remap in `src/LspLoad.cpp`
(entry point only — collect extra remaps such as queueexpr from the SDK; do
not invent them). **No** `ship: true` GRX row until this skill adds one with a
real SDK **and** the validator freeze is relaxed.

- Calendar-year ids (`GRX.2027.x64` is an OpenDCL pattern — confirm).
- Env example `GRX2027` is **unverified** until the operator provides it.
- Registry: OpenDCL uses `SOFTWARE\GstarSoft\GstarCAD\R{year-2000}...` /
  `Gstarsoft\GstarCAD\R...` (casing quirks). **Unverified for LspLoad.**
  Operator supplies probes; **refuse guessed keys.**
- `scripts/validate-hosts.ps1` currently errors on any GRX `targets[]` row
  (`GRX family must have zero targets`) and on any `ship: true` GRX row
  (`GRX ship:true is not allowed`). The first real GRX add **must change
  both checks** in the same commit as the JSON row. After that, `ship: true`
  remains allowed only for a real SDK+probes row.
- `ship: true` only after those probes + SDK directory exist. No fourth zip;
  the PE joins `LspLoad.zip`.

## Out of skill scope

- Porting `src/LspLoad.cpp` for API breaks beyond compile blockers.
- Copyright year / Inno LEGAL NOTICE edits.
- Publishing zips or `freebies.json` to manusoft.com.
- Inventing GRX registry keys or shipping a `.grx` without a real SDK row.
- Cloning `.vcxproj`, WiX, RxInstall, or OpenDCL VI trees.
- Creating or publishing a GitHub repository.
- Passing `-RequireAllShip` on a host-add.
- Writing PIN/PUK/passwords into files.

## Quick verification checklist

- [ ] Inputs collected: family, marketing, **asked** matrix version, x64,
      `sdkEnv` set to a real dir, clone source, probes, toolset, defines
      (incl. ZRX short `_ZRXTARGET` / BRX `_ACADTARGET` compat)
- [ ] `hosts/hosts.json` row; no `productVersion`; no Loader on probes
- [ ] First GRX: `scripts/validate-hosts.ps1` zero-target / zero-ship freeze
      lifted in the same change (still no invented keys; `ship: true` only
      with a real SDK row)
- [ ] `scripts/sync-from-hosts.ps1` + `scripts/validate-hosts.ps1`
- [ ] Generated files committed with the JSON (never hand-edited):
      `cmake/LspLoadHosts.cmake`, `InnoSetup/generated/*`, `docs/HOSTS.md`
- [ ] `VERSION` + product `ReadMe.txt` bumped; Inno kit header **not** bumped
- [ ] Matching **full** preset `--fresh` (not `*-dev-*`); Release; signed
- [ ] PE name = `outputName`+`ext` under `build/<full-preset>/out/Release/`
- [ ] `pwsh -File scripts/package-zips.ps1 -Official` (**no** `-RequireAllShip`)
- [ ] `dist/SHA256SUMS.txt` shows the new PE as `rebuilt`; others may be
      `reused-gold`
- [ ] If `ISCC` present: git `.iss` signed smoke; zipped `.iss` has no `SignTool=`
- [ ] This skill updated if lessons were learned
- [ ] Commit only if asked

## Lessons

(none yet — first real host-add fills this)
