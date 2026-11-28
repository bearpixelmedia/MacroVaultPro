# MacroVaultPro

A World of Warcraft addon for the **Forever** client (interface 16001) that puts
every macro you own in one window.

Open it with `/mvpro` or `/macrovaultpro`, or click the addon's icon beside the
minimap — drag that icon around the edge of the map to move it, right-click it
to put it back. `/mvpro minimap` hides or shows that icon, and the choice is
saved with the rest of the settings. The **My macros** tab lists account and character macros
together and tags each with its real scope, so you can search, pick a macro up
onto your cursor, edit it, open the editor on a copy, or jump to the client's own
macro window. The **Library**
tab has 26 ready-made targeting, utility and developer macros you can read
before creating. The **Tools** tab runs the client's own debug tools —
`/fstack`, `/etrace`, `/api`, build info, script errors, taint log — without
typing them. The **Maker** tab composes a list of spells and macros into one bar
button: drop a spell from your spellbook or click one of your own macros, order
the steps, give each spell a target and conditions, and build it as a priority
list or as one `/castsequence` with its own reset choices; **Share** writes the
whole maker as one line and loads one back. The **Sheet** tab puts the macro
list beside 36 icon slots: drag one
onto a slot, drag one slot onto another to swap the two, right-click to clear
(Undo writes back the layout from before that last clear or move); the layout is
saved with the rest of the addon's settings.

Macro slots are read from the client rather than assumed, and nothing is written
while you are in combat.

## One Button Pad

A second, separate addon ships from this repository: **One Button Pad**
(`OneButtonPad/`), built for Forever WoW alone. It reads Forever One Button's
cells and puts each one in a single window at controller size, with the chord that
presses it — including cells the grid is not showing, and cells with no key at
all. It only reads: no cell, key or setting is changed. `/obp` opens it,
`/obp report` prints the same information to chat and `/obp diag` prints which
reads answered; rebuild and install it with
`powershell -NoProfile -ExecutionPolicy Bypass -File tools/onebuttonpad.ps1`.

## Install

Unzip `MacroVaultPro-<version>.zip` into the client's `Interface/AddOns/` folder, so
the path ends up as `Interface/AddOns/MacroVaultPro/MacroVaultPro.toc`. Start the
game with no addons disabled, and the window opens from `/mvpro` or
`/macrovaultpro`.

## If something goes wrong

`/mvpro errors` assembles the log as one plain-text block — timestamp, message
and traceback for each entry — and hands it to a small read-only window, with
chat as the fallback when that window cannot be built. Its Copy button selects the
whole block and says to press Ctrl+C. It covers errors raised in the addon's own
files, including ones thrown while it loads; an error raised by another addon is
listed under its own heading, and repeats of one error fold into a single entry
with a count and the time it was last seen. The same list is saved in
`WTF/Account/<account>/SavedVariables/MacroVaultPro.lua` after a reload; the
window's Clear log button empties both stored lists and rebuilds the window. For a drag or load problem, `/mvpro diag`
prints one copyable block — build stamp, client build, which drag APIs the
client has, the minimap size and the detected slot split — so a report says
exactly which drag path works.

## What lives where

| Path | What it is |
| --- | --- |
| `MacroVaultPro/` | The addon itself — the only folder that ships to players. `MacroVaultPro.toc` declares the interface, version, SavedVariables and icon; `Core.lua` holds the data layer and slash commands, `Library.lua` the 26 ready-made macros, `Skin.lua` the client-template skin the window draws with, `UI.lua` the window, and `Media/icon.tga` the addon-list icon the `.toc` points at. |
| `OneButtonPad/` | The separate One Button Pad addon, for Forever WoW only: `Core.lua` reads Forever One Button's cells and keys, `UI.lua` draws the read-only window. It builds to its own zip and never borrows MacroVaultPro's version or saved variables. |
| `media-kit/` | The CurseForge listing: paste-ready description, listing copy, changelog, avatar, banner and gallery images. `media-kit/README.md` is the upload checklist. |
| `media-kit/build/` | The HTML/CSS the banner and gallery cards are rendered from, the avatar master, and `render.ps1`, which regenerates every image in the kit. Development only — never goes in the zip. |
| `AGENTS.md` | The project goal, the state table one chat moves one row of, and the rules for working here — read before any change. |
| `tools/` | `package.ps1` builds the archive, `install.ps1` installs it into the client and verifies it, `release.ps1` bumps the version and writes the changelog before running both, and `upload-curseforge.ps1` checks the archive and sends it to CurseForge only with `-Upload`. Nothing in `tools/` publishes without that switch. `onebuttonpad.ps1` packages One Button Pad as `dist/OneButtonPad-<version>.zip` and installs it the same way, and never uploads. |
| `dist/` | Build output: `MacroVaultPro-<version>.zip`, the file you upload. |

## Rebuilding

Two commands, both from the repository root.

**Media kit** — renders the banner, the four gallery cards, all three avatar
sizes and the addon's 64×64 TGA icon, then checks the TGA header:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File media-kit/build/render.ps1
```

**Release zip** — reads `## Version:` from the `.toc` and writes
`dist/MacroVaultPro-<version>.zip` with a single `MacroVaultPro/` root and forward-slash
entries, then verifies the archive's root, separators, `.toc` and icon path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/package.ps1
```

Older archives stay in `dist/` — `tools/upload-curseforge.ps1 -VerifyId` hashes a
live file against the build it came from — so bump `## Version:` in the `.toc`
before you build the next release; the new archive is named after the new version.

**Install for testing** — copies `dist/MacroVaultPro-<version>.zip` into
`D:\World of Warcraft\_forever_\Interface\AddOns` (pass `-AddOns` for another
install). It refuses an archive that no longer matches the source tree, deletes
the destination folder before extracting so nothing stale survives, then hashes
every installed file against the archive and re-reads the build stamp from disk:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/install.ps1
```

Run `/reload` afterwards — the script says so when the client is running. The
previous install is copied to `<install>\_addon-archive\backups\` first.

**Release** — `tools/release.ps1` chains the whole thing: it bumps the version,
writes the changelog, runs the pre-flight checks, packages and installs. It stops
there unless you pass `-Upload`; publishing is opt-in, so a build meant to stay local
cannot go up because a flag was forgotten. With `-Upload` it publishes, then downloads
the published file and compares its SHA-256 with `dist/`. A release does not finish
unless the two match; a file still in review has no public copy to hash, so it stops
with the id to re-check.

## License

All rights reserved. See [LICENSE](LICENSE).
