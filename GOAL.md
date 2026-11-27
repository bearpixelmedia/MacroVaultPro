# MacroVaultPro — goal and state

**Goal:** MacroVaultPro reaches CurseForge with a Maker that has been seen working in
game — published on the owner's word, never on a guess.

This file is the state of record for MacroVaultPro. The `bmp-goal` skill still lists
these four rows itself, so there are two copies and they can disagree — when they do,
**this file wins**; the skill's copy is the stale one. Rows move here, never back. A chat
that moves a row edits it here, and while the skill still lists that row it says in its
final message that the skill's copy is now stale. Project facts — commands, install
path, settled decisions, machine limits — stay in `AGENTS.md` and are not repeated here.

## Status — one chat moves one row

| Workstream | State | Blocked by |
|---|---|---|
| Maker | Code done, harness green — **unverified in game** | owner at the keyboard |
| 1.0.3 local install | Done — 1.0.3.18, build stamp `[2026-11-27z]`, 6 files hash-verified, **not uploaded** | — |
| One Button Pad 0.1.0 | Separate addon, code done, harness green — **unverified in game**, installed locally | owner at the keyboard |
| 1.0.3 listing copy | Not started — `media-kit/curseforge-*` still read 1.0.2 | the in-game Maker check |
| 1.0.3 CurseForge upload | Blocked | the in-game Maker check, then the listing copy, then the owner's `-Upload` |

Already live and byte-identical to `dist/`: file 9810929 (1.0.1), 9837232 (1.0.2).

Update a row in the same turn you move it. Only the owner clears a blocker, and a
chat never starts blocked work twice.
