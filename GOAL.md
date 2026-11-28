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
| 1.0.3.27 local build | Built and installed — carries the taint repair (the chat fallback refuses in combat) on top of 1.0.3.26's status-line work; `dist/MacroVaultPro-1.0.3.27.zip` is byte-identical to the installed copy, and the installed `Core.lua` was read back from the AddOns folder to confirm the guard is in the file the client loads; **waiting on the owner's in-game check** | the owner's reload |
| Sheet tab — taint verdict | **No taint can originate from this addon, so none from the Sheet tab.** Nothing under `MacroVaultPro/` touches the secure system: no `SecureActionButtonTemplate`, `SetAttribute`, `hooksecurefunc`, `SecureHandler*`, `SecureCmdOptionParse` or `issecure`, and no action-bar or protected API (`PlaceAction`, `PickupAction`, `UseAction`, `ActionButton*`, `SetBinding`, `PickupSpell`/`PickupItem`). The sheet's slot scripts (`UI.lua:1930-1993`) only read the addon's own table, draw its tooltip and set its own status line. Every macro write is refused in combat by `MV:EditBlocked` (`Core.lua:581`) and pcall-wrapped (`Core.lua:591`, `624`, `655`), and the harness asserts that nothing reaches the client in combat. The single client-owned frame the addon writes is the chat box in the Tools fallback (`Core.lua:699-716`); it now refuses in combat (`Core.lua:705`) and still puts a half-typed line back, both pinned in `tests/maker/check.js:698` and `:701`. The red text on the Sheet screenshot is the client's, not the addon's: no addon frame is anchored at the screen's top-left — every frame is a child of the window, the minimap button, the drag ghost or a centred dialog — and that string exists nowhere in the code; the only `taint` string is the tool that turns the client's own taint log on (`Library.lua:96-99`). The repair ships in the installed 1.0.3.27: the `Core.lua` under `Interface\AddOns\MacroVaultPro` was read back and carries the guard at `Core.lua:705`, so this verdict holds for the bytes the client loads, not only for the repo | — |
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
