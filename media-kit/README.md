# MacroVaultPro — CurseForge media kit

Everything the CurseForge project page needs, in the sizes CurseForge asks for.

| File | Size | Where it goes |
| --- | --- | --- |
| `images/avatar-400.png` | 400 × 400 | Project avatar (the file CurseForge requests) |
| `images/avatar-1024.png` | 1024 × 1024 | Large master copy of the same art |
| `images/banner-1280x400.png` | 1280 × 400 | Description header, README, social posts |
| `images/gallery-01-macros.png` | 1280 × 720 | Images tab, slide 1 |
| `images/gallery-02-library.png` | 1280 × 720 | Images tab, slide 2 |
| `images/gallery-03-tools.png` | 1280 × 720 | Images tab, slide 3 |
| `images/gallery-04-forever.png` | 1280 × 720 | Images tab, slide 4 |
| `images/icon-64.png` | 64 × 64 | Same art as the in-game addon-list icon, as a PNG preview |
| `curseforge-listing.md` | — | Name, summary, categories, tags, gallery captions |
| `curseforge-description.html` | — | The project description body, paste-ready HTML |
| `curseforge-description.md` | — | The same description as Markdown |
| `release-notes.md` | — | Player-facing notes per version; `tools/release.ps1` turns the section for a version into that version's changelog |

## Upload checklist

1. **Project name** `MacroVaultPro`, slug `macrovaultpro` — check it is still free.
2. **Summary** — paste the 118-character line from `curseforge-listing.md`.
3. **Avatar** — upload `images/avatar-400.png`. Square, original art, no game logo, no text.
4. **Description** — put the editor in HTML mode and paste
   `curseforge-description.html`. CurseForge's rich editor drops Markdown tables
   and mangles pipe characters, so the HTML version is the one to use; its tables
   come through as real tables. `curseforge-description.md` is the same text for
   anywhere that takes Markdown.
5. **Images tab** — upload the four gallery panels in order with the captions from
   `curseforge-listing.md`, and enable the carousel.
6. **Game version** — Forever (interface 16001); file version `1.0.2`, release type
   `Release`, changelog from the version's section in `release-notes.md`.
7. Add the banner at the top of the description if you want a header image.

## CurseForge pre-flight

Run through this before any file goes up. Each line is a moderation rule, not a
style preference.

- [ ] **Avatar** — `images/avatar-400.png`, exactly **400 × 400**, PNG. Not webp (the
      site has a known bug with it), not a solid colour, no game logo or borrowed art.
- [ ] **Changelog** — `release-notes.md` has a `## <version>` section for the build being
      uploaded. `tools/release.ps1` turns it into `changelog-<version>.md` and refuses to
      package without it; every file must describe what changed from the last one.
- [ ] **Name** — the project name and the file display name carry no game name, class
      name or version number. `MacroVaultPro` is fine; `MacroVaultPro-WoW-1.0.1` is not.
      Technical detail belongs in the description or the file tags.
- [ ] **Gallery disclosure** — if the panels are still the HTML renderings, the
      description's Gallery paragraph must say they are not in-game screenshots.
- [ ] **Summary** — the 118-character line in `curseforge-listing.md`: one sentence, and
      not the description's opening line copied across.
- [ ] **One upload per build** — a second upload of the same archive is rejected as a
      duplicate (file 9811070 was) and counts against the fair-play rule.

Rows one to five are enforced by `tools/preflight.ps1`, which `tools/release.ps1` runs
before it writes anything; the duplicate row is enforced by `tools/upload-curseforge.ps1`,
which hashes every published file that is the same size as the archive — or whose listing
carries no readable size, so an incomplete listing cannot hide one — and refuses an archive
whose SHA-256 is already on the project, whatever it happens to be called.

## Checking a published file

`tools/upload-curseforge.ps1 -VerifyId <file id>` loads the id's public record and prints `live`,
`pending`, `blocked` or `unknown`. `live` means the site returns the file with its name, size and
approval status 4; `pending` means the id has no public record yet (still in review, or rejected).
It needs no token and uploads nothing, so it is safe to run against any id — for example
`-VerifyId 9810929` for the 1.0.1 archive. It is the same check a real upload prints afterwards,
which is why the file page's own 404 is not used: Cloudflare answers 403 to non-browser clients.
It exits 0 only after the published bytes matched a build in `dist/`; 1 means they differ, or
nothing was there to compare them with; 2 means the id could not be checked at all, which is not a
pass. When `tools/release.ps1` is run with `-Upload`, it runs this check on the file it just
uploaded, so a release ends only with a hash match against `dist/`; a file still in review stops it
with the id to re-check. Without `-Upload` the release builds and installs and publishes nothing.

## About the gallery images

The four gallery panels are graphic feature cards, not in-game screenshots — no WoW
client was available while this kit was made. The description says so on the project
page, because CurseForge's moderation rules treat a showcase image that could pass for
in-game content as something that needs a visible disclaimer; keep that paragraph if the
panels stay. They are accurate about what the addon
does, but CurseForge reviewers and players both prefer real screenshots, so capture
these in game when the addon is installed and add them alongside (or in place of)
the panels:

| Shot | What to capture |
| --- | --- |
| 1 | **My macros** tab with several macros listed and one selected, search box empty |
| 2 | **Library** tab, Targeting group, with the body of a macro visible |
| 3 | **Tools** tab, showing the frame stack / `/fstack` entries |
| 4 | **Editor** tab with a macro open |
| 5 | Chat after `/mvpro selftest`, out of combat — the `detected:` and `confirmed:` lines |
| 6 | **Sheet** tab with several macros dropped into slots |
| 7 | The minimap button at the edge of the minimap, with its tooltip visible |

Shoot at 1280 × 720 (or larger, 16:9) with default UI scale, `/fstack` off, and the
rest of the UI as clean as you like it. Give each one a one-line title in the Images
tab; the captions in `curseforge-listing.md` already fit the panels and can be reused.

## Regenerating

The panels are HTML/CSS, so the text stays crisp and editable.

- Source: `build-media-kit.html` — one banner and four cards, stacked. Each tile
  is exactly 1280 px wide and its final height, so there is nothing to crop.
  Adding `#banner` or `#card1`..`#card4` to the URL shows only that tile.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File build/render.ps1`.
  That one command rebuilds every asset in this kit: it drives headless Edge to
  capture each tile at its own size, then cuts `build/avatar-source.png` at 1024,
  400 and 64 px. The 64 px cut goes two places — `images/icon-64.png` to look at,
  and the addon's own icon `../MacroVaultPro/Media/icon.tga`, because the client
  reads TGA and not PNG. `MacroVaultPro.toc` points at it with
  `## IconTexture: Interface\AddOns\MacroVaultPro\Media\icon.tga`. The run prints
  every size and re-reads the TGA header, so a malformed icon fails loudly
  instead of shipping broken.
- The avatar art is `build/avatar-source.png`; replace it and re-run to re-cut all
  four sizes. `Media/icon.tga` belongs in the addon zip; `build/` does not.

Keep `build-media-kit.html` and `build/` out of the addon zip — they belong with
the marketing assets, not in `Interface/AddOns/MacroVaultPro`.
