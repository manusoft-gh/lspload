# AGENTS.md — LspLoad

Maintainer/agent notes for this repository.

Product version is the single line in `VERSION`. Do not invent a second
version field (including inside `hosts.json` when that file exists).

## Skill (later)

`/add-runtime-target` will live at
[`.agents/skills/add-runtime-target/SKILL.md`](.agents/skills/add-runtime-target/SKILL.md).
That skill is not in this bootstrap commit.

Until it lands: do not guess ObjectARX major from AutoCAD marketing year; do
not add CMake/Inno/signing/skills unless the current task asks for them; never
write PIN/PUK/passwords into the tree.

Gold 6.10 PE names (floor) are listed in `docs/gold/LspLoad-6.10-names.txt`.
