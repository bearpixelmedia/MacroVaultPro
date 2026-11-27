# MacroVaultPro in-game check — 1.0.3.12 → 1.0.3.19

Installed build: **1.0.3.19**, stamp `[2026-11-27aa]`. Everything below is reachable on **one reload**, in this order. Tick what passes; for anything clipped, overlapping or refused, note the section and the exact text so it can be fixed against a version number.

## 0. You are on the new build

- [ ] `/reload`
- [ ] `/mvpro selftest` reports `1.0.3.19`, build `2026-11-27aa`, interface `16001`

## 1. Maker card — 1.0.3.12, 1.0.3.13, 1.0.3.15

- [ ] `/mvpro` → Maker: the card header reads **Target and conditions**, and the hint line under it sits fully inside the card — no clipping, nothing under the conditions row
- [ ] **TARGET** row is two lines: `target · mouseover · focus · player` then `cursor · none`. No button crosses the card edge or the **CONDITIONS** label
- [ ] CONDITIONS label sits below the second target line; both condition rows are visible and unclipped
- [ ] Click each of the six targets once — it lights; click again — it clears (same for `cursor` and `none`)
- [ ] With `@cursor` and `harm` on step 1, the made line reads `[@cursor,harm]`, target first
- [ ] The card does not cover the step list or the made/count line

## 2. Share and Load — 1.0.3.14, 1.0.3.15

- [ ] With two or more steps, **Share**: the box holds one line starting `MVPSEQ1|`, and the status line under it is legible and not clipped
- [ ] **Copy**, paste into chat: the whole string arrives, no colour codes, no line breaks
- [ ] With steps already there, press **Load** once: the button reads **Replace?** and the gold line says how many steps would go
- [ ] Press **Close** (or edit the box): back to **Load**, nothing replaced
- [ ] Press **Load**, then **Replace?**: steps are replaced, and the count matches what the gold line said
- [ ] Paste a broken string such as `MVPSEQ1|nope`, press **Load**: refusal message, steps untouched, **no** `Replace?` prompt
- [ ] Clear every step, paste a valid string, press **Load**: loads without asking
- [ ] Load a string whose macro steps this character does not have: the line under the box names at most three of them and says `and N more`, and it stays between the box and the **Copy** row (1.0.3.19)

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

## Keeping this current

Add a line to the right section whenever a build adds UI the owner has to look at, and name the version it came from. Move the build line at the top forward with each install. Geometry that the harness already asserts (`tests/maker/layout.js`) still gets an in-game tick: the harness proves the anchors, not what the client draws.
