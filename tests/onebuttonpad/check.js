const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

// Parses and runs One Button Pad against stubs: no client, no game, and neither
// of the two addons it reads. Run from the repo root with `bun run test:obp`.
const root = path.resolve(__dirname, "..", "..");
const corePath = path.join(root, "OneButtonPad", "Core.lua");
const uiPath = path.join(root, "OneButtonPad", "UI.lua");
const tocPath = path.join(root, "OneButtonPad", "OneButtonPad.toc");
let failed = false;

const sources = new Map();
for (const file of [corePath, uiPath]) {
  const name = path.basename(file);
  const text = fs.readFileSync(file, "utf8");
  sources.set(name, text);
  try {
    luaparse.parse(text, { luaVersion: "5.1" });
    console.log("PASS parse " + name + " (Lua 5.1)");
  } catch (e) {
    failed = true;
    console.log("FAIL parse " + name + ": " + e.message);
  }
}

// This addon is for Forever WoW alone: Console Port must not be named anywhere.
const FORBIDDEN = [
  "ConsolePort", "Console Port", "GetCurrentBindings", "GetFormattedButtonCombination",
  "PadBindings", "DescribeBinding", "DescribeWidget", "Gamepad", "ActionButton",
];
for (const [name, text] of sources) {
  const hits = FORBIDDEN.filter((word) => text.includes(word));
  if (hits.length) {
    failed = true;
    console.log("FAIL " + name + " still names Console Port: " + hits.join(", "));
  }
}
if (!failed) console.log("PASS no Console Port reference in Core.lua or UI.lua");

const toc = fs.readFileSync(tocPath, "utf8");
const tocHits = FORBIDDEN.filter((word) => toc.includes(word));
const optional = (toc.match(/^##\s*OptionalDeps:(.*)$/m) || [, ""])[1].trim();
if (tocHits.length) {
  failed = true;
  console.log("FAIL OneButtonPad.toc still names Console Port: " + tocHits.join(", "));
} else if (optional !== "ForeverOneButton") {
  failed = true;
  console.log("FAIL OneButtonPad.toc OptionalDeps is '" + optional + "', expected ForeverOneButton");
} else {
  console.log("PASS .toc depends on Forever One Button only (" + optional + ")");
}

const stubs = `
UIParent = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { messages = {} }
function DEFAULT_CHAT_FRAME.AddMessage(frame, message)
  frame.messages[#frame.messages + 1] = tostring(message)
end
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
check("the version is 0.1.1", OPB.VERSION == "0.1.1", tostring(OPB.VERSION))
check("the build stamp is today's", OPB.BUILD == "2026-11-28a", tostring(OPB.BUILD))

-- what the client cannot answer must never read as "loaded"
check("forever one button is not loaded in the stub", OPB:IsLoaded(OPB.ONE_BUTTON) == false)
check("no other addon is treated as forever one button", OPB:IsLoaded("ConsolePort") == false)
check("the addon only knows one name", OPB.ONE_BUTTON == "ForeverOneButton")

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
  one.present == true and one.shown == 3 and #one.cells == 2 and one.keyed == 1 and one.keyless == 1,
  tostring(one.shown) .. " / " .. tostring(one.keyed) .. " / " .. tostring(one.keyless))

-- the report must say what is there, and count the cells no chord presses
local lines = OPB:ReportLines()
check("the report is plain lines", type(lines) == "table" and #lines >= 4 and type(lines[1]) == "string")
check("the report says forever one button was read",
  tostring(lines[1]):find("Forever One Button") ~= nil, lines[1])
check("the report counts the cells with no key",
  table.concat(lines, NL):find("no chord presses them") ~= nil)
check("the report ends with the read-only note",
  tostring(lines[#lines]):find("read%-only") ~= nil, lines[#lines])

-- diag must name the build and the reads, and never mention a pad binding
local before = #DEFAULT_CHAT_FRAME.messages
OPB:Diag()
local diag = table.concat(DEFAULT_CHAT_FRAME.messages, NL, before + 1)
check("diag prints the build stamp", diag:find(OPB.BUILD, 1, true) ~= nil)
check("diag names the reads it makes", diag:find("reads db yes") ~= nil)
check("diag says the window is not built yet", diag:find("window not built") ~= nil)

ForeverOneButtonCharDB, ForeverOneButtonDB = nil, nil
local empty = OPB:ReportLines()
check("an unloaded addon is reported, not crashed",
  tostring(empty[1]):find("not loaded") ~= nil, empty[1])

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
