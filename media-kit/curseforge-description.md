# MacroVaultPro

**Every macro you own in one window — and the client's own tools one click away.**

MacroVaultPro lists every account-wide and character macro you have in a single
searchable window. Pick one, read its whole body, and put it straight onto your
action bars without opening the macro window, retyping a command or working out
which slot it lives in. The same window carries the slash commands you end up
typing by hand — `/fstack`, `/etrace`, `/api`, the `/console` toggles — and a
library of ready-made macros you can create in one click.

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
- **Duplicate** copies it so you can change a copy and keep the original.
- **Macro UI** opens the game's own macro window when you would rather drag it.

### An editor that respects the client's limits

Macros are edited as plain text with the client's real limits applied: 255
characters in the body, 16 characters in the name. The body carries a live
counter that turns red past the limit, and saving an over-long body is refused
with both numbers instead of truncating it; the name field stops at 16
characters.

### Twelve client tools

| Tool | Command |
| --- | --- |
| Frame stack | `/fstack` |
| Frame stack + hidden frames | `/fstack true` |
| Event trace | `/etrace` |
| Build info | `/dump select(4, GetBuildInfo())` |
| API browser | `/api` |
| Macro window | opens the client's macro frame |
| Reload UI | `/reload` |
| Script errors on | `/console scriptErrors 1` |
| Script errors off | `/console scriptErrors 0` |
| Taint log | `/console taintLog 1` |
| Mouseover frame | prints the frame under your cursor |
| Dump mouseover frame | `/dump GetMouseFocus()` |

Ten of these run the client's own slash commands, so they behave exactly as if
you had typed them into chat; the macro window and the mouseover inspector call
the client's API instead. If the client does not have a command, MacroVaultPro
says so in the window rather than failing quietly.

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

The **Sheet** tab puts every macro in a list beside 36 icon slots. Drag one out of
the list and it lands in whichever slot you let go over, drag one slot onto
another to swap their places,
and right-click a slot to clear it. Each slot wears its macro's own icon and
shows the name, scope and body on hover; clicking one selects it in My macros.
Slots hold the macro's name and scope rather than a slot number, so the sheet
survives macros being created and deleted - a slot whose macro has gone stays
visible with a red border, so nothing disappears without you seeing it. The
layout is written to `MacroVaultProDB` as you change it, and **Save layout**
writes it again on demand.

### Sensible about account and character slots

Clients do not agree on which slot index character macros start at, so MacroVaultPro
reads the limit from the client — the `MAX_ACCOUNT_MACROS` and
`MAX_CHARACTER_MACROS` globals where they exist, then `Constants`, then built-in
defaults of 120 account and 30 character slots. Every macro MacroVaultPro creates
also records the exact scope of its own slot, so the tags stay right even when
the detected boundary is only an estimate.

Opening the window is read-only. It never creates or deletes anything.

### Tells you it loaded, and logs its own errors

On login the addon prints one line — `v1.0.0 loaded - /mvpro` — so a fresh
install reports that it is running instead of looking inert until you type a
command.

If something inside the addon does raise a Lua error, `/mvpro errors` prints it
with its timestamp, message and traceback, ready to paste into a bug report. It
records errors raised in the addon's own files, including ones thrown while it is
still loading, and keeps the last 20 plus up to 10 whose traceback carries no
addon name. The list is saved in `MacroVaultProDB`, so it survives a reload, and
`/mvpro errors clear` empties it.

### Remembers where you left it

The window position, the last tab, your default scope and the sheet layout are
saved per account in `MacroVaultProDB`.

## How to use it

1. Type `/mvpro` in chat to open the window.
2. **My macros** — search, click a macro, then **Inject**, **Edit**, **Duplicate**
   or **Macro UI**.
3. **Tools** — click an entry. The tool runs immediately; output appears in chat
   or in the client's own window.
4. **Library** — pick a macro, check its body, then **Create** or **Create & pick up**.
5. **Sheet** — drag macros out of My macros into the slots, drag slots to
   reorder, right-click to clear.
6. Close with Escape, or type `/mvpro` again.

## Slash commands

| Command | What it does |
| --- | --- |
| `/mvpro` or `/macrovaultpro` | Open or close the window |
| `/mvpro macros` | Open the My macros tab |
| `/mvpro tools` | Open the Tools tab |
| `/mvpro library` | Open the Library tab |
| `/mvpro editor` | Open the editor |
| `/mvpro sheet` | Open the sheet |
| `/mvpro selftest` | Print client and limit diagnostics, then confirm the account/character boundary |
| `/mvpro errors` | Print the addon's error log, ready to copy |
| `/mvpro errors clear` | Empty the error log |
| `/mvpro reset` | Forget the saved window position |

`/mvpro selftest` is the only thing in the addon that creates a macro on its own:
one temporary macro per scope, deleted straight away, so it can report where
character macros really begin. Run it out of combat. It prints the client build,
the detected split, how many slots you use, and whether the probes confirmed or
corrected the boundary.

## Compatibility

- **World of Warcraft: Forever** — interface 16001 (supported target).
- The `.toc` lists interface 120105 as a secondary value, but Forever is the
  only client this is written and tested against.
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
- **Panels stay put.** Window position, tab, default scope and the sheet layout
  are the only settings stored; the error log is the only other thing written.
- **Errors are kept, not swallowed.** A failure in the addon's own code lands in
  `/mvpro errors` and in
  `WTF/Account/<account>/SavedVariables/MacroVaultPro.lua` after a reload, so it
  can be reported with its traceback instead of a screenshot of a dialog.

## Gallery

See the Images tab for the full set of panels.

## Version

1.0.0 — first release. See the changelog on the Files tab.
