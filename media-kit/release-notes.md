# Release notes

Player-facing notes, one `## <version>` section per release.
`tools/release.ps1` copies the section for the version being released into
`media-kit/changelog-<version>.md`, which is the changelog CurseForge shows on
the file page.

Write these for someone who uses the addon, not for someone reading the diff:
what it does now, and what changed for them. One bullet per thing. Keep the
multi-line continuation indent — it renders as one bullet.

## 1.0.1

- **The error log is a window now.** `/mvpro errors` opens a small read-only
  list of every error MacroVaultPro has caught, newest first, with the time and
  the message for each. It no longer pours into the chat frame, so a long
  traceback is not cut off before you can read it.
- **Copy the whole log.** The Copy button selects all of it — header, counts and
  every entry — so one Ctrl+C puts the complete log on the clipboard for a bug
  report. The client has no clipboard call of its own, which is why it selects
  the text rather than copying it.
- **Errors from load are caught too.** Anything raised while the addon is still
  loading is kept, not just errors after login, and errors whose traceback names
  no addon are listed separately instead of being mixed in with ours.
- **`/mvpro diag`** prints one block you can paste into a report: build stamp,
  client build, which drag events the client offers, the minimap size, the
  detected account/character split, and how many drags each path has handled
  since you logged in.
- **Sheet can undo.** The Sheet tab has an Undo button that takes back the last
  move or clear of an icon slot, one step.
- **Dragging works on more clients.** Drag and drop now runs through both ways
  the client reports a drag, instead of relying on the one it used before.
- **Minimap button.** Drag it around the edge of the map and it remembers where
  you put it; `/mvpro minimap` hides or shows it, and the choice is saved.
- **Forever only.** The `.toc` now declares just Forever's interface, so the
  addon list no longer claims support for clients it was never tested on.
