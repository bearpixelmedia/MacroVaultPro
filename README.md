# MacroVaultPro

A World of Warcraft addon for the **Forever** client (interface 16001) that puts
every macro you own in one window.

Open it with `/mvpro` or `/macrovaultpro`. The **My macros** tab lists account and
character macros together and tags each with its real scope, so you can search,
inject onto your bars, edit, duplicate, or jump to the client's own macro window.
The **Library** tab has 26 ready-made targeting, utility and developer macros you
can read before creating. The **Tools** tab runs the client's own debug tools —
`/fstack`, `/etrace`, `/api`, build info, script errors, taint log — without
typing them.

Macro slots are read from the client rather than assumed, and nothing is written
while you are in combat.

## Install

Unzip `MacroVaultPro-1.0.0.zip` into the client's `Interface/AddOns/` folder, so
the path ends up as `Interface/AddOns/MacroVaultPro/MacroVaultPro.toc`. Start the
game with no addons disabled, and the window opens from `/mvpro` or
`/macrovaultpro`.

## If something goes wrong

`/mvpro errors` prints any Lua error the addon has logged — timestamp, message
and traceback — ready to paste into a bug report. It covers errors raised in the
addon's own files, including ones thrown while it loads. The same list is saved
in `WTF/Account/<account>/SavedVariables/MacroVaultPro.lua` after a reload, and
`/mvpro errors clear` empties it.

## What lives where

| Path | What it is |
| --- | --- |
| `MacroVaultPro/` | The addon itself — the only folder that ships to players. `MacroVaultPro.toc` declares the interface, version, SavedVariables and icon; `Core.lua` holds the data layer and slash commands, `Library.lua` the 26 ready-made macros, `UI.lua` the window, and `Media/icon.tga` the addon-list icon the `.toc` points at. |
| `media-kit/` | The CurseForge listing: paste-ready description, listing copy, changelog, avatar, banner and gallery images. `media-kit/README.md` is the upload checklist. |
| `media-kit/build/` | The HTML/CSS the banner and gallery cards are rendered from, the avatar master, and `render.ps1`, which regenerates every image in the kit. Development only — never goes in the zip. |
| `tools/` | `package.ps1`, the release packager. |
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

The packager deletes older `dist/MacroVaultPro-*.zip` files, so bump
`## Version:` in the `.toc` before you build the next release.

## License

All rights reserved. See [LICENSE](LICENSE).
