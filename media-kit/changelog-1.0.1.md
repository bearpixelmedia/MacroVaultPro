# MacroVaultPro 1.0.1

For World of Warcraft: Forever (interface 16001), build 2026-11-25e.

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
