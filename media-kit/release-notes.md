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

## 1.0.3.17

- **Repeats of one error take one slot.** The log no longer fills up with the
  same failure over and over: the entry counts how many times it happened and
  keeps when it was last seen, so repeated mistakes still fit beside new ones.
- Duplicates already saved by an older build fold into a single entry when the
  log loads.

## 1.0.3.16

- **The error log names the addon that actually broke.** Errors raised by
  another addon are listed under their own heading now instead of being
  reported as MacroVaultPro's, and the log's own frame is no longer stored as
  part of the trace.
- Entries logged before this version stay where they are; `/mvpro errors clear`
  empties the log if the old ones are in the way.

## 1.0.3.15

- **Load asks before it replaces anything.** When the maker already holds steps,
  the first press turns `Load` into `Replace?` and the line under the box says
  how many of your steps would go. Press it again to load, or `Close` to keep
  what you have. Editing the box abandons the question, and a string that does
  not read cleanly is reported straight away without one.
- **Two more targets in the same bracket:** `@cursor` and `@none`, on a second
  line under the first four. They travel inside share strings like any other
  target - `s:Rain of Fire@cursor`.
- Clicking the lit target again still clears it. `@none` is a choice of its own
  now, so it is no longer how a target is removed.
- The target and conditions card is taller to fit the second target line.

## 1.0.3.14

- **A sequence travels as one line.** `Share` opens a box holding the whole maker
  as text - the name, the mode, the reset choices and every step with its target,
  conditions and scope:
  `MVPSEQ1|Heals|sequence|target+combat+25|s:Flash Heal@mouseover*help|m:Trinket 1#a`.
  Copy selects it for Ctrl+C; there is no clipboard API to call.
- **Loading validates before it writes.** The prefix says which build wrote the
  line, the mode must be priority or sequence, reset choices must be `target`,
  `combat`, `none` or 1-60 seconds, steps must start with `s:` or `m:`, each
  condition and target must be one this maker writes, a contradictory pair is
  refused, and a macro step cannot carry a target or conditions. One bad step
  refuses the whole line, so nothing is half-imported; the reason names the step
  and the field.
- Names are escaped, so a spell or macro containing `|`, `:`, `,`, `@`, `*`, `#`
  or `+` survives the round trip.
- A macro step normally lives in a sequence without its macro on the other side;
  the import still takes it and says how many macros it needs.

## 1.0.3.13

- The step card now calls itself **Target and conditions**, both in its header and
  per step (`Target and conditions - step 2: Frostbolt`), and its hint says which
  section is which: the target row first, then the conditions.
- The `cond` button's tooltip says the same, including that only spell steps carry
  a target or conditions.

## 1.0.3.12

- **A step can choose who its spell lands on.** The step card now has a `TARGET`
  row - `target`, `mouseover`, `focus`, `player` - written at the front of the same
  bracket as the conditions: `[@mouseover,mod:shift,harm]`. Both modes honour it,
  so a priority macro can heal the person under the cursor and a sequence entry
  keeps its own target.
- Clicking the lit target again clears it, back to the client's default, which is
  your current target.
- Targets belong to spell steps. A macro step's body carries its own target, so its
  card is dimmed and the refusal names that reason instead of writing a bracket the
  inlined body would ignore.

## 1.0.3.11

- **The reset choices combine.** Instead of one cycling `Reset:` button there are
  three toggles - `target`, `combat` and `10s` - and any of them can be on at
  once, so the old `reset=target/10` is reachable again by switching target and
  the seconds field on. Three on at once reads `reset=target/combat/10`.
- **The combination is on the control**: each toggle lights while it is switched
  on, the timed one's label shows the current count, and every tooltip states what
  is on now and exactly what `Build macro` will write. All three off writes a
  `castsequence` with no reset clause.
- A Maker saved by 1.0.3.6-1.0.3.10 loads its single choice as that one toggle, so
  nothing already chosen is lost.

## 1.0.3.10

- **`harm` and `help` are now caught as a contradiction too.** They cannot both
  hold, so the card dims whichever one would clash, a click is refused with the
  pair named, and a step saved with both is reported and left out of the macro.
- The rule lives in one place now, so any impossible pair added later is covered by
  the card, the toggle and the composer at once.

## 1.0.3.9

- **Modifier conditions that contradict each other are caught.** `nomod` and any
  `mod:` cannot both hold, so the card dims the toggle that would clash and a
  click explains that the client would never pick that step. Either direction is
  refused: adding a modifier beside `nomod`, or `nomod` beside a modifier.
- A step saved with the pair from an earlier build is not written into the macro:
  the count's red tooltip names it as a contradiction, and in sequence mode the
  step is left out of the `castsequence` rather than sitting there dead.

## 1.0.3.8

- **A step can carry conditions.** Each row has a `cond` button that opens a card
  of eight toggles: `mod:shift`, `mod:ctrl`, `mod:alt`, `nomod`, `harm`, `help`,
  `exists` and `combat`. Switched on, they are written into the macro in the order
  they are listed, and the row shows them:
  `Cast Frostbolt  [mod:shift,harm]`.
- **Both modes honour them.** Priority writes `/cast [mod:shift,harm] Frostbolt`;
  sequence puts the bracket on that spell's own entry, so one list can branch on a
  modifier instead of only cycling: `/castsequence reset=target
  [mod:shift,harm]Frostbolt, Fireball`.
- Conditions belong to spell steps. A macro step's body applies its own, so its
  `cond` button is dimmed and the count's tooltip says why rather than pretending
  the setting took effect.

## 1.0.3.7

- **The timed reset is a number you choose.** With `Reset: 10s` selected, a `SECS`
  field sits beside the button: type anything from 1 to 60 and the built
  `/castsequence` uses that figure. It is saved with the steps, so it survives a
  reload, and the field only appears while the timed reset is selected.
- The number is committed when you press Enter or click away, so typing `25` does
  not write `reset=2` along the way; an out-of-range or non-numeric entry keeps
  the previous value and says why.
- The `Reset:` tooltip now quotes the current count instead of a fixed 10.

## 1.0.3.6

- **The sequence's reset is yours to choose.** A `Reset:` button next to `Runs:`
  cycles through **target** (`reset=target`), **combat** (`reset=combat`),
  **10s** (`reset=10`) and **none** (no reset clause at all), and the choice is
  saved with the steps. Its tooltip says what the current one does.
- The reset button dims while `Runs: priority`, because a priority macro has no
  `castsequence` for it to affect; the setting is still remembered for when you
  switch back.

## 1.0.3.5

- **The Maker can run its steps as a sequence instead of a priority list.**
  `Runs: priority` is what it always did - each press tries every step and casts
  the first that works. `Runs: sequence` writes one
  `/castsequence reset=target/10 a, b, c`, so the client casts one spell per
  press and keeps its place, the way a GSE sequence steps. The toggle sits next to
  `Build macro`, and the steps stay where they are when you switch.
- Sequence mode takes spells only: a macro step is named in the count's red
  tooltip rather than dropped from the body without a word.

## 1.0.3.4

- `/mvpro diag` now prints a `window skin` line naming each template the client
  provided (`PortraitFrameTemplate`, `LargeSideTabButtonTemplate`,
  `BackdropTemplate`, `UIPanelButtonTemplate`) as `yes`, `fallback` or
  `not-built`, so a screenshot of the report shows which look is drawing.

## 1.0.3.3

- **Every page and pane now uses the window's panel styling**, so the list, the
  macro text, the Maker's sequence and the Sheet's slots all sit on the same dark
  cards with the gold trim instead of flat grey boxes.

## 1.0.3.2

- **The window now looks like the client's own windows.** It uses the game's
  portrait frame and title bar, with the addon's icon as the portrait, and the
  buttons carry the same gold trim and pressed art as the rest of the interface.
- **Pages are chosen from icon tabs down the right edge**, each with its name in a
  tooltip, instead of a row of text tabs above the content. The accent colour is
  the client's gold rather than purple.

## 1.0.3.1

- **The Maker tab no longer treats a click as an error.** Clicking in the sequence
  area with nothing on the cursor leaves the status line alone, and clicking the
  drop bar says what to do instead of turning red.
- **With no macros yet, the Maker tab offers a Make a macro button** that opens the
  Editor tab on an empty macro, instead of pointing at a tab with nothing to press.
- **The sequence row says what a step can do:** `x` removes it, dragging a row moves
  it, and the Build button's tooltip explains that rebuilding updates the same
  macro, so a bar button already there keeps working.
- **An empty sequence reads 0 / 255**, not the 12 characters of the `#showtooltip`
  header, and the panel's overlapping hint text is gone.

## 1.0.3

- **A new Maker tab builds one macro out of a list.** Drop a spell from your
  spellbook onto it, or add one of your own macros, and put the steps in the
  order they should run: one bar button then runs the whole sequence.
- **Drag a step to move it, click its `x` to remove it.** The step under the
  cursor is where the dragged one goes, and the icon row offers the icons your
  steps already carry, plus the default question mark.
- **The maker shows the macro text and its character count as you build it.** A
  sequence longer than the client's 255 characters is refused with the count
  instead of being cut short, and changing the order updates the same macro, so a
  button already on your bar follows it.
- **A sequence cannot include the macro it builds.** The maker's own macro is in
  your macro list, so it could be added to its own sequence; that is now refused
  with the reason on the row, instead of building a macro that doubles in size
  every time.
- **Renaming the maker renames its macro.** Changing the name and building again
  used to make a second macro and leave the first one behind, with the old bar
  button still pointing at it; the same macro is renamed now, so one button and
  one macro stay in step.
- **A name shared by an account and a character macro is no longer guessed at.**
  Each step remembers which of the two you added, and if the maker cannot tell
  them apart it says so instead of quietly composing the other macro's lines.

## 1.0.2

- **The version the addon reports is the version you installed.** The line in
  chat on login, and the version `/mvpro selftest` prints, now match the number
  in the archive's name. They used to say 1.0.0 whichever build was loaded, so a
  bug report could not be tied to the file it came from.
- **Nothing else changed** — same commands, same window, same behaviour. The
  release script now writes the `.toc` version, the version the addon prints and
  the build stamp together, so they cannot drift apart again.

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
