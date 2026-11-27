const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

// Parses and runs the addon's Lua against stubs: no client, no game needed.
// Run from the repo root with `bun run test:maker`.
const root = path.resolve(__dirname, "..", "..");
const corePath = path.join(root, "MacroVaultPro", "Core.lua");
const uiPath = path.join(root, "MacroVaultPro", "UI.lua");
const skinPath = path.join(root, "MacroVaultPro", "Skin.lua");
let failed = false;

for (const file of [corePath, uiPath, skinPath]) {
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
local MV = MacroVaultPro
local NL = string.char(10)
local log = {}
local function check(name, cond, extra)
  log[#log + 1] = (cond and "PASS " or "FAIL ") .. name .. (extra and ("  [" .. tostring(extra) .. "]") or "")
  if not cond then FAILED = true end
end

MacroVaultProDB = {}
MV.maker = nil
MV:GetMaker().name = "MV Combo"

local TRINKET_BODY = "#showtooltip 13" .. NL .. "/use 13"
function MV:GetMacros()
  return { { index = 5, name = "Trinket 1", icon = 135000, body = TRINKET_BODY, scope = "account" } }
end

check("add spell step", MV:AddMakerStep("spell", "Fireball", 135812))
check("add macro step", MV:AddMakerStep("macro", "Trinket 1", 135000))

local body, problems = MV:ComposeMaker()
check("compose returns text and problems only", type(problems) == "table")
check("compose runs steps in order",
  body == "#showtooltip" .. NL .. "/cast Fireball" .. NL .. "/use 13", body)
check("no problems", #problems == 0, #problems)

MV:MoveMakerStep(2, 1)
local reordered = MV:ComposeMaker()
check("reorder swaps the steps",
  reordered == "#showtooltip" .. NL .. "/use 13" .. NL .. "/cast Fireball", reordered)

MV:AddMakerStep("macro", "Gone", 1)
local _, missing = MV:ComposeMaker()
check("missing macro is reported", #missing == 1, missing[1])
MV:RemoveMakerStep(3)

MV:ClearMakerSteps()
for i = 1, MV.MAKER_MAX_STEPS do MV:AddMakerStep("spell", string.rep("A", 30), 1) end
check("step cap refuses a 13th step", not MV:AddMakerStep("spell", "One more", 1))
local longBody = MV:ComposeMaker()
local longIndex, longErr = MV:BuildMakerMacro()
check("over 255 characters is refused with a message",
  longIndex == nil and #longBody > 255 and type(longErr) == "string" and longErr:find("characters") ~= nil,
  tostring(#longBody) .. " | " .. tostring(longErr))
check("empty sequence is refused", (function()
  MV:ClearMakerSteps()
  local index = MV:BuildMakerMacro()
  return index == nil
end)())

MV:AddMakerStep("spell", "Fireball", 135812)

local created = {}
CreateMacro = function(name, icon, macroBody, perChar)
  created.name, created.icon, created.body, created.perChar = name, icon, macroBody, perChar
  return 9
end
EditMacro = function(index, name, icon, macroBody)
  created.edited = { index = index, name = name, icon = icon, body = macroBody }
  return index
end
MV.GetMacro = function(self, index)
  if index ~= 9 then return nil end
  return { index = 9, name = created.name, icon = created.icon, body = created.body, scope = "account" }
end

local index = MV:BuildMakerMacro()
check("build creates the macro", index == 9, tostring(index))
check("default name", created.name == "MV Combo", created.name)
check("first step icon used when none chosen", created.icon == 135812, tostring(created.icon))
check("built body", created.body == "#showtooltip" .. NL .. "/cast Fireball", created.body)
check("account scope", not created.perChar)

MV:AddMakerStep("spell", "Frostbolt", 116)
local rebuilt = MV:BuildMakerMacro()
check("rebuild edits the same slot", rebuilt == 9 and created.edited ~= nil and created.edited.index == 9, tostring(rebuilt))
check("rebuilt body has both steps",
  created.edited and created.edited.body == "#showtooltip" .. NL .. "/cast Fireball" .. NL .. "/cast Frostbolt",
  created.edited and created.edited.body)

MV:GetMaker().icon = 999
MV:BuildMakerMacro()
check("chosen icon is applied", created.edited and created.edited.icon == 999, created.edited and tostring(created.edited.icon))

function MV:GetMacros(self)
  return {
    { index = 5, name = "Trinket 1", icon = 135000, body = TRINKET_BODY, scope = "account" },
    { index = 9, name = "MV Combo", icon = 999, body = created.edited and created.edited.body or "", scope = "account" },
  }
end
MV:AddMakerStep("macro", "MV Combo", 999)
local _, ownProblem = MV:ComposeMaker()
check("own macro is refused as a step",
  #ownProblem == 1 and ownProblem[1]:find("itself") ~= nil, ownProblem[1])
local ownIndex, ownErr = MV:BuildMakerMacro()
check("build refuses a self-including sequence",
  ownIndex == nil and tostring(ownErr):find("itself") ~= nil, tostring(ownErr))
MV:RemoveMakerStep(3)

-- renaming the sequence renames the macro instead of orphaning it
local creates = 0
CreateMacro = function(name, icon, macroBody, perChar)
  creates = creates + 1
  return 9
end
MV:GetMaker().name = "Combo Two"
local renamedIndex = MV:BuildMakerMacro()
check("rename reuses the same slot",
  renamedIndex == 9 and created.edited ~= nil and created.edited.index == 9, tostring(renamedIndex))
check("rename renames the macro in place",
  created.edited ~= nil and created.edited.name == "Combo Two", created.edited and created.edited.name)
check("rename creates no second macro", creates == 0, creates)

-- two macros sharing a name: the step's scope decides which body is used
function MV:GetMacros(self)
  return {
    { index = 5, name = "Trinket 1", icon = 135000, body = "/use 13", scope = "account" },
    { index = 7, name = "Trinket 1", icon = 135000, body = "/use 14", scope = "char" },
  }
end
MV:AddMakerStep("macro", "Trinket 1", 135000, nil, "char")
local scopeStep = MV:GetMaker().steps[#MV:GetMaker().steps]
check("step remembers the scope it came from", scopeStep.scope == "char", scopeStep.scope)
local dupBody, dupProblems = MV:ComposeMaker()
check("scope picks the right duplicate",
  #dupProblems == 0 and dupBody:find("/use 14") ~= nil and dupBody:find("/use 13") == nil, dupBody)
MV:RemoveMakerStep(3)

MV:AddMakerStep("macro", "Trinket 1", 135000)
local _, ambiguous = MV:ComposeMaker()
check("duplicate names are refused without a scope",
  #ambiguous == 1 and ambiguous[1]:find("named") ~= nil, ambiguous[1])
MV:RemoveMakerStep(3)

local saved = MacroVaultProDB.maker
check("saved variables hold the sequence",
  type(saved) == "table" and #saved.steps == 2 and saved.steps[2].value == "Frostbolt", type(saved))
check("saved steps carry icons", saved.steps[2].icon == 116, saved.steps[2].icon)

-- CursorStep must put its reason in the fourth slot: a caller reading
-- kind, value, icon, why otherwise gets the reason in value and prints a fallback.
local ck, cv, ci, cwhy = MV:CursorStep()
check("cursor miss reports its reason in the fourth slot",
  ck == nil and cwhy ~= nil and tostring(cwhy):find("does not report") ~= nil, tostring(cwhy))

GetCursorInfo = function() return nil end
local ek, ev, ei, ewhy = MV:CursorStep()
check("empty cursor explains itself in the fourth slot",
  ek == nil and ewhy ~= nil and tostring(ewhy):find("Nothing is on the cursor") ~= nil, tostring(ewhy))

-- sequence mode: the same steps become one /castsequence the client advances
MV:ClearMakerSteps()
MV:AddMakerStep("spell", "Frostbolt", 116)
MV:AddMakerStep("spell", "Fireball", 133)
MV:SetMakerMode("sequence")
local seqBody, seqProblems = MV:ComposeMaker()
check("sequence mode writes one castsequence",
  #seqProblems == 0 and seqBody:find("/castsequence reset=target Frostbolt, Fireball") ~= nil, seqBody)
check("reset defaults to the target", MV:GetMaker().reset == "target", MV:GetMaker().reset)
MV:SetMakerReset("combat")
check("combat reset is written",
  MV:ComposeMaker():find("/castsequence reset=combat Frostbolt") ~= nil, MV:ComposeMaker())
MV:SetMakerReset("seconds")
check("seconds reset uses the stored count",
  MV:ComposeMaker():find("/castsequence reset=10 Frostbolt") ~= nil, MV:ComposeMaker())
MV:SetMakerResetSeconds(25)
check("an edited seconds count is written",
  MV:ComposeMaker():find("/castsequence reset=25 Frostbolt") ~= nil, MV:ComposeMaker())
check("seconds count is saved with the steps",
  MacroVaultProDB.maker.resetSeconds == 25, MacroVaultProDB.maker.resetSeconds)
check("zero seconds is refused", MV:SetMakerResetSeconds(0) == false)
check("a count over the cap is refused", MV:SetMakerResetSeconds(600) == false)
check("text is refused", MV:SetMakerResetSeconds("soon") == false)
check("a refused count keeps the saved one",
  MacroVaultProDB.maker.resetSeconds == 25, MacroVaultProDB.maker.resetSeconds)
MV:SetMakerResetSeconds(10)
MV:SetMakerReset("none")
local noReset = MV:ComposeMaker()
check("none drops the reset clause",
  noReset:find("/castsequence Frostbolt, Fireball") ~= nil and noReset:find("reset=") == nil, noReset)
check("reset is saved with the steps", MacroVaultProDB.maker.reset == "none", MacroVaultProDB.maker.reset)
check("cycling wraps back to target", MV:CycleMakerReset() and MV:GetMaker().reset == "target",
  MV:GetMaker().reset)
check("an unknown reset is refused", MV:SetMakerReset("hourly") == false)
check("sequence mode keeps the showtooltip header",
  seqBody:sub(1, 12) == "#showtooltip", seqBody:sub(1, 12))
check("sequence mode skips the per-step cast lines", seqBody:find("/cast Frostbolt") == nil, seqBody)
check("mode is saved", MacroVaultProDB.maker.mode == "sequence", MacroVaultProDB.maker.mode)

MV:AddMakerStep("macro", "Trinket 1", 135000)
local seqBody2, seqProblems2 = MV:ComposeMaker()
check("sequence mode names the macro step it cannot use",
  #seqProblems2 == 1 and seqProblems2[1]:find("spells only") ~= nil, seqProblems2[1])
check("the offending step keeps its name in the report",
  seqProblems2[1]:find("Trinket 1") ~= nil, seqProblems2[1])
MV:RemoveMakerStep(3)

MV:SetMakerMode("priority")
local priBody, priProblems = MV:ComposeMaker()
check("priority mode still writes one cast per step",
  #priProblems == 0 and priBody:find("/cast Frostbolt") ~= nil
    and priBody:find("/castsequence") == nil, priBody)
MV:ClearMakerSteps()

-- per-step conditions, written into whichever mode is active
MV:ClearMakerSteps()
MV:AddMakerStep("spell", "Frostbolt", 116)
MV:AddMakerStep("spell", "Fireball", 133)
check("a step starts with no conditions",
  MV:MakerStepConditionText(MV:GetMaker().steps[1]) == nil)
MV:ToggleMakerStepCondition(1, "harm")
MV:ToggleMakerStepCondition(1, "mod:shift")
local condPri = MV:ComposeMaker()
check("conditions are written in the canonical order",
  condPri:find("/cast %[mod:shift,harm%] Frostbolt") ~= nil, condPri)
check("steps without conditions stay plain",
  condPri:find("/cast Fireball") ~= nil, condPri)

MV:SetMakerMode("sequence")
local condSeq = MV:ComposeMaker()
check("conditions ride on the castsequence entry",
  condSeq:find("%[mod:shift,harm%]Frostbolt, Fireball") ~= nil, condSeq)

MV:ToggleMakerStepCondition(1, "harm")
check("switching one off keeps the rest",
  MV:ComposeMaker():find("%[mod:shift%]Frostbolt") ~= nil, MV:ComposeMaker())
check("conditions are saved with the step",
  MacroVaultProDB.maker.steps[1].conditions[1] == "mod:shift",
  MacroVaultProDB.maker.steps[1].conditions and MacroVaultProDB.maker.steps[1].conditions[1])
MV:ToggleMakerStepCondition(1, "mod:shift")
local plainSeq = MV:ComposeMaker()
check("clearing every condition leaves a plain entry",
  plainSeq:find("reset=target Frostbolt, Fireball") ~= nil and plainSeq:find("%[") == nil, plainSeq)

MV:SetMakerMode("priority")
table.insert(MV:GetMaker().steps, { kind = "macro", value = "Trinket 1", icon = 135000, conditions = { "harm" } })
local _, condProblems = MV:ComposeMaker()
check("a macro step is refused conditions",
  #condProblems == 1 and condProblems[1]:find("conditions") ~= nil, condProblems[1])
MV:RemoveMakerStep(2)
check("toggling a condition onto a macro step is refused",
  MV:ToggleMakerStepCondition(2, "harm") == false)
check("an unknown condition is refused", MV:ToggleMakerStepCondition(1, "flying") == false)
MV:ClearMakerSteps()

-- diag must say which window-skin pieces drew the window, and must still say
-- something when Skin.lua never loaded.
check("diag has a skin report", type(MV.SkinReport) == "function")
local noSkin = MV:SkinReport()
check("skin report admits Skin.lua is missing",
  tostring(noSkin):find("Skin.lua did not load") ~= nil, tostring(noSkin))

MV.Skin = { templates = { PortraitFrameTemplate = true, LargeSideTabButtonTemplate = false } }
local partSkin = MV:SkinReport()
check("skin report shows yes, fallback and not-built",
  partSkin:find("PortraitFrameTemplate=yes") ~= nil
    and partSkin:find("LargeSideTabButtonTemplate=fallback") ~= nil
    and partSkin:find("BackdropTemplate=not%-built") ~= nil, partSkin)
MV.Skin = nil

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
console.log(out);
if (failed || /FAIL/.test(out)) process.exitCode = 1;
