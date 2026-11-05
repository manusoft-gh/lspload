# AGENTS.md — LspLoad

Maintainer/agent notes for this repository.

Product version is the single line in `VERSION`. Do not invent a second
version field (including inside `hosts.json`). The Inno kit header
(`InnoSetup/ReadMe.txt`, Installer Script 2.1) is independent of `VERSION`.

After any `hosts.json` edit, run `pwsh -File scripts/sync-from-hosts.ps1`
then `validate-hosts.ps1` **before** `cmake --preset …`. CMake does not parse
JSON; it includes generated `cmake/LspLoadHosts.cmake`. Sync also writes
`InnoSetup/generated/HostsFiles.iss` and `HostsCode.iss`. Do not hand-edit
generated files.

## Skill

`/add-runtime-target` lives at
[`.agents/skills/add-runtime-target/SKILL.md`](.agents/skills/add-runtime-target/SKILL.md).
Git/maintainers only — `scripts/package-zips.ps1` excludes `.agents` from
`LspLoadSource.zip`.

Do not guess ObjectARX major from AutoCAD marketing year (worked example is
ARX.26 / `ARX2027` / `R26.0` / v145). New hosts default x64-only. Refuse an
unset SDK env. Never write PIN/PUK/passwords into the tree (env var names
only). `package-zips.ps1 -Official` is the only zipper; do not pass
`-RequireAllShip` on a normal host-add.

Gold 6.10 PE names (floor) are listed in `docs/gold/LspLoad-6.10-names.txt`.
