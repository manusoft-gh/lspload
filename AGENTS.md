# AGENTS.md — LspLoad

Maintainer/agent notes for this repository.

Product version is the single line in `VERSION`. Do not invent a second
version field (including inside `hosts.json`).

After any `hosts.json` edit, run `pwsh -File scripts/sync-from-hosts.ps1`
then `validate-hosts.ps1` **before** `cmake --preset …`. CMake does not parse
JSON; it includes generated `cmake/LspLoadHosts.cmake`. Do not hand-edit that
file. Do not emit Inno fragments from sync (separate PR).

## Skill (later)

`/add-runtime-target` will live at
[`.agents/skills/add-runtime-target/SKILL.md`](.agents/skills/add-runtime-target/SKILL.md).
That skill is not in this bootstrap commit.

Until it lands: do not guess ObjectARX major from AutoCAD marketing year; do
not add CMake/Inno/signing/skills unless the current task asks for them; never
write PIN/PUK/passwords into the tree.

Gold 6.10 PE names (floor) are listed in `docs/gold/LspLoad-6.10-names.txt`.
