# MacroVaultPro — goal and state

**Goal:** MacroVaultPro reaches CurseForge with a Maker that has been seen working in
game — published on the owner's word, never on a guess.

This file is the state of record for MacroVaultPro, and the only copy of these rows: a
chat that moves one edits it here, in the same turn. Project facts — commands, install
path, settled decisions, machine limits — stay in `AGENTS.md` and are not repeated here.

## Status — one chat moves one row

| Workstream | State | Blocked by |
|---|---|---|
| Maker | **Verified in game by the owner**; ships as 1.0.3 | — |
| 1.0.3 release build | Done — 1.0.3, build stamp `[2026-11-27ab]`, 6 files hash-verified, preflight passed, installed locally, **uploaded as file 9861169** | — |
| One Button Pad 0.1.1 | Separate Forever One Button-only addon, Console Port stripped, harness green — **verified in game**, installed locally | — |
| 1.0.3 listing copy | Done — `media-kit/curseforge-*` read 1.0.3 with the Maker, the checklist reads 1.0.3, and the `## 1.0.3` notes cover everything since 1.0.2 | — |
| 1.0.3 CurseForge upload | **Sent 2026-11-28 — file id 9861169**, in CurseForge review, so it has no public record yet and its bytes are not verifiable | nothing to start: re-run `tools/upload-curseforge.ps1 -VerifyId 9861169` once the file is approved |

Already live and byte-identical to `dist/`: file 9810929 (1.0.1), 9837232 (1.0.2).
1.0.3 is file 9861169, uploaded 2026-11-28 from `dist/MacroVaultPro-1.0.3.zip`
(65,597 bytes) — in review, not live yet, so do not call it published until
`-VerifyId 9861169` prints `live` and `IDENTICAL`.

Update a row in the same turn you move it. Only the owner clears a blocker, and a
chat never starts blocked work twice.
