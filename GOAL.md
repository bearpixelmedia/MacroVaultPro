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
| 1.0.3.26 local build | Built and installed — every tab's status message is pinned word for word and each must stay within two lines above the panes; `dist/MacroVaultPro-1.0.3.26.zip` is committed and its six files are byte-identical to the installed copy; **waiting on the owner's in-game check** | the owner's reload |
| 1.0.3 release build | Done — 1.0.3, build stamp `[2026-11-27ab]`, 6 files hash-verified, preflight passed, installed locally, **live as file 9861169** | — |
| One Button Pad 0.1.1 | Separate Forever One Button-only addon, Console Port stripped, harness green — **verified in game**, installed locally | — |
| 1.0.3 listing copy | Done — `media-kit/curseforge-*` read 1.0.3 with the Maker, the checklist reads 1.0.3, and the `## 1.0.3` notes cover everything since 1.0.2 | — |
| 1.0.3 CurseForge upload | **Live — file 9861169**, approved and public, and `-VerifyId 9861169` prints `IDENTICAL` against `dist/MacroVaultPro-1.0.3.zip` | — |
| 1.0.3 description on the live page | **Done — the page carries the 1.0.3 copy**, read once in the browser after the owner pasted it: the 118-character summary, the Maker section, `Version 1.0.3`, the gallery disclosure (`not in-game screenshots`), the site link and a `mailto:hello@bearpixelmedia.com` link. The old `Version 1.0.0` line, the studio summary and `See the Images tab for the full set of panels` are gone | — |

Already live and byte-identical to `dist/`: file 9810929 (1.0.1), 9837232 (1.0.2),
9861169 (1.0.3, 65,597 bytes, sha256 `182BFB181A7D01551786F0A75274BE00D0F7A23754972A22F4DD5BC9A47489DE`,
checked with `-VerifyId 9861169` after it went public).

Seen in game 2026-11-28, from the owner's six screenshots: every tab renders —
**My macros** with `account 1/120  character 0/30`, `Account macro · slot 1 ·
195 characters`, `BODY (195/255)` and its four buttons; **Maker** with
`SEQUENCE 0/12`, `0 / 255`, the `target`/`combat`/`10s` reset toggles and
`Runs: priority`; **Tools** with all twelve entries and their commands; **Library**
`26` with group tags and `MACRO TEXT (32/255)`; the **editor** with `0 / 255` and
its four buttons; **Sheet** `0/36` with the 6×6 grid, **Save layout** and
**Undo**. Every label sat inside its card and the status bar was one line on each.
The shots carry no version stamp — the build is inferred from the install being
byte-identical to HEAD, 1.0.3.26 — and none of them shows an interaction or the
two-line status case 1.0.3.26 changed, so the checklist's interaction items are
still unticked and that row still waits on the owner.

Update a row in the same turn you move it. Only the owner clears a blocker, and a
chat never starts blocked work twice.
