# MacroVaultPro — project facts

**Goal and workstream state live in `GOAL.md`, at the root of this repo** — the
`bmp-goal` skill sends every chat there and still lists the same four rows itself, so
there are two copies and they can disagree; when they do, `GOAL.md` wins and the
skill's copy is the stale one. Read it first. Nothing about state belongs in this
file: when a MacroVaultPro row moves, edit its row in `GOAL.md` in that same turn, and
say in your final message if the skill's copy now disagrees.

## Local to this project

- Only `MacroVaultPro/` ships. `dist/MacroVaultPro-<version>.zip` is the artifact
  uploaded to CurseForge; `media-kit/build/` never goes in it.
- Rebuild: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/package.ps1`;
  release: `tools/release.ps1 -Version <v>`; install into the client:
  `tools/install.ps1` (target `D:\World of Warcraft\_forever_\Interface\AddOns`).
- Changelog text comes only from `## <version>` sections in
  `media-kit/release-notes.md` — never written fresh.
- Publishing needs `-Upload` on `tools/release.ps1` **and** the owner's explicit
  word. The token in `.curseforge-token` is never printed, echoed or committed.
- Never claim in-game behaviour that was not seen in game; describe the mechanism
  and say it is unseen.
- Every change is committed and pushed to `main`, no AI attribution footer.
- Maker checks live in the repo: `bun install` once, then `bun run test:maker`.
  `tests/maker/check.js` loads `Core.lua` and `UI.lua` against stubs — it never
  touches the client, and a failure there is not a substitute for the in-game check.
- Machine limits: no WoW client, Lua, Node or Python — Bun with fengari/luaparse
  for the test harnesses.

## Where the rest lives

| Need | Read |
| --- | --- |
| What the addon does, install, rebuild commands | `README.md` |
| Maker API, `Diag`, version and build stamp | `MacroVaultPro/Core.lua` |
| Maker tab, drag paths | `MacroVaultPro/UI.lua` |
| Upload checklist | `media-kit/README.md` |
| Release, install, upload scripts | `tools/` |

## Decisions already made — do not revisit

- A game macro cannot call another macro, so the Maker **composes** ordered steps
  into one body (`#showtooltip` + lines), capped at 255 characters, shown and
  counted live.
- Rebuilding edits the same slot (`maker.macroIndex`) so bar buttons keep working.
- Steps are `{kind, value, icon}`; macros are referenced by name because slots
  renumber.
- All maker entry points are guarded by `UI:MakerRun`, and `BuildMakerPanel` is
  pcall-wrapped because `Build()` never runs twice.
- Local test installs reuse version 1.0.3 with `-Force` (stamp a → b → c); they are
  never uploaded.
