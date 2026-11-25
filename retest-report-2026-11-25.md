# MacroVaultPro retest - 2026-11-25

Build under test: `1f69ee2` / `MacroVaultPro 1.0.0` / stamp `2026-11-25d` / interface 16001
Machine: the user's Windows desktop. Client: Forever, `D:\World of Warcraft\_forever_\Wow.exe` (pid 8984, running).
Addon install path: `D:\World of Warcraft\_forever_\Interface\AddOns\MacroVaultPro`
SavedVariables: `D:\World of Warcraft\_forever_\WTF\Account\PULLEY\SavedVariables\MacroVaultPro.lua`

## Step 0 - build under test: FAIL on arrival, then fixed

The addon installed on disk was **not** this build. It was dated 2026-11-24 01:20 and came from
`...\Interface\AddOns\_zips\MacroVaultPro-main.zip` (2026-11-24 01:19), i.e. a GitHub main snapshot
downloaded before the rename cleanup, the `.toc` change and the error window.

Evidence it was stale:

| Check | Installed (before) | This build |
| --- | --- | --- |
| `Core.lua` size | 25,941 | 39,096 |
| `MV.BUILD` line | absent | `MV.BUILD = "2026-11-25d"` |
| `.toc` interface | `## Interface: 16001, 120105` | `## Interface: 16001` |
| `UI.lua` size | 36,295 | 56,982 |
| `BuildErrorWindow` / `ShowErrorLog` / `CopyErrorLog` in `UI.lua` | 0 matches | 5 matches |

A test run against that copy would have measured the November 24 addon, not the one being shipped.

Fix applied: the old folder was copied to
`D:\World of Warcraft\_forever_\_mvpro-backup-2026-11-25-064621` (5 files) and
`dist\MacroVaultPro-1.0.0.zip` was extracted over
`...\Interface\AddOns\MacroVaultPro`. SHA-1 of the installed files now matches the zip exactly:

```
Core.lua            d81949a64bc868abc3f5730d9bf68a20eb0ab89d
Library.lua         3dc12f4d5825ff171c4371f282f513e41887514a
UI.lua              c5a246becb1a73c85726bfca3a2c47cee8d453ef
MacroVaultPro.toc   e263b8ddc08d088f66a9df6885831fcf8e2147df
Media\icon.tga      4654afc2d4a7e3e1994eb06bd808d000eb4e706d
```

Step 0 status: **PASS** - the files on disk are now this build. Still required before any in-game
check: a `/reload` (or client restart), because the running client has the Nov 24 files in memory.

### The reappearing `MacroVault` folder (2026-11-25 04:59)

A pre-rename `MacroVault` folder sits beside the addon. It owns `SlashCmdList["MACROVAULT"]` and
`MacroVaultDB`, so it does not collide with `/mvpro` or `MacroVaultProDB`, and it does not affect
the checks below. It cannot be removed by deleting the folder, because CurseForge put it there.

CurseForge tracks one addon in this instance: name `MacroVaultPro`, project **1827533**, slug
`macrovaultpro`, installed file **9785860**, module folder **`MacroVault`**. Its cached copy at
`%APPDATA%\CurseForge\agent\FileCache\1827533\9785860.zip` is timestamped 2026-11-25 04:59:35,
the same second the folder was created, so the agent re-extracts it whenever it finds the folder
missing. Unwrapped, that cached file contains `MacroVault/Core.lua`, `MacroVault/Library.lua`,
`MacroVault/UI.lua`, `MacroVault/Media/icon.tga` and `MacroVault/MacroVault.toc` reading
`## Interface: 16001, 120105` with title `MacroVault` - the pre-rename build, 19,584-byte `Core.lua`,
no `MV.BUILD`, no error window. The CurseForge project already has this file uploaded
(2026-11-24T05:21Z) and marks it `isCompatibleWithClient: false`.

Removing it properly means deleting the addon inside CurseForge (which drops the database record),
not deleting the folder in Explorer. Until the project has a file whose root folder is
`MacroVaultPro/`, a fresh install from the site will keep producing `MacroVault/`.

## SavedVariables at the start of the test

The log was empty, so the window has nothing to scroll:

```lua
MacroVaultProDB = {
["tab"] = "library",
["position"] = { ... },
["errors"] = { },
["otherErrors"] = { },
["perCharacter"] = false,
}
```

Expected window text in this state, and the summary line that must match it:

- summary: `0 own, 0 unattributed`
- body line 1: `MacroVaultPro 1.0.0  build 2026-11-25d  client <x> (build <n>)  interface 16001`
- body line 2: `nothing logged.`

## Steps 1-5 - BLOCKED: nobody is at the keyboard

These need a person in the game window. The agent that ran Step 0 can read files and the clipboard
but cannot see or drive the WoW window, so every line below is **UNSEEN**, not passing. Nothing has
been tested in game yet.

| Check | Status |
| --- | --- |
| `/mvpro selftest` shows `[2026-11-25d]` | UNSEEN |
| `/mvpro errors` opens a window instead of dumping into chat | UNSEEN |
| Summary counts match the saved file | UNSEEN |
| Body scrolls and is read-only | UNSEEN |
| Copy changes the hint to `Selected - press Ctrl+C to copy` | UNSEEN |
| Ctrl+C puts the whole log, last entry included, on the clipboard | UNSEEN |
| ESC closes the window | UNSEEN |
| Dragging moves the window and it stays on screen | UNSEEN |
| Clear log prints `error log cleared.` and refreshes the open window | UNSEEN |

Clipboard baseline captured before the test: 5,404 bytes / 91 lines (the retest brief itself), so any
WoW copy replaces it visibly.

## What the Step 0 pass does establish

- The shipped zip and the files the client will load are byte-identical.
- The error window code is present in the loaded build, so `/mvpro errors` cannot silently fall back
  to the chat path on a missing UI function.
- The saved log is empty, so the first run of `/mvpro errors` should show `nothing logged.`; seeing
  anything else means the counts or the empty branch disagree with the file above.

## 1.0.1 release verification (2026-11-25, later the same day)

Build under test for this section: `MacroVaultPro 1.0.1` / stamp `2026-11-25e` / interface 16001,
from `dist/MacroVaultPro-1.0.1.zip` (38,510 bytes).

### Staged and installed

`tools/release.ps1 -Version 1.0.1 -NoUpload` reported:

| Item | Value |
| --- | --- |
| version | `1.0.0 -> 1.0.1` |
| build stamp | `2026-11-25d -> 2026-11-25e` |
| changelog | `media-kit/changelog-1.0.1.md`, 9 entries from `release-notes.md` |
| archive | 5 files, 38,510 bytes |
| install | `install.ps1` verified 5 files, every hash matches the archive |
| installed build | `MacroVaultPro 1.0.1 [2026-11-25e]  interface 16001` |

### Published

| Fact | Value |
| --- | --- |
| CurseForge file id | **9810929** |
| file name | `MacroVaultPro-1.0.1.zip` |
| flavour / game version | Forever, 1.60.1 (game version id 17053, type 88568) |
| release type | Release |
| approval | approved (`status: 4`), page loads at `.../files/9810929` |
| duplicate file | **9811070** - rejected by CurseForge: "File is a duplicate of file #9810929" |

### Byte check: the live file is the tested build

Downloaded from the CDN and hashed against the local archive:

```
url           https://mediafilez.forgecdn.net/files/9810/929/MacroVaultPro-1.0.1.zip  (HTTP 200)
size          38,510 bytes both sides
sha256 live   710B2307AEF44576AC415A156BD51EEC96BCC894D47087663175183A342509AA
sha256 local  710B2307AEF44576AC415A156BD51EEC96BCC894D47087663175183A342509AA
verdict       IDENTICAL
```

`edge.forgecdn.net` served the same 38,510 bytes. The site's `/download/9810929` route answers 403 to
non-browser clients, so the CDN path is the one used here. Installed files, `dist/` archive, uploaded
bytes and public download are therefore all the same bytes.

### For the record: the 404 was review latency

Immediately after the upload the file page returned 404 and the public Files tab still listed only
the older 78.1 KB `MacroVault` file, so the upload was called unconfirmed and re-run. That second
upload became 9811070 and was rejected as a duplicate of 9810929, which had in fact been approved.
`tools/upload-curseforge.ps1` now reports `live` / `pending` / `blocked` from the site's file record
instead of the page, and `-VerifyId <id>` runs that check without uploading anything.

### In-game checks for 1.0.1: still UNSEEN

Nothing in this section was seen in the client. Against stamp `2026-11-25e`, all of these remain
**UNSEEN**:

| Check | Status |
| --- | --- |
| `/mvpro selftest` shows `[2026-11-25e]` | UNSEEN |
| `/mvpro errors` assembles the block and shows the window, not chat | UNSEEN |
| Summary reads `0 own, 0 unattributed`, body `nothing logged.` | UNSEEN |
| Copy selects the whole block and changes the hint | UNSEEN |
| Ctrl+C, then paste into Notepad reproduces the block | UNSEEN |
| Clear log prints `error log cleared.` and rebuilds the open window | UNSEEN |
| Undo writes back the layout from before the last clear or move | UNSEEN |
| Dragging works through both paths the client reports | UNSEEN |
| Minimap button opens the window; drag saves an angle; right-click resets | UNSEEN |

Same caveat as Steps 1-5: these need someone at the keyboard. Byte-identical archives prove the
right build shipped, not that it behaves.
