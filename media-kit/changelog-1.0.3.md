# MacroVaultPro 1.0.3

For World of Warcraft: Forever (interface 16001), build 2026-11-27ab.

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
- **A step can choose who its spell lands on.** The step card's `TARGET` row -
  `target`, `mouseover`, `focus`, `player`, `cursor` and `none` - is written at the
  front of the same bracket as the conditions, target first:
  `[@cursor,harm]`. Both modes honour it. Clicking the lit target again clears it,
  back to your current target.
- **A step can carry conditions.** Each row's `cond` button opens eight toggles -
  `mod:shift`, `mod:ctrl`, `mod:alt`, `nomod`, `harm`, `help`, `exists` and
  `combat` - written in the order they are listed. Priority writes
  `/cast [mod:shift,harm] Frostbolt`; sequence puts the bracket on that spell's own
  entry. Pairs the client could never satisfy, such as `nomod` beside a modifier
  or `harm` beside `help`, are dimmed and refused with the pair named, and a step
  saved with one is reported and left out of the macro rather than sitting there
  dead.
- **The steps can run as a sequence instead of a priority list.** `Runs:` next to
  the steps switches between one `/cast` per step, the way it always worked, and a
  single `/castsequence` the client steps through one press at a time. Sequence
  mode takes spells only and names a macro step it cannot use.
- **The sequence's reset is yours to build.** Three toggles - `target`, `combat`
  and a seconds field from 1 to 60 - combine in any order, so `reset=target/10`
  and `reset=target/combat/25` are both reachable; all three off writes a
  `castsequence` with no reset clause, and every tooltip says what will be written.
- **A sequence travels as one line.** `Share` puts the whole maker in a box as
  text - the name, the mode, the reset choices and every step with its target,
  conditions and scope - and `Copy` selects it for Ctrl+C. `Load` validates a line
  before writing it and refuses the whole thing with the step and field named if
  one step is bad, so nothing is half-imported; names are escaped, so a spell
  containing `|`, `:`, `,`, `@`, `*`, `#` or `+` survives the round trip. When the
  maker already holds steps, the first press asks `Replace?` and says how many
  would go, and a line that needs macros this character does not have names them
  and counts the rest.
- **The window looks like the client's own windows.** It uses the game's portrait
  frame and title bar with the addon's icon as the portrait, the buttons carry the
  client's gold trim and pressed art, every page sits on the same dark card, and
  pages are chosen from icon tabs down the right edge instead of a row of text
  tabs.
- **The Maker tab says what a step can do and what to do with an empty sequence.**
  `x` removes a step and dragging a row moves it, an empty sequence reads `0 / 255`,
  a click with nothing on the cursor is no longer reported as an error, and with no
  macros yet a **Make a macro** button opens the editor on an empty one.
- **The error log names the addon that broke, and repeats take one slot.** Errors
  raised by another addon are listed under their own heading, tagged
  `(not this addon)`, instead of being reported as this addon's; the same error
  happening again folds into one entry that counts the repeats and shows when it
  was last seen, and the header totals every sighting. `/mvpro diag` also names
  each window template the client provided as `yes`, `fallback` or `not-built`.
