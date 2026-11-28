const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

// Runs Core.lua and UI.lua against recording frame stubs and asserts the maker
// card and the share card geometry. No client and no screenshot: every check
// reads the anchors the UI actually sets, so a layout change that clips or
// overlaps a control fails here instead of in game. Run from the repo root with
// `bun run test:maker`; check.js covers the maker logic, this file the layout.
const root = path.resolve(__dirname, "..", "..");
const corePath = path.join(root, "MacroVaultPro", "Core.lua");
const uiPath = path.join(root, "MacroVaultPro", "UI.lua");

const stubs = `
UIParent = {}
SlashCmdList = {}
UISpecialFrames = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GameTooltip = {
  SetOwner = function() end, SetText = function() end, AddLine = function() end,
  Show = function() end, Hide = function() end, ClearLines = function() end,
}
tinsert = table.insert

REGIONS = {}
local function region(kind, name, parent)
  local r = { kind = kind, name = name, parent = parent, points = {}, scripts = {}, width = 0, height = 0, shown = true }
  REGIONS[#REGIONS + 1] = r

  function r:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    r.points[#r.points + 1] = {
      point = point, rel = rel or r.parent, relPoint = relPoint or point,
      x = x or 0, y = y or 0,
    }
  end
  function r:SetAllPoints() end
  function r:SetSize(w, h) r.width, r.height = w or 0, h or 0 end
  function r:SetWidth(w) r.width = w or 0 end
  function r:SetHeight(h) r.height = h or 0 end
  function r:GetWidth() return r.width end
  function r:GetHeight() return r.height end
  function r:GetParent() return r.parent end
  function r:GetName() return r.name end
  function r:SetName(n) r.name = n end
  function r:GetObjectType() return r.kind end
  function r:IsShown() return r.shown end
  function r:IsVisible() return r.shown end
  function r:Show() r.shown = true end
  function r:Hide() r.shown = false end
  function r:SetScript(key, fn) r.scripts[key] = fn end
  function r:GetScript(key) return r.scripts[key] end
  function r:HookScript() end
  function r:CreateTexture() return region("Texture", nil, r) end
  function r:CreateFontString() return region("FontString", nil, r) end
  function r:SetText(text) r.text = text end
  function r:GetText() return r.text end
  -- MakeButton redefines SetLabel itself, so the stub records the label where
  -- that closure puts it: the button's own label FontString.
  function r:GetLabel()
    if r.label and r.label.GetText then return r.label:GetText() end
    return nil
  end
  function r:SetFont(_, size) r.fontSize = size end
  -- One line of a string is its font size plus its leading; enough for a layout
  -- check, and it keeps the share status measurement stable.
  function r:GetStringHeight() return (r.fontSize or 12) + 4 end
  function r:GetStringWidth() return #tostring(r.text or "") * ((r.fontSize or 12) * 0.52) end
  function r:SetScrollChild(child) r.scrollChild = child end
  function r:GetVerticalScroll() return r.scrollOffset or 0 end
  function r:SetVerticalScroll(offset) r.scrollOffset = offset end
  return setmetatable(r, {
    __index = function(t, key)
      local noop = function() end
      t[key] = noop
      return noop
    end,
  })
end
function CreateFrame(kind, name, parent) return region(kind or "Frame", name, parent) end
`;

const tests = `
local MV = MacroVaultPro
local NL = string.char(10)
local log = {}
local function check(name, cond, extra)
  log[#log + 1] = (cond and "PASS " or "FAIL ") .. name .. (extra ~= nil and ("  [" .. tostring(extra) .. "]") or "")
  if not cond then FAILED = true end
end

MacroVaultProDB = {}
MV.maker = nil
function MV:GetMacros() return {} end

local UI = MV.UI
local builtPanel, panelErr = pcall(function() UI:BuildMakerPanel(CreateFrame("Frame", nil, UIParent)) end)
check("the maker panel builds against the stubs", builtPanel, tostring(panelErr))

local card = UI.makerCondPopup
check("the condition card is 330x192",
  card ~= nil and card.width == 330 and card.height == 192,
  card and (card.width .. "x" .. card.height) or "no card")

if builtPanel and card then
  -- The six targets, grouped by the line they landed on.
  local rows, rowCount, targets = {}, 0, 0
  for _, entry in ipairs(MV.MAKER_TARGETS) do
    local button = UI.makerTargetButtons[entry.token]
    local point = button.points[1]
    targets = targets + 1
    local row = rows[point.y]
    if not row then
      row = { count = 0, left = 330, right = 0 }
      rows[point.y] = row
      rowCount = rowCount + 1
    end
    row.count = row.count + 1
    row.left = math.min(row.left, point.x)
    row.right = math.max(row.right, point.x + button.width)
  end

  local ys = {}
  for y in pairs(rows) do ys[#ys + 1] = y end
  table.sort(ys, function(a, b) return a > b end)

  check("six targets are on the card", targets == 6, targets)
  check("the targets sit on two lines", rowCount == 2, rowCount)
  check("four targets on the first line and two on the second",
    rowCount == 2 and rows[ys[1]].count == 4 and rows[ys[2]].count == 2,
    rowCount == 2 and (rows[ys[1]].count .. "/" .. rows[ys[2]].count) or "rows")
  check("the second target line is 26 below the first",
    rowCount == 2 and ys[1] - ys[2] == 26, rowCount == 2 and (ys[1] - ys[2]) or "rows")
  check("the target rows keep a 10 margin inside the card",
    rowCount == 2 and rows[ys[1]].left == 10 and rows[ys[2]].left == 10
      and rows[ys[1]].right <= card.width - 10 and rows[ys[2]].right <= card.width - 10,
    rowCount == 2 and (rows[ys[1]].right .. " / " .. rows[ys[2]].right) or "rows")

  if rowCount == 2 then
    local firstRow, secondRow = {}, {}
    for _, entry in ipairs(MV.MAKER_TARGETS) do
      local point = UI.makerTargetButtons[entry.token].points[1]
      local list = (point.y == ys[1]) and firstRow or secondRow
      list[#list + 1] = entry.token
    end
    check("the first line is target, mouseover, focus, player",
      table.concat(firstRow, ",") == "target,mouseover,focus,player", table.concat(firstRow, ","))
    check("the second line is cursor, none",
      table.concat(secondRow, ",") == "cursor,none", table.concat(secondRow, ","))
  end

  -- The condition rows have to follow the wrapped target row, not overlap it.
  local firstCond = UI.makerCondButtons[MV.MAKER_CONDITIONS[1].token]
  local condLabel = firstCond.points[1].rel
  local labelPoint = condLabel.points[1]
  check("CONDITIONS is anchored 34 below the last target line",
    rowCount == 2 and labelPoint.y == ys[2] - 34, labelPoint.y)

  local conditions, lowestBottom, highestTop = 0, 0, -math.huge
  for _, entry in ipairs(MV.MAKER_CONDITIONS) do
    local button = UI.makerCondButtons[entry.token]
    local point = button.points[1]
    local top = labelPoint.y + point.y
    conditions = conditions + 1
    highestTop = math.max(highestTop, top)
    lowestBottom = math.min(lowestBottom, top - button.height)
  end
  check("all eight conditions are on the card", conditions == 8, conditions)
  check("the condition rows clear the second target line",
    rowCount == 2 and highestTop <= ys[2] - 24 - 8,
    highestTop .. " vs " .. (rowCount == 2 and (ys[2] - 32) or "rows"))
  check("the last condition row keeps 8 below it inside the card",
    card.height + lowestBottom >= 8, card.height + lowestBottom)

  -- The share card: the status line is the one piece that sits between the box
  -- above it and the buttons below it.
  local share = UI:BuildMakerShare()
  check("the share card is 430x250", share.width == 430 and share.height == 250,
    share.width .. "x" .. share.height)

  local status = UI.makerShareStatus
  local statusPoint = status.points[1]
  local bottomButtonHeight = 0
  for _, regionFrame in ipairs(REGIONS) do
    local point = regionFrame.points[1]
    if regionFrame.parent == share and regionFrame.kind == "Button"
      and point and point.y == 8 and regionFrame.height > 0 then
      bottomButtonHeight = math.max(bottomButtonHeight, regionFrame.height)
    end
  end

  local boxBottom
  for _, point in ipairs(UI.makerShareBox.points) do
    if point.point == "BOTTOMRIGHT" then boxBottom = point.y end
  end

  check("the share card's bottom buttons are 24 tall", bottomButtonHeight == 24, bottomButtonHeight)

  local faces = {}
  for _, regionFrame in ipairs(REGIONS) do
    if regionFrame.parent == share and regionFrame.kind == "Button" then
      faces[#faces + 1] = tostring(regionFrame:GetLabel())
    end
  end
  table.sort(faces)
  check("the share card's buttons read Close, Copy and Load",
    table.concat(faces, ", ") == "Close, Copy, Load", table.concat(faces, ", "))
  check("the status line clears the buttons below it",
    statusPoint.y >= 8 + bottomButtonHeight + 8,
    statusPoint.y .. " vs buttons top " .. (8 + bottomButtonHeight))
  check("two status lines fit between the buttons and the box",
    boxBottom ~= nil and statusPoint.y + 2 * status:GetStringHeight() <= boxBottom,
    boxBottom and (statusPoint.y + 2 * status:GetStringHeight()) or "no box bottom")
  check("the status line spans the box and stays inside the card",
    status.width == share.width - 24 and statusPoint.x + status.width <= share.width - 12,
    status.width .. " in " .. share.width)

  -- Whatever LoadMakerShare writes has to fit the strip between the box and the
  -- buttons, including the message that lists macros the character does not
  -- have: a twelve-step paste with sixteen-character names is the widest text
  -- that path can produce.
  local crafted = { "MVPSEQ1", "N", "priority", "none" }
  for i = 1, MV.MAKER_MAX_STEPS do
    crafted[#crafted + 1] = "m:" .. string.rep("M", MV.MAX_NAME - 2) .. ("%02d"):format(i)
  end
  crafted = table.concat(crafted, "|")

  -- Characters per line, budgeted at a wide glyph instead of the 5.2px that
  -- the average character gives at this font size: a capital or a digit runs to
  -- about 0.7em, so this over-counts lines rather than trusting font metrics.
  local wrapWidth = status.width > 0 and status.width or 1
  local charsPerLine = math.max(1, math.floor(wrapWidth / ((status.fontSize or 10) * 0.7)))

  local function statusReport()
    local text = UI.makerShareStatus.text or ""
    return math.max(1, math.ceil(#text / charsPerLine)), text
  end

  UI.makerShareBox:SetText("MVPSEQ1|nope")
  UI:LoadMakerShare()
  local refusalLines, refusalText = statusReport()
  check("the refusal status says what is wrong, exactly",
    refusalText == "'nil' is not a mode - expected priority or sequence",
    refusalText .. " (" .. #refusalText .. " chars)")

  MV:ClearMakerSteps()
  UI.makerShareBox:SetText(crafted)
  UI:LoadMakerShare()
  local loadedLines, loadedText = statusReport()

  -- Measuring the widest text says nothing about what it says: the count, the
  -- cap and the remainder have to be right too, so the whole message is spelled
  -- out and compared exactly.
  local function wideName(i)
    return string.rep("M", MV.MAX_NAME - 2) .. ("%02d"):format(i)
  end
  local expectedLoaded = ("Loaded %d steps. %d macros missing: %s, %s, %s and %d more.")
    :format(MV.MAKER_MAX_STEPS, MV.MAKER_MAX_STEPS,
      wideName(1), wideName(2), wideName(3), MV.MAKER_MAX_STEPS - 3)
  check("the longest share status says Loaded 12 steps. 12 macros missing: with three names and 9 more",
    loadedText == expectedLoaded, loadedText)

  -- Same string again, now that the maker holds steps: the Replace? question.
  UI:LoadMakerShare()
  local replaceLines, replaceText = statusReport()
  local expectedReplace = ("This replaces your %d steps. Press Replace? to go ahead, or Close to keep them.")
    :format(MV.MAKER_MAX_STEPS)
  check("the Replace status asks for the same count, exactly",
    replaceText == expectedReplace,
    replaceText .. " (" .. #replaceText .. " chars)")
  check("the Load button asks Replace? while a paste is pending",
    UI.makerShareLoad:GetLabel() == "Replace?", tostring(UI.makerShareLoad:GetLabel()))

  -- The twelve-missing paste is the widest text this path makes, but the count
  -- it prints has to agree with its own noun, and the singular case is the one
  -- that reads "1 macros" if nobody looks. One step, one name, one missing
  -- macro: it has to fit the strip too.
  MV:ClearMakerSteps()
  UI.makerShareBox:SetText(table.concat({
    "MVPSEQ1", "N", "priority", "none",
    "m:" .. string.rep("M", MV.MAX_NAME - 2) .. "01",
  }, "|"))
  UI:LoadMakerShare()
  local oneLines, oneText = statusReport()
  check('a one-missing status reads "Loaded 1 step. 1 macro missing"',
    oneText:find("Loaded 1 step. 1 macro missing: ", 1, true) ~= nil
      and oneText:find("steps", 1, true) == nil
      and oneText:find("macros missing", 1, true) == nil, oneText)
  check('the one-missing status fits between the box and the buttons',
    statusPoint.y + oneLines * status:GetStringHeight() <= boxBottom,
    oneLines .. " lines, needs " .. (oneLines * status:GetStringHeight())
      .. " of " .. (boxBottom - statusPoint.y) .. " at " .. charsPerLine
      .. " chars/line: " .. oneText)

  -- ShareMaker and CopyMakerShare print counts the harness never read, and the
  -- hint above the box has to stop before the box starts.
  local maker = MV:GetMaker()
  UI:ShareMaker()
  local shareStatus = UI.makerShareStatus.text or ""
  local shareSteps = #maker.steps
  local expectedShare = ("%d %s, %d characters - selected, press Ctrl+C."):format(
    shareSteps, shareSteps == 1 and "step" or "steps", #(UI.makerShareBox.text or ""))
  check("the ShareMaker status names the step and character counts, exactly",
    shareStatus == expectedShare, shareStatus .. " (" .. #shareStatus .. " chars)")

  UI:CopyMakerShare()
  local copyStatus = UI.makerShareStatus.text or ""
  local expectedCopy = ("%d characters - press Ctrl+C to copy.")
    :format(#(UI.makerShareBox.text or ""))
  check("the Copy status names the character count, exactly",
    copyStatus == expectedCopy, copyStatus .. " (" .. #copyStatus .. " chars)")
  check("the Load button is back to Load after Copy",
    UI.makerShareLoad:GetLabel() == "Load", tostring(UI.makerShareLoad:GetLabel()))

  local hint
  for _, regionFrame in ipairs(REGIONS) do
    if regionFrame.parent == share and regionFrame.kind == "FontString"
      and tostring(regionFrame.text or ""):sub(1, 9) == "One line:" then
      hint = regionFrame
    end
  end
  local hintText = hint and tostring(hint.text or "") or ""
  local hintLines = math.max(1, math.ceil(#hintText / charsPerLine))
  local hintHeight = hintLines * (hint and hint:GetStringHeight() or 0)
  local hintTop = hint and hint.points[1] and hint.points[1].y or 0
  local boxTopY
  for _, point in ipairs(UI.makerShareBox.points) do
    if point.point == "TOPLEFT" then boxTopY = point.y end
  end
  -- y grows downward, so the hint clears the box when its bottom sits above
  -- the box's top: a positive gap is real space between them.
  local hintGap = boxTopY and ((hintTop - hintHeight) - boxTopY) or -1
  check("the share card's hint clears the edit box by at least 4",
    hint ~= nil and boxTopY ~= nil and hintGap >= 4,
    hintLines .. " lines, " .. hintHeight .. " tall from " .. hintTop
      .. ", box top " .. tostring(boxTopY) .. ", gap " .. hintGap
      .. " at " .. charsPerLine .. " chars/line: " .. hintText)

  -- Every other way ReadMakerString refuses a paste, driven through the real
  -- Load path. The maker is emptied first so no Replace? question takes over.
  local function refusalFor(text)
    MV:ClearMakerSteps()
    UI.makerShareBox:SetText(text)
    UI:LoadMakerShare()
    return UI.makerShareStatus.text or ""
  end

  local tooManySteps = { "MVPSEQ1", "N", "priority", "none" }
  for i = 1, MV.MAKER_MAX_STEPS + 1 do
    tooManySteps[#tooManySteps + 1] = "m:" .. wideName(i)
  end
  local oversized = string.rep("x", MV.MAKER_SHARE_MAX + 1)

  local refusals = {
    { "an empty box is named",
      "", "the box is empty - paste a sequence string first" },
    { "an oversized paste names both limits",
      oversized, ("that is %d characters - a sequence string is under %d"):format(
        #oversized, MV.MAKER_SHARE_MAX) },
    { "a foreign prefix names the expected one",
      "NOPE|N|priority|none", ("this is not a MacroVaultPro sequence - it should start with %s"):format(
        MV.MAKER_SHARE_PREFIX) },
    { "a cut escape names the damaged name",
      "MVPSEQ1|%2|priority|none", "the name is damaged - a % escape is cut short" },
    { "a missing reset section is named",
      "MVPSEQ1|N|priority", "the string has no reset section" },
    { "an unknown reset choice is named",
      "MVPSEQ1|N|priority|soon", ("'soon' is not a reset choice - expected target, combat, %d-%ds or none"):format(
        MV.SEQUENCE_RESET_SECONDS_MIN, MV.SEQUENCE_RESET_SECONDS_MAX) },
    { "too many steps names both counts",
      table.concat(tooManySteps, "|"), ("the string holds %d steps - the maker holds %d"):format(
        MV.MAKER_MAX_STEPS + 1, MV.MAKER_MAX_STEPS) },
    { "a step without a kind is named",
      "MVPSEQ1|N|priority|none|zzz", "step 1 should start with s: or m:, not 'zz'" },
  }
  for _, case in ipairs(refusals) do
    local got = refusalFor(case[2])
    check(case[1], got == case[3], got .. " (" .. #got .. " chars)")
  end

  local worstLines = math.max(refusalLines, loadedLines, replaceLines, oneLines)
  check("the longest share status fits between the box and the buttons",
    statusPoint.y + worstLines * status:GetStringHeight() <= boxBottom,
    worstLines .. " lines, needs " .. (worstLines * status:GetStringHeight())
      .. " of " .. (boxBottom - statusPoint.y) .. " at " .. charsPerLine
      .. " chars/line: " .. loadedText)
end

-- The Sheet. A slot is stored by the macro's name and scope, not by a slot
-- number, so the client renumbering a macro leaves the slot where it is; a slot
-- whose macro has gone stays visible and wears the red border; and Undo puts
-- back the layout from before the last clear or move.
local sheetMacros = {
  { index = 3,  name = "Heal",   icon = 111, scope = "account" },
  { index = 9,  name = "Heal",   icon = 222, scope = "char" },
  { index = 14, name = "Ground", icon = 333, scope = "account" },
}
function MV:GetMacros() return sheetMacros end

UI.sheet, UI.sheetMacroMap, UI.sheetUndo = nil, nil, nil
MacroVaultProDB.sheet = nil

UI:DropOnSlot(1, { macro = sheetMacros[1] })
UI:DropOnSlot(2, { macro = sheetMacros[2] })
UI:DropOnSlot(3, { macro = sheetMacros[3] })

local savedSheet = MacroVaultProDB.sheet or {}
local function savedShapeOk(position, name, scope)
  local entry = savedSheet[position]
  return type(entry) == "table" and entry.name == name and entry.scope == scope
    and entry.index == nil and entry.macroIndex == nil and entry.slot == nil
end
check("a slot is saved as the macro's name and scope, not a slot number",
  savedShapeOk(1, "Heal", "account") and savedShapeOk(2, "Heal", "char")
    and savedShapeOk(3, "Ground", "account"),
  tostring(savedSheet[1] and (savedSheet[1].name .. "/" .. savedSheet[1].scope)))

check("two macros sharing a name resolve by their own scope",
  UI:SheetMacroAt(1) ~= nil and UI:SheetMacroAt(1).index == 3
    and UI:SheetMacroAt(2) ~= nil and UI:SheetMacroAt(2).index == 9,
  tostring(UI:SheetMacroAt(1) and UI:SheetMacroAt(1).index) .. " / "
    .. tostring(UI:SheetMacroAt(2) and UI:SheetMacroAt(2).index))

-- The client renumbers macros when one is deleted; the slot has to follow the
-- name, not the number it was placed at.
sheetMacros[1].index = 21
UI.sheetMacroMap = nil
check("a renumbered macro stays in its slot",
  UI:SheetMacroAt(1) ~= nil and UI:SheetMacroAt(1).index == 21,
  tostring(UI:SheetMacroAt(1) and UI:SheetMacroAt(1).index))

-- A macro that is gone leaves the slot visible and marks it with the red border.
table.remove(sheetMacros, 3)
UI.sheetMacroMap = nil
check("a slot whose macro has gone keeps its entry",
  UI:GetSheet()[3] ~= nil and UI:SheetMacroAt(3) == nil,
  tostring(UI:GetSheet()[3] and UI:GetSheet()[3].name))

local goneBorder = {}
UI:UpdateSlotBorder({
  sheetSlot = 3,
  borderEdges = { { SetColorTexture = function(_, r, g, b, a) goneBorder = { r, g, b, a } end } },
})
check("that slot wears the red border",
  goneBorder[1] == 0.72 and goneBorder[2] == 0.30 and goneBorder[3] == 0.30,
  tostring(goneBorder[1]) .. "," .. tostring(goneBorder[2]) .. "," .. tostring(goneBorder[3]))

local liveBorder = {}
UI:UpdateSlotBorder({
  sheetSlot = 1,
  borderEdges = { { SetColorTexture = function(_, r, g, b) liveBorder = { r, g, b } end } },
})
check("a slot with a live macro keeps the normal border",
  liveBorder[1] == 0.26 and liveBorder[2] == 0.23,
  tostring(liveBorder[1]) .. "," .. tostring(liveBorder[2]))

local function sheetSnapshot()
  local copy = {}
  for position, entry in pairs(UI:GetSheet()) do
    copy[position] = entry.name .. "|" .. entry.scope
  end
  return copy
end
local function sameSheet(a, b)
  for position, value in pairs(a) do
    if b[position] ~= value then return false end
  end
  for position in pairs(b) do
    if a[position] == nil then return false end
  end
  return true
end
local function describeSheet()
  local parts = {}
  for position, value in pairs(sheetSnapshot()) do parts[#parts + 1] = position .. "=" .. value end
  table.sort(parts)
  return table.concat(parts, ", ")
end

-- Undo after a clear puts back exactly the layout that was there before it.
local beforeClear = sheetSnapshot()
UI:ClearSheetSlot(1)
check("clearing a slot takes it out of the sheet and the saved layout",
  UI:GetSheet()[1] == nil and (MacroVaultProDB.sheet or {})[1] == nil,
  describeSheet())
check("undo is offered after a clear", UI.sheetUndo ~= nil)
check("undo puts the cleared slot back",
  UI:UndoSheet() == true and sameSheet(sheetSnapshot(), beforeClear), describeSheet())
check("the restored layout is saved, not only shown",
  type(MacroVaultProDB.sheet) == "table" and MacroVaultProDB.sheet[1] ~= nil
    and MacroVaultProDB.sheet[1].name == "Heal"
    and MacroVaultProDB.sheet[1].scope == "account",
  tostring(MacroVaultProDB.sheet and MacroVaultProDB.sheet[1] and MacroVaultProDB.sheet[1].name))

-- A swap is the tab's other destructive move, and undo covers it the same way.
local beforeSwap = sheetSnapshot()
UI:DropOnSlot(2, { slot = 1 })
check("dragging one slot onto another swaps them",
  UI:GetSheet()[1] ~= nil and UI:GetSheet()[2] ~= nil
    and UI:GetSheet()[1].scope == "char" and UI:GetSheet()[2].scope == "account",
  describeSheet())
check("undo puts the swapped slots back",
  UI:UndoSheet() == true and sameSheet(sheetSnapshot(), beforeSwap), describeSheet())
check("undo is one step only", UI:UndoSheet() == false)

return table.concat(log, NL) .. NL .. (FAILED and "RESULT FAIL" or "RESULT PASS")
`;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

// Each addon file runs as its own chunk with the argument the client passes, so
// its file-scope locals stay separate the way they do in the client.
const src = stubs
  + "\nlocal function __core(...)\n" + fs.readFileSync(corePath, "utf8")
  + "\nend\n__core('MacroVaultPro', {})\n"
  + "local function __ui(...)\n" + fs.readFileSync(uiPath, "utf8")
  + "\nend\n__ui('MacroVaultPro', MacroVaultPro)\n"
  + tests;

if (lauxlib.luaL_loadstring(L, to_luastring(src)) !== lua.LUA_OK) {
  console.log("FAIL load: " + to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(1);
}
if (lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) {
  console.log("FAIL runtime: " + to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(1);
}

const out = to_jsstring(lua.lua_tostring(L, -1));
console.log(out);
if (out.indexOf("RESULT PASS") === -1) process.exit(1);
