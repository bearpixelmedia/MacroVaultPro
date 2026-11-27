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
  check("the status line clears the buttons below it",
    statusPoint.y >= 8 + bottomButtonHeight + 8,
    statusPoint.y .. " vs buttons top " .. (8 + bottomButtonHeight))
  check("two status lines fit between the buttons and the box",
    boxBottom ~= nil and statusPoint.y + 2 * status:GetStringHeight() <= boxBottom,
    boxBottom and (statusPoint.y + 2 * status:GetStringHeight()) or "no box bottom")
  check("the status line spans the box and stays inside the card",
    status.width == share.width - 24 and statusPoint.x + status.width <= share.width - 12,
    status.width .. " in " .. share.width)
end

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
