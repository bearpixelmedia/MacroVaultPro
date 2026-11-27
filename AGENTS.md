# MacroVaultPro — the goal every chat here serves

**Goal:** MacroVaultPro reaches CurseForge with a Maker that has been seen working
in game — published on the owner's word, never on a guess.

This file is the context. Every chat in this project reads it automatically, so
state, versions, paths and settled decisions never need pasting again. When a chat
learns a fact that belongs here, it updates this file in the same turn.

## State — one chat moves one row

| Workstream | State | Blocked by |
| --- | --- | --- |
| Maker: compose steps into one real macro | Code done, harness green — **unverified in game** | owner at the keyboard |
| Release pipeline (`-Upload` opt-in) | Done — a local build cannot publish | — |
| 1.0.3 local build + install | Done — build stamp `[2026-11-27c]`, 5 files hash-verified | — |
| In-game check of 1.0.3 | Open — panel layout, spellbook drop, row reorder, nested macro inlining | owner |
| CurseForge 1.0.3 listing copy | Not started — `media-kit/curseforge-*` still read 1.0.2 | the in-game check |
| CurseForge 1.0.3 upload | Blocked on the two rows above | owner's `-Upload` |

Already live and byte-identical to `dist/`: file 9810929 (1.0.1), 9837232 (1.0.2).

## Rules for chats

1. **One chat = one row.** Name the row you are moving in the first line. If a
   request is not a row, it is not work: say so and stop.
2. **End with evidence only** — commit sha, byte count, exit code, the pasted diag
   line — then what is still blocked. No progress narration.
3. **Blocked rows clear only through the owner.** Never start blocked work a second
   time in a new chat.
4. **Small follow-ups go into the chat that finished that row**, not a new one.
5. **Never claim in-game behaviour that was not seen in game.** Describe the
   mechanism instead, and say it is unseen.
6. **Publishing needs `-Upload` and the owner's explicit word.** The token in
   `.curseforge-token` is never printed, echoed or committed.
7. **Every change is committed and pushed to `main`**, no AI attribution footer.
8. New work: add its row to the table first, then open exactly one chat for it.

## Where the rest lives

| Need | Read |
| --- | --- |
| What the addon does, install, rebuild commands | `README.md` |
| Maker API, `Diag`, version and build stamp | `MacroVaultPro/Core.lua` |
| Maker tab, drag paths | `MacroVaultPro/UI.lua` |
| Changelog text (only `## <version>` sections) | `media-kit/release-notes.md` |
| Upload checklist | `media-kit/README.md` |
| Release, install, upload commands | `tools/release.ps1`, `tools/install.ps1`, `tools/upload-curseforge.ps1` |
| Machine limits | No WoW client, Lua, Node or Python — Bun with fengari/luaparse only |

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
