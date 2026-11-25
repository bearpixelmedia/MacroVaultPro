# Release notes

Player-facing notes, one `## <version>` section per release.
`tools/release.ps1` copies the section for the version being released into
`media-kit/changelog-<version>.md`, which is the changelog CurseForge shows on
the file page. This file is the only source; the per-version changelogs are
output, not something to edit.

Write these for someone who uses the addon, not for someone reading the diff:
what it does now, and what changed for them. One bullet per thing. Keep the
multi-line continuation indent — it renders as one bullet.

Only `##` belongs to a version heading, because that is what the release script
splits on. Use `###` for subsections inside a version.

Describe what the addon does, not how a client feature is expected to behave.
Anything that depends on client behaviour the addon has not been tested against
in game stays out until it has been.

## 1.0.1

- **The error log gets its own window.** `/mvpro errors` assembles the log as one
  plain-text block — the build line, both counts, then each entry with its time,
  message and traceback — and hands it to a small read-only window instead of
  printing it line by line into the chat frame, where a long traceback runs out
  of room. Chat is only the fallback for the case where that window cannot be
  built.
- **Copy takes the whole log at once.** It fills the window's text with the same
  block and selects all of it, so there is no dragging a selection across a
  traceback to build a report by hand.
- **Clear log** empties both stored logs and the entries still waiting to be
  saved, then rebuilds the window from the empty log and says so in chat.
- **Errors from load are caught too.** Anything raised while the addon is still
  loading goes into the same stores rather than being lost before the first
  frame, and errors whose traceback names no addon path are kept in a separate
  list so they are not mixed in with the addon's own.
- **`/mvpro diag`** prints one block you can paste into a report: build stamp,
  client build, which drag events the client offers, the minimap size, the
  detected account/character split, and how many drags each path has handled
  since you logged in.
- **Undo on the Sheet tab.** Before a slot is cleared or a macro is moved
  between slots, the tab takes a plain copy of the layout; **Undo** writes that
  copy back, saves it and rebuilds the slots from it. One step at a time — once
  it is used there is nothing to undo until the next change.
- **Dragging** now runs through both ways the client reports a drag, rather than
  the one it used before.
- **Minimap button.** Its position is a saved angle around the minimap, and a
  drag writes a new angle back, so nothing about where it sits is hard-coded;
  `/mvpro minimap` hides or shows the button and saves that choice as well.
- **Forever only.** The `.toc` now declares just Forever's interface, so the
  addon list no longer claims support for clients it was never tested on.

## 1.0.0

### Added

- **My macros** — every account-wide and character macro in one searchable list,
  tagged with the scope it really lives in, with the full body shown for the
  selected macro.
- **Inject, Edit, Duplicate, Macro UI** actions on the selected macro: pick it up
  for an action button, edit it in place, copy it, or open the client's macro frame.
- **Tools** — 12 entries that drive the client's own debug tools: `/fstack`
  (with and without hidden frames), `/etrace`, build info, `/api`, the macro
  window, `/reload`, script errors on and off, the taint log, and a mouseover
  frame inspector.
- **Library** — 26 ready-made macros across Targeting, Utility and Development,
  each with its body visible before you create it, plus Create and Create & pick
  up, and a toggle for account-wide or character scope.
- **Editor** — plain-text macro editing with the client's real limits applied
  (255-character bodies, 16-character names).
- **Sheet** — a list of every macro beside 36 icon slots: drag one from the list
  onto a slot, drag one slot onto another to swap the two, and right-click a slot to
  clear.
  Slots remember their macro by name and scope rather than by slot number, so the
  layout survives macros being created or deleted; a slot whose macro is gone
  stays visible with a red border. The layout is saved to `MacroVaultProDB` as
  you change it, and **Save layout** writes it again on demand. **Undo** takes
  back the last clear or move, once.
- **Slot detection** — account and character limits are read from the client
  (`MAX_*` globals, then `Constants`, then defaults), and every macro the addon
  creates records the exact scope of its own slot.
- **`/mvpro selftest`** — prints the client build, the detected slot split, your
  usage, and confirms the account/character boundary with one temporary macro per
  scope, deleted immediately. Run it out of combat.
- **`/mvpro diag`** — prints one pasteable block for a bug report: the addon's
  build stamp, the client build, whether the client exposes `RegisterForDrag`,
  `IsMouseButtonDown` and `GetMouseFocus`, the minimap size and shape, the
  detected slot split, and how many drags each drag path has started since you
  logged in — so the report says exactly which path works.
- **`/mvpro errors`** — opens the log in a small read-only window instead of
  dumping it into chat: every Lua error raised in the addon's own files,
  including ones thrown while the addon is still loading, each with its
  timestamp, message and traceback. **Copy** selects the whole log at once, and
  **Clear log** empties it. The last 20 are kept, plus up to 10 whose traceback
  carries no addon name (some clients report only short paths), and the list is
  saved in `MacroVaultProDB` so it survives a reload.
- **Minimap button** — the addon's icon sits by the minimap and opens the window.
  Drag it to walk it around the edge of the map, right-click to put it back where
  it started; where it sits is saved. `/mvpro minimap` hides or shows the button
  and remembers which you chose. Hand-rolled, so it adds no dependency.
- **Load confirmation** — one line in chat on login, so a fresh install reports
  that it loaded instead of looking inert until you type the command.
- **Saved window position** — position, last tab, default scope and the sheet
  layout persist in `MacroVaultProDB`; `/mvpro reset` forgets the position.

### Notes

- Opening the window only reads. It never creates or deletes a macro.
- No macros are created, edited or deleted in combat; the addon tells you and you
  can retry afterwards.
- No dependencies and no external libraries.
- If something misbehaves, `/mvpro errors` opens the log in a read-only window
  with a Copy button; the same entries are in
  `WTF/Account/<account>/SavedVariables/MacroVaultPro.lua` after a reload.
