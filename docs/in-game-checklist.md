# MacroVaultPro in-game check — 1.0.3.12 → 1.0.3.24

Installed builds: **MacroVaultPro 1.0.3.24**, stamp `[2026-11-27af]`; **One Button Pad 0.1.1**, stamp `[2026-11-28a]` — a separate addon, checked in section 5 of the same reload. Everything below is reachable on **one reload**, in this order. Tick what passes; for anything clipped, overlapping or refused, note the section and the exact text so it can be fixed against a version number.

## 0. You are on the new build

- [ ] `/reload`
- [ ] `/mvpro selftest` reports `1.0.3.24`, build `2026-11-27af`, interface `16001`

## 1. Maker card — 1.0.3.12, 1.0.3.13, 1.0.3.15

- [ ] `/mvpro` → Maker: the card header reads **Target and conditions**, and the hint line under it sits fully inside the card — no clipping, nothing under the conditions row
- [ ] **TARGET** row is two lines: `target · mouseover · focus · player` then `cursor · none`. No button crosses the card edge or the **CONDITIONS** label
- [ ] CONDITIONS label sits below the second target line; both condition rows are visible and unclipped
- [ ] Click each of the six targets once — it lights; click again — it clears (same for `cursor` and `none`)
- [ ] With `@cursor` and `harm` on step 1, the made line reads `[@cursor,harm]`, target first
- [ ] The card does not cover the step list or the made/count line

## 2. Share and Load — 1.0.3.14, 1.0.3.15, 1.0.3.23, 1.0.3.24

- [ ] With two or more steps, **Share**: the box holds one line starting `MVPSEQ1|`, and the status line under it is legible and not clipped
- [ ] **Copy**, paste into chat: the whole string arrives, no colour codes, no line breaks
- [ ] With steps already there, press **Load** once: the button reads **Replace?** and the gold line says how many steps would go
- [ ] Press **Close** (or edit the box): back to **Load**, nothing replaced
- [ ] Press **Load**, then **Replace?**: steps are replaced, and the count matches what the gold line said
- [ ] Paste a broken string such as `MVPSEQ1|nope`, press **Load**: refusal message, steps untouched, **no** `Replace?` prompt
- [ ] Clear every step, paste a valid string, press **Load**: loads without asking
- [ ] Load a string whose macro steps this character does not have: the line under the box names three of them and says `and N more`, and it stays between the box and the **Copy** row (1.0.3.22)
- [ ] The card's hint above the box stops at two lines and leaves the box clear — nothing of it sits on the box's top edge (1.0.3.24)
- [ ] There is a visible gap between the hint's second line and the top edge of the edit box — the box starts lower than it did in 1.0.3.23 (1.0.3.24)
- [ ] The edit box still shows several lines of a long sequence without its last line crowding the **Copy** row (1.0.3.24)
- [ ] Share a maker holding one step, then Load it into an empty maker: the line reads `Loaded 1 step`, not `1 steps` (1.0.3.23)

## 3. Error log — 1.0.3.16, 1.0.3.17, 1.0.3.18

- [ ] `/mvpro errors` before clearing: **three** entries, not eight — `Options` ×2, `Bindings` ×4, `Hint` ×2, each with `last seen`
- [ ] Header reads `3 own + 0 from other addons  -  8 sightings  -  saved in …`. The three say **own** because they were saved before 1.0.3.16 fixed attribution — that is expected, not a failure
- [ ] `/mvpro errors clear` → "error log cleared.", window empties
- [ ] Reload so ForeverOneButtonPad throws again, then `/mvpro errors`: one entry under **raised by another addon**, tagged `(not this addon)`, `x1`, first and last time identical
- [ ] Reload again: same entry, `x2`, first time unchanged, last seen moved, header sightings now 2
- [ ] Window: status line reads `0 own, 1 other`; **Copy** gives plain text with no colour codes; the long header is not clipped

## 4. Quick regressions

- [ ] `/mvpro diag` prints the skin report, including which templates fell back
- [ ] Tabs switch (Macros, Maker, Tools, Library, Editor, Sheet); the minimap button opens and closes the window
- [ ] No Lua error popup during any of the above

### Known cosmetics (don't stop the pass for these)

- The header says `1 sightings` when there is exactly one — grammar only, no work started.
- The three old entries can't fold with new repeats of the same error, because their text still carries the pre-1.0.3.16 handler frame.

## 5. One Button Pad 0.1.1 — separate addon, same reload

Its own `.toc` reads 0.1.1 and Console Port is no longer a dependency: this addon is Forever One Button only.

- [ ] Chat after the reload shows `One Button Pad  v0.1.1 loaded - /obp` (the prefix is coloured) — not v0.1.0
- [ ] `/obp` opens **one pane**: a single list, **no pad column**, no `CONSOLE PORT  -  PAD BINDINGS` header anywhere
- [ ] Header under `FOREVER ONE BUTTON  -  CELLS AND KEYS` reads `version 1.2.14  -  N cells, M with a key`, and when some cells have no key it continues `  -  K with no key`; N, M and K match the rows you can count
- [ ] Every row reads `Cell <n>    <name>` with a chord on the right (`SHIFT-1`, `CTRL-SHIFT-4`, …); a name the client cannot resolve falls back to `spell <id>` or `item <id>`, never a blank row
- [ ] A cell with no key shows `no key` on the right and is dimmed grey, still listed — not hidden
- [ ] A cell numbered past what the grid shows is dimmed the same way; the window does not label it, so count the dimmed rows against `/obp report`, which marks each one `(past the cells it shows)`
- [ ] `/obp report` ends with `read-only: this window never moves a cell or changes a key.`, and has a `cell(s) have no key - they are in the grid, but no chord presses them` line whenever K above is more than 0
- [ ] `/obp diag` first line under the header reads exactly `addon 0.1.1  build 2026-11-28a` — not 0.1.0, not `2026-11-27a`
- [ ] `/obp diag` next line reads `foreveronebutton yes  version 1.2.14  cells <keyed>/<total> keyed  shows <grid slots>`; `version -` only means the addon metadata could not be read — everything else still has to say `yes`
- [ ] `/obp diag` names its reads and all five say yes: `reads db yes  char yes  cells yes  spells yes  items yes` — any `no` names the read that failed, so note which word said it
- [ ] `/obp diag` last line reads `window built  saved yes` once `/obp` has opened the window; before that `window not built  saved yes` is correct, because the saved-variable table is made when the addon loads
- [ ] **Copy to chat** prints the same block as `/obp report`, and the window's status line reads `Report printed to chat - it can be copied from there.`
- [ ] If the window opens at the old 0.1.0 position or looks off after the narrower width, `/obp reset` re-centres it — expected once, not a failure
- [ ] No Lua error popup from `/obp`, `/obp report` or `/obp diag`

## Keeping this current

Add a line to the right section whenever a build adds UI the owner has to look at, and name the version it came from. Move the build line at the top forward with each install. Geometry that the harness already asserts (`tests/maker/layout.js`) still gets an in-game tick: the harness proves the anchors, not what the client draws.
