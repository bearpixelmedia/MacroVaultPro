# MacroVaultPro

**Every macro you own in one window — and the client's own tools one click away.**

MacroVaultPro lists every account-wide and character macro you have in a single
searchable window. Pick one, read its whole body, and put it straight onto your
action bars without opening the macro window, retyping a command or working out
which slot it lives in. The same window carries the slash commands you end up
typing by hand — `/fstack`, `/etrace`, `/api`, the `/console` toggles — and a
library of ready-made macros you can create in one click, and a Maker that
composes a list of steps into a single macro.

Built for **World of Warcraft: Forever** (interface 16001).

## Features

### Every macro, one list

Account-wide and character macros share one scroll, each tagged with the scope it
actually lives in. Search filters on the name and on the body, so you can find a
macro by what it does when you have forgotten what you called it.

The macro you select shows its full body, its icon, its slot and its scope, with
four things you can do about it:

- **Inject** picks the macro up, so one click on an action button drops it there.
- **Edit** opens it in the editor without retyping the body.
- **Duplicate** opens the editor pre-filled with the macro's name, body and icon,
  so you save a changed copy and keep the original.
- **Macro UI** opens the game's own macro window when you would rather drag it.

### An editor that respects the client's limits

Macros are edited as plain text with the client's real limits applied: 255
characters in the body, 16 characters in the name. The body carries a live
counter that turns red past the limit, and saving an over-long body is refused
with both numbers instead of truncating it; the name field stops at 16
characters.

### A Maker that composes one macro

The **Maker** tab turns a list of steps into one bar button. Drag a spell from
your spellbook onto the drop bar, or click any of your own macros in the list on
the left, and the steps run down the list in the order shown. **Build macro**
writes the result as a real in-game macro - one `#showtooltip` header and a line
per step - and the whole body and its character count are shown above the buttons
as you build. A body over the client's 255 characters is refused with the count
instead of being cut short, and a sequence holds at most 12 steps. Rebuilding
updates the same macro, so a button already on your bar keeps working; renaming
the Maker renames that macro rather than leaving a second one behind. **Drag to
bar** builds it and puts it on your cursor.

The same steps run in one of two ways. **Runs: priority** writes one `/cast` per
step, so each press tries every step in order and casts the first that works -
spells and macro steps both fit. **Runs: sequence** writes a single
`/castsequence` carrying the reset choices below, so the client casts one spell
per press and keeps its place; that mode takes spells only, and names any macro step
it cannot use instead of dropping it without a word. The reset is three toggles -
`target`, `combat` and a seconds field from 1 to 60 - and any of them can be on at
once, or all three off for a `castsequence` with no reset clause.

A spell step's `cond` button opens **Target and conditions**. One target -
`target`, `mouseover`, `focus`, `player`, `cursor` or `none` - and eight
conditions - `mod:shift`, `mod:ctrl`, `mod:alt`, `nomod`, `harm`, `help`,
`exists` and `combat` - are written into the same bracket at the front of that
step, target first: `[@mouseover,mod:shift,harm]`. Sequence mode puts the bracket
on the spell's own entry. A pair the client could never satisfy - `nomod` beside a
modifier, or `harm` beside `help` - is refused with the pair named, and a step
saved with one by an older build is reported and left out of the macro. A macro
step carries its own target and conditions inside its body, so its card is dimmed
and a click says why.

**Share** writes the whole Maker as one line - name, mode, reset choices, and
every step with its target, conditions and scope, escaped so names survive the
round trip:

```
MVPSEQ1|Heals|sequence|target+combat+25|s:Flash Heal@mouseover*help|m:Trinket 1#a
```

**Copy** selects it for Ctrl+C; there is no clipboard API to call. Paste a line
into the same box and **Load** checks it before writing anything: the prefix, the
mode, the reset choices, the step kinds, every target and condition, and
contradictory pairs. One bad step refuses the whole line and names the step and
the field, so nothing is half-imported. When the Maker already holds steps the
first press turns Load into **Replace?** and says how many steps would go; press
it again to replace them, or **Close** to keep what you have. A loaded line whose
macro steps this character does not have names them and counts the rest.

### Twelve client tools

| Tool | What it runs |
| --- | --- |
| Frame stack | `/fstack` |
| Frame stack + hidden frames | `/fstack true` |
| Event trace | `/etrace` |
| Build info | `GetBuildInfo()`, read in Lua |
| API browser | `/api` |
| Macro window | opens the client's macro frame |
| Reload UI | `/reload` |
| Script errors on | `/console scriptErrors 1` |
| Script errors off | `/console scriptErrors 0` |
| Taint log | `/console taintLog 1` |
| Mouseover frame | prints the frame under your cursor |
| Dump mouseover frame | `GetMouseFocus()`, read in Lua |

Eight of these run the client's own slash commands: the addon calls the handler
the client registered for the command, and hands the line to the chat parser when
there is no handler, which is the path a client-native or lazily loaded command
like `/fstack` or `/api` takes. The other four don't depend on the command text -
build info and the two mouseover inspectors call `GetBuildInfo()` and
`GetMouseFocus()` in Lua, and the macro window opens the client's macro frame
(`/macro` where the client registers it, `ShowMacroFrame` otherwise). If a command
really is missing, MacroVaultPro says so in the window rather than failing
quietly.

### 26 ready-made macros

| Group | Count | Examples |
| --- | --- | --- |
| Targeting | 10 | mouseover target, mouseover focus, mouseover's target, assist mouseover, skull and clear markers |
| Utility | 11 | trinket 1, both trinkets, start attack, stopcasting, dismount, sit, follow, stopwatch, ready check, roll, played time |
| Development | 5 | frame stack, event trace, dump mouseover frame, script errors, reload |

Each entry shows its body before you commit. **Create** makes a real in-game
macro; **Create & pick up** makes it and puts it on your cursor in one step. A
toggle chooses whether new macros land in your account-wide or character slots.

### A sheet you arrange yourself

The **Sheet** tab puts every macro in a list beside 36 icon slots. A drop from the list writes the macro into the slot under the pointer
and takes it out of wherever it already sat; a drop from one slot onto another
swaps the two, and right-clicking a slot clears it. Each slot wears its macro's own icon and
shows the name, scope and body on hover; clicking one selects it in My macros.
Slots hold the macro's name and scope rather than a slot number, so the sheet
survives macros being created and deleted - a slot whose macro has gone stays
visible with a red border, so nothing disappears without you seeing it. The
layout is written to `MacroVaultProDB` as you change it, and **Save layout**
writes it again on demand. **Undo**, beside it, holds the copy of the layout
taken just before the last clear or move and writes it back — one step, then
nothing older until the next change.

### Sensible about account and character slots

Clients do not agree on which slot index character macros start at, so MacroVaultPro
reads the limit from the client — the `MAX_ACCOUNT_MACROS` and
`MAX_CHARACTER_MACROS` globals where they exist, then `Constants`, then built-in
defaults of 120 account and 30 character slots. Every macro MacroVaultPro creates
also records the exact scope of its own slot, so the tags stay right even when
the detected boundary is only an estimate.

Opening the window is read-only. It never creates or deletes anything.

### Tells you it loaded, and logs its own errors

On login the addon prints one line — `v<version> loaded - /mvpro` — so a fresh
install reports that it is running instead of looking inert until you type a
command.

If something inside the addon does raise a Lua error, `/mvpro errors` assembles
the log as one plain-text block — a header, then each entry with its timestamp,
message and traceback — and hands it to a small read-only window instead of
printing it into chat; chat is the fallback when that window cannot be built.
**Copy** fills the window's text with that block and selects all of it. Errors
raised by another addon go under their own heading, tagged `(not this addon)`,
instead of being reported as MacroVaultPro's. Repeats of the same error fold into
one entry that keeps the first time, counts the occurrences and shows when it was
last seen, and the header totals every sighting, folded repeats included. The
list is saved in `MacroVaultProDB`, so it survives a reload: the addon's own 20
entries and up to 10 from other addons. **Clear log** empties both stored lists,
drops the entries still waiting to be saved, and rebuilds the window from the
empty log.

`/mvpro diag` prints one block, ready to paste: the addon's build stamp, the
client build, whether the client exposes `RegisterForDrag`,
`IsMouseButtonDown` and `GetMouseFocus`, the minimap size and shape, the
detected slot split, and how many drags each of the two drag paths has started
since you logged in — so a report says exactly which path works.

### Remembers where you left it

The window position, the last tab, your default scope, the sheet layout, the
Maker's name, steps, mode and reset choices, where the minimap button sits and
whether it is shown are saved per account in `MacroVaultProDB`.

## How to use it

1. Type `/mvpro` in chat, or click the addon's icon by the minimap, to open the
   window.
2. **My macros** — search, click a macro, then **Inject**, **Edit**, **Duplicate**
   or **Macro UI**.
3. **Tools** — click an entry. The tool runs immediately; output appears in chat
   or in the client's own window.
4. **Library** — pick a macro, check its body, then **Create** or **Create & pick up**.
5. **Maker** — drop a spell onto the drop bar or click a macro on the left, order
   the steps, then **Build macro**. **Share** writes the sequence as one line and
   loads one back.
6. **Sheet** — drag macros out of My macros into the slots, drag a slot onto
   another to swap them, right-click to clear. **Undo** writes back the layout
   from before that last clear or move.
7. Close with Escape, or type `/mvpro` again.

## Slash commands

| Command | What it does |
| --- | --- |
| `/mvpro` or `/macrovaultpro` | Open or close the window |
| `/mvpro macros` | Open the My macros tab |
| `/mvpro tools` | Open the Tools tab |
| `/mvpro library` | Open the Library tab |
| `/mvpro maker` | Open the Maker tab |
| `/mvpro editor` | Open the editor |
| `/mvpro sheet` | Open the sheet |
| `/mvpro minimap` | Show or hide the minimap button |
| `/mvpro selftest` | Print client and limit diagnostics, then confirm the account/character boundary |
| `/mvpro diag` | Print one copyable block: build stamp, client build, drag APIs, minimap and slot split |
| `/mvpro undo` | Write back the layout from before the last Sheet clear or move |
| `/mvpro errors` | Assemble the error log and show it in a read-only window, with Copy |
| `/mvpro errors clear` | Empty the error log |
| `/mvpro reset` | Forget the saved window position |

`/mvpro selftest` is the only thing in the addon that creates a macro on its own:
one temporary macro per scope, deleted straight away, so it can report where
character macros really begin. Run it out of combat. It prints the client build,
the detected split, how many slots you use, and whether the probes confirmed or
corrected the boundary.

## Compatibility

- **World of Warcraft: Forever** — interface 16001, the only interface the
  `.toc` declares.
- No dependencies and no external libraries. One SavedVariables file for the
  window position, preferences and the error log.
- Nothing is created, edited or deleted while you are in combat — the addon
  says so in the window and you can try again afterwards.

## Good to know

- **Capacity numbers**: if a client exposes neither `MAX_ACCOUNT_MACROS`,
  `MAX_CHARACTER_MACROS` nor a usable `Constants` entry, the window shows the
  built-in defaults of 120 account and 30 character slots until you run
  `/mvpro selftest`, which measures the real split.
- **Slash tools are UI tools.** They toggle debug frames, print information and
  change console settings. MacroVaultPro never casts, moves or fights for you.
- **Panels stay put.** Window position, tab, default scope, sheet layout, the
  Maker's sequence, and the minimap button's place and visibility are the only
  settings stored; the error log is the only other thing written.
- **Minimap button.** The icon beside the minimap is wired to open the window; a
  drag writes a new angle around the map edge back to `MacroVaultProDB`, and
  right-click writes the default angle back, so nothing about where it sits is
  hard-coded. Type `/mvpro minimap` to hide or show it if you would rather not
  have it on the map. It is built into the addon, so it adds no dependency.
- **Errors are kept, not swallowed.** A failure in the addon's own code is stored
  for the `/mvpro errors` window and written into
  `WTF/Account/<account>/SavedVariables/MacroVaultPro.lua` on reload, so the
  message and traceback exist as text rather than only in a dialog.

## Gallery

The four panels on the Images tab are illustrations drawn from the addon's own layout
to show what each tab holds. They are renderings, not in-game screenshots, so spacing
and button positions can differ from the client; in-game captures will replace them as
they are taken.

## Version

1.0.3 — see the changelog on the Files tab.
