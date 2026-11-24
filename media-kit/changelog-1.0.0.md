# MacroVault 1.0.0

First release, for World of Warcraft: Forever (interface 16001).

## Added

- **My macros** — every account-wide and character macro in one searchable list,
  tagged with the scope it really lives in, with the full body shown for the
  selected macro.
- **Inject, Edit, Duplicate, Macro UI** actions on the selected macro: pick it up
  for an action button, edit it in place, copy it, or open the client's macro frame.
- **Tools** — 12 entries that run the client's own slash commands: `/fstack`
  (with and without hidden frames), `/etrace`, build info, `/api`, the macro
  window, `/reload`, script errors on and off, the taint log, and a mouseover
  frame inspector.
- **Library** — 26 ready-made macros across Targeting, Utility and Development,
  each with its body visible before you create it, plus Create and Create & pick
  up, and a toggle for account-wide or character scope.
- **Editor** — plain-text macro editing with the client's real limits applied
  (255-character bodies, 16-character names).
- **Slot detection** — account and character limits are read from the client
  (`MAX_*` globals, then `Constants`, then defaults), and every macro the addon
  creates records the exact scope of its own slot.
- **`/mvault selftest`** — prints the client build, the detected slot split, your
  usage, and confirms the account/character boundary with one temporary macro per
  scope, deleted immediately. Run it out of combat.
- **Saved window position** — position, last tab and default scope persist in
  `MacroVaultDB`; `/mvault reset` forgets the position.

## Notes

- Opening the window only reads. It never creates or deletes a macro.
- No macros are created, edited or deleted in combat; the addon tells you and you
  can retry afterwards.
- No dependencies and no external libraries.
