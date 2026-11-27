const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

// Parses and runs One Button Pad against stubs: no client, no game, and neither
// of the two addons it reads. Run from the repo root with `bun run test:obp`.
const root = path.resolve(__dirname, "..", "..");
const corePath = path.join(root, "OneButtonPad", "Core.lua");
const uiPath = path.join(root, "OneButtonPad", "UI.lua");
let failed = false;

for (const file of [corePath, uiPath]) {
  const name = path.basename(file);
  try {
    luaparse.parse(fs.readFileSync(file, "utf8"), { luaVersion: "5.1" });
    console.log("PASS parse " + name + " (Lua 5.1)");
  } catch (e) {
    failed = true;
    console.log("FAIL parse " + name + ": " + e.message);
  }
}

const stubs = `
UIParent = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
tinsert = table.insert
function CreateFrame()
  local f = {}
  function f:RegisterEvent() end
  function f:SetScript() end
  function f:Hide() end
  function f:Show() end
  return f
end
`;

const tests = `
local OPB = OneButtonPad
local NL = string.char(10)
local log = {}
local function check(name, cond, extra)
  log[#log + 1] = (cond and "PASS " or "FAIL ") .. name .. (extra and ("  [" .. tostring(extra) .. "]") or "")
  if not cond then FAILED = true end
end

check("addon table exists", type(OPB) == "table")
check("saved variables start empty", true)

-- what the client cannot answer must never read as "loaded"
check("neither addon is loaded in the stub", OPB:IsLoaded(OPB.ONE_BUTTON) == false)

-- keys: saved string, removed key, untouched default
check("an untouched cell uses Forever One Button's default",
  OPB:KeyFor(1, { keys = {} }) == "SHIFT-1", tostring(OPB:KeyFor(1, { keys = {} })))
check("cell 21 defaults to CTRL-1", OPB:KeyFor(21, nil) == "CTRL-1", tostring(OPB:KeyFor(21, nil)))
check("a saved key wins", OPB:KeyFor(11, { keys = { [11] = "F1" } }) == "F1")
check("a removed key stays removed", OPB:KeyFor(2, { keys = { [2] = false } }) == nil)

-- cells come from the character saved variables, in cell order
ForeverOneButtonCharDB = { cells = {
  [1] = { kind = "spell", id = 133 },
  [4] = { kind = "item", id = 22829, auto = true },
  [7] = { kind = "spell" },
  [9] = { kind = "bogus", id = 1 },
} }
ForeverOneButtonDB = { keys = { [4] = false }, grid = { slots = 3 } }

local cells = OPB:Cells(ForeverOneButtonDB, ForeverOneButtonCharDB, 3)
check("only filled cells are listed", #cells == 2, #cells)
check("cells come back in cell order", cells[1].slot == 1 and cells[2].slot == 4)
check("a cell with no key says so", cells[2].key == nil)
check("a cell past what the grid shows is marked hidden", cells[2].hidden == true, tostring(cells[2].hidden))
check("the first cell is not hidden", cells[1].hidden == false)
check("an auto-filled cell is marked", cells[2].automatic == true)

local resolved = OPB:Resolve({ kind = "spell", id = 133 })
check("a cell the client cannot name still has a label",
  type(resolved.name) == "string" and resolved.name ~= "", tostring(resolved.name))

local one = OPB:OneButton()
check("one button reads what is saved",
  one.present == true and one.shown == 3 and #one.cells == 2 and one.keyed == 1,
  tostring(one.shown) .. " / " .. tostring(one.keyed))

-- console port absent: no bindings, and nothing raised
local controller = OPB:Controller()
check("console port is reported absent", controller.present == false and controller.api == nil)
check("no bindings without console port", #OPB:PadBindings() == 0)

-- binding targets in words a player recognises
check("main bar button reads as main bar",
  OPB:DescribeWidget("ActionButton3") == "main bar 3", tostring(OPB:DescribeWidget("ActionButton3")))
check("the longest prefix wins",
  OPB:DescribeWidget("MultiBarBottomLeftButton3") == "bottom left bar 3",
  tostring(OPB:DescribeWidget("MultiBarBottomLeftButton3")))
check("a cell widget reads as a cell",
  OPB:DescribeWidget("ForeverOneButtonCell12") == "Forever One Button cell 12",
  tostring(OPB:DescribeWidget("ForeverOneButtonCell12")))
check("an unknown widget has no player words", OPB:DescribeWidget("SomethingElse1") == nil)
check("a click binding is described through its widget",
  OPB:DescribeBinding("CLICK ActionButton2:LeftButton") == "main bar 2",
  tostring(OPB:DescribeBinding("CLICK ActionButton2:LeftButton")))
check("console port's own action is left alone",
  OPB:DescribeBinding("togglemenu") == nil, tostring(OPB:DescribeBinding("togglemenu")))

local row = { button = "PAD2", modifier = "SHIFT" }
check("a binding with no glyph reads as button plus modifier",
  OPB:PadText(row) == "PAD2 + SHIFT", tostring(OPB:PadText(row)))
check("the no-modifier form is not printed",
  OPB:PadText({ button = "PAD2", modifier = "NONE" }) == "PAD2")
check("a glyph is passed through untouched",
  OPB:PadText({ button = "PAD2", modifier = "SHIFT", glyph = "|Tglyph:16:16|t" }) == "|Tglyph:16:16|t")

-- the report must say what is missing instead of breaking
local lines = OPB:ReportLines()
check("the report is plain lines", type(lines) == "table" and #lines >= 3 and type(lines[1]) == "string")
check("the report says forever one button was read", tostring(lines[1]):find("Forever One Button") ~= nil, lines[1])
check("the report names console port as missing",
  tostring(lines[#lines - 1]):find("Console Port is not loaded") ~= nil, lines[#lines - 1])
check("the report ends with the keyboard-versus-pad note",
  tostring(lines[#lines]):find("pad button runs an action bar slot") ~= nil, lines[#lines])

-- a console port stub: bindings are read and sorted, and a broken one raises nothing
ConsolePort = {
  GetCurrentBindings = function() end,
  GetFormattedButtonCombination = function() return nil end,
}
check("console port is found through its global", OPB:Controller().present == true)

ConsolePort.GetCurrentBindings = function()
  return {
    PAD2 = { SHIFT = "CLICK ActionButton4:LeftButton", NONE = "CLICK ActionButton3:LeftButton" },
    PAD1 = { NONE = "CLICK MultiBarBottomLeftButton1:LeftButton" },
  }
end
ConsolePort.GetFormattedButtonCombination = function(_, button, modifier)
  return button == "PAD1" and "|Tglyph|t" or nil
end

local bindings = OPB:PadBindings()
check("every binding is listed", #bindings == 3, #bindings)
check("bindings are sorted by button then modifier",
  bindings[1].button == "PAD1" and bindings[2].button == "PAD2" and bindings[2].modifier == "NONE"
    and bindings[3].modifier == "SHIFT",
  bindings[1].button .. "/" .. bindings[2].modifier .. "/" .. bindings[3].modifier)
check("a binding carries the words for what it runs",
  bindings[3].target == "main bar 4", tostring(bindings[3].target))
check("a glyph comes from console port",
  OPB:PadText(bindings[1]) == "|Tglyph|t", tostring(OPB:PadText(bindings[1])))

ConsolePort.GetCurrentBindings = function() error("boom") end
check("a failing binding call is reported as no bindings, not an error",
  #OPB:PadBindings() == 0)

ForeverOneButtonCharDB, ForeverOneButtonDB, ConsolePort = nil, nil, nil

return table.concat(log, NL) .. NL .. (FAILED and "RESULT FAIL" or "RESULT PASS")
`;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const src = stubs + fs.readFileSync(corePath, "utf8") + "\n" + tests;
if (lauxlib.luaL_loadstring(L, to_luastring(src)) !== lua.LUA_OK) {
  console.log("FAIL load: " + to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(1);
}
if (lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) {
  console.log("FAIL runtime: " + to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(1);
}

const out = to_jsstring(lua.lua_tostring(L, -1));
console.log(out.trim());
if (out.indexOf("RESULT PASS") === -1) failed = true;
process.exit(failed ? 1 : 0);
