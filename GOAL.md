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
| 1.0.3.25 local build | Built and installed — the window's status bar is measured against the panes and every maker status message is checked word for word; `dist/MacroVaultPro-1.0.3.25.zip` is committed and its six files are byte-identical to the installed copy; **waiting on the owner's in-game check** | the owner's reload |
| 1.0.3 release build | Done — 1.0.3, build stamp `[2026-11-27ab]`, 6 files hash-verified, preflight passed, installed locally, **live as file 9861169** | — |
| One Button Pad 0.1.1 | Separate Forever One Button-only addon, Console Port stripped, harness green — **verified in game**, installed locally | — |
| 1.0.3 listing copy | Done — `media-kit/curseforge-*` read 1.0.3 with the Maker, the checklist reads 1.0.3, and the `## 1.0.3` notes cover everything since 1.0.2 | — |
| 1.0.3 CurseForge upload | **Live — file 9861169**, approved and public, and `-VerifyId 9861169` prints `IDENTICAL` against `dist/MacroVaultPro-1.0.3.zip` | — |
| 1.0.3 description on the live page | **Behind — the page still shows the 1.0.0 text**: no Maker section, `Version 1.0.0 — first release`, and no gallery-disclosure paragraph, which the panels need while they are still renderings; the live summary is the studio line, not the kit's 118-character one. The 1.0.3 copy is ready in `media-kit/curseforge-description.html` and carries the site and `hello@bearpixelmedia.com` | **the owner pasting it themselves** — the API has no description endpoint and no chat has an author session for this project. The owner has the text and will say when it is on the page; until then, do not re-read the live page to check |

Already live and byte-identical to `dist/`: file 9810929 (1.0.1), 9837232 (1.0.2),
9861169 (1.0.3, 65,597 bytes, sha256 `182BFB181A7D01551786F0A75274BE00D0F7A23754972A22F4DD5BC9A47489DE`,
checked with `-VerifyId 9861169` after it went public).

Update a row in the same turn you move it. Only the owner clears a blocker, and a
chat never starts blocked work twice.
