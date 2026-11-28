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
const libPath = path.join(root, "MacroVaultPro", "Library.lua");
const tocPath = path.join(root, "MacroVaultPro", "MacroVaultPro.toc");
let failed = false;

for (const file of [corePath, uiPath, skinPath, libPath]) {
  const name = path.basename(file);
  try {
    luaparse.parse(fs.readFileSync(file, "utf8"), { luaVersion: "5.1" });
    console.log("PASS parse " + name + " (Lua 5.1)");
  } catch (e) {
    failed = true;
    console.log("FAIL parse " + name + ": " + e.message);
  }
}

// README.md and the CurseForge listing count things and name a version. These
// read those claims from the files the client loads, so a count that drifts, or
// a file added to the folder but left out of the .toc, fails here.
function docCheck(name, ok, extra) {
  console.log((ok ? "PASS " : "FAIL ") + name + (extra !== undefined ? "  [" + extra + "]" : ""));
  if (!ok) failed = true;
}

const coreSource = fs.readFileSync(corePath, "utf8");
const uiSource = fs.readFileSync(uiPath, "utf8");
const tocSource = fs.readFileSync(tocPath, "utf8");
const notesSource = fs.readFileSync(path.join(root, "media-kit", "release-notes.md"), "utf8");

const tocVersion = (tocSource.match(/^##\s*Version:\s*(.+?)\s*$/m) || [])[1];
const coreVersion = (coreSource.match(/MV\.VERSION\s*=\s*"([^"]+)"/) || [])[1];
const stamp = (coreSource.match(/MV\.BUILD\s*=\s*"([^"]+)"/) || [])[1];
docCheck("the .toc and the addon report one version",
  !!tocVersion && tocVersion === coreVersion, tocVersion + " / " + coreVersion);
docCheck("the build stamp is dated and lettered", /^\d{4}-\d{2}-\d{2}[a-z]{2}$/.test(stamp || ""), stamp);
docCheck("release-notes has a section for the installed version",
  !!tocVersion && new RegExp("^## " + tocVersion.replace(/\./g, "\\.") + "\\s*$", "m").test(notesSource),
  tocVersion);

// The in-game checklist's build line and its selftest expectation are moved by
// hand with every install, and both have gone stale before. Read them as a claim:
// the line names both addons, so each version and stamp is checked against its
// own .toc and build constant.
const checklistPath = path.join(root, "docs", "in-game-checklist.md");
const checklistSource = fs.existsSync(checklistPath) ? fs.readFileSync(checklistPath, "utf8") : "";
const installedLine = checklistSource.match(/Installed build(?:s)?:\s*\*\*MacroVaultPro\s+([^*]+)\*\*,\s+stamp `\[([^\]]+)\]`/);
docCheck("the in-game checklist names the installed version and stamp",
  !!installedLine && installedLine[1] === tocVersion && installedLine[2] === stamp,
  installedLine ? installedLine[1] + " / " + installedLine[2] : "no installed-build line");
docCheck("the checklist's selftest line expects that same build",
  !!tocVersion && checklistSource.includes("reports `" + tocVersion + "`, build `" + stamp + "`"),
  tocVersion + " / " + stamp);

const obpTocSource = fs.readFileSync(path.join(root, "OneButtonPad", "OneButtonPad.toc"), "utf8");
const obpCoreSource = fs.readFileSync(path.join(root, "OneButtonPad", "Core.lua"), "utf8");
const obpVersion = (obpTocSource.match(/^##\s*Version:\s*(.+?)\s*$/m) || [])[1];
const obpStamp = (obpCoreSource.match(/OPB\.BUILD\s*=\s*"([^"]+)"/) || [])[1];
const obpInstalledLine = checklistSource.match(/\*\*One Button Pad\s+([^*]+)\*\*,\s+stamp `\[([^\]]+)\]`/);
docCheck("the in-game checklist names the installed One Button Pad version and stamp",
  !!obpVersion && !!obpStamp && !!obpInstalledLine &&
    obpInstalledLine[1] === obpVersion && obpInstalledLine[2] === obpStamp,
  obpInstalledLine
    ? obpInstalledLine[1] + " / " + obpInstalledLine[2] + " vs " + obpVersion + " / " + obpStamp
    : "no installed-build line");

// Section 5 also quotes the load line chat shows. The prefix carries colour codes
// and ends in two spaces, so strip the codes and hold the doc to what renders.
const obpPrefix = ((obpCoreSource.match(/local PREFIX = "([^"]*)"/) || [])[1] || "")
  .replace(/\|c[0-9a-fA-F]{8}/g, "")
  .replace(/\|r/g, "");
const obpLoadedLine = "`" + obpPrefix + "v" + (obpVersion || "") + " loaded - /obp`";
docCheck("the checklist's load line expects that same version",
  !!obpVersion && !!obpPrefix && checklistSource.includes(obpLoadedLine),
  checklistSource.includes(obpLoadedLine)
    ? obpLoadedLine.slice(1, -1)
    : "expected " + obpLoadedLine);

// Section 5 tells the owner what `/obp diag` prints; the addon formats that line
// with two spaces, so the checklist has to quote it in that exact shape.
const obpDiagLine = checklistSource.match(/`addon (\S+) {2}build (\S+)`/);
docCheck("the checklist's /obp diag line expects that same build",
  !!obpDiagLine && obpDiagLine[1] === obpVersion && obpDiagLine[2] === obpStamp,
  obpDiagLine
    ? obpDiagLine[1] + " / " + obpDiagLine[2] + " vs " + obpVersion + " / " + obpStamp
    : "no /obp diag line");

const tocFiles = tocSource.split(/\r?\n/).map((line) => line.trim()).filter((line) => line.endsWith(".lua"));
const luaFiles = fs.readdirSync(path.join(root, "MacroVaultPro")).filter((name) => name.endsWith(".lua")).sort();
docCheck("the .toc loads every .lua in the addon folder, and nothing else",
  luaFiles.every((name) => tocFiles.includes(name)) && tocFiles.length === luaFiles.length,
  tocFiles.join(","));

const iconLine = (tocSource.match(/^##\s*IconTexture:\s*(.+?)\s*$/m) || [])[1];
const iconPath = iconLine
  ? path.join(root, "MacroVaultPro", iconLine.replace(/^Interface[\\/]AddOns[\\/]MacroVaultPro[\\/]/, "").replace(/\\/g, "/"))
  : null;
docCheck("the .toc icon exists on disk", !!iconPath && fs.existsSync(iconPath), iconLine);

// README.md says the addon-list icon is a 64x64 TGA; the size lives in its header.
const tgaFile = path.join(root, "MacroVaultPro", "Media", "icon.tga");
const tga = fs.existsSync(tgaFile) ? fs.readFileSync(tgaFile) : null;
docCheck("the addon-list icon is the documented 64x64 TGA",
  !!tga && tga.length > 18 && tga.readUInt16LE(12) === 64 && tga.readUInt16LE(14) === 64,
  tga && tga.length > 18 ? tga.readUInt16LE(12) + "x" + tga.readUInt16LE(14) : "missing");

const sheetCols = Number((uiSource.match(/SHEET_COLUMNS\s*=\s*(\d+)/) || [])[1]);
const sheetRows = Number((uiSource.match(/SHEET_ROWS\s*=\s*(\d+)/) || [])[1]);
docCheck("the sheet has the documented 36 slots", sheetCols * sheetRows === 36, sheetCols + "x" + sheetRows);

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
check("reset defaults to the target", MV:ResetClause() == "reset=target", MV:ResetClause())
MV:SetMakerReset("target", false)
MV:SetMakerReset("combat", true)
check("combat reset is written",
  MV:ComposeMaker():find("/castsequence reset=combat ") ~= nil, MV:ComposeMaker())
MV:SetMakerReset("target", true)
MV:SetMakerReset("combat", false)
MV:SetMakerReset("seconds", true)
check("target and the seconds field combine",
  MV:ComposeMaker():find("/castsequence reset=target/10 ") ~= nil, MV:ComposeMaker())
MV:SetMakerResetSeconds(25)
check("an edited seconds count combines too",
  MV:ComposeMaker():find("/castsequence reset=target/25 ") ~= nil, MV:ComposeMaker())
check("seconds count is saved with the steps",
  MacroVaultProDB.maker.resetSeconds == 25, MacroVaultProDB.maker.resetSeconds)
check("zero seconds is refused", MV:SetMakerResetSeconds(0) == false)
check("a count over the cap is refused", MV:SetMakerResetSeconds(600) == false)
check("text is refused", MV:SetMakerResetSeconds("soon") == false)
check("a refused count keeps the saved one",
  MacroVaultProDB.maker.resetSeconds == 25, MacroVaultProDB.maker.resetSeconds)
MV:SetMakerReset("combat", true)
check("three choices combine in their fixed order",
  MV:ComposeMaker():find("/castsequence reset=target/combat/25 ") ~= nil, MV:ComposeMaker())
MV:SetMakerReset("target", false)
MV:SetMakerReset("combat", false)
MV:SetMakerReset("seconds", false)
local noReset = MV:ComposeMaker()
check("all off drops the reset clause",
  noReset:find("/castsequence Frostbolt, Fireball") ~= nil and noReset:find("reset=") == nil, noReset)
check("resets are saved with the steps", next(MacroVaultProDB.maker.resets) == nil,
  next(MacroVaultProDB.maker.resets))
local legacyReset = MV:ReadMakerResets({ reset = "seconds" })
check("a legacy single choice still loads",
  legacyReset.seconds == true and next(legacyReset, "seconds") == nil)
check("an unknown reset is refused", MV:SetMakerReset("hourly", true) == false)
MV:SetMakerReset("target", true)
MV:SetMakerResetSeconds(10)
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

-- contradictory modifiers: nomod with any mod: never fires
MV:AddMakerStep("spell", "Frostbolt", 116)
MV:ToggleMakerStepCondition(1, "nomod")
check("nomod on its own is written",
  MV:ComposeMaker():find("/cast %[nomod%] Frostbolt") ~= nil, MV:ComposeMaker())
local okConf, whyConf = MV:ToggleMakerStepCondition(1, "mod:shift")
check("mod:shift is refused beside nomod",
  okConf == false and tostring(whyConf):find("never pick") ~= nil, tostring(whyConf))
check("the refused toggle changes nothing",
  MV:MakerStepConditionText(MV:GetMaker().steps[1]) == "nomod", MV:MakerStepConditionText(MV:GetMaker().steps[1]))
MV:ToggleMakerStepCondition(1, "nomod")
check("a modifier is accepted once nomod is off", MV:ToggleMakerStepCondition(1, "mod:shift") == true)
local okConf2, whyConf2 = MV:ToggleMakerStepCondition(1, "nomod")
check("nomod is refused beside a modifier",
  okConf2 == false and tostring(whyConf2):find("mod:shift") ~= nil, tostring(whyConf2))

-- a step saved with the pair is flagged, not silently written
table.insert(MV:GetMaker().steps, { kind = "spell", value = "Fireball", icon = 133, conditions = { "nomod", "mod:shift" } })
local _, badProblems = MV:ComposeMaker()
check("a contradictory saved step is reported",
  #badProblems == 1 and badProblems[1]:find("contradict") ~= nil, badProblems[1])
MV:SetMakerMode("sequence")
local badSeq = MV:ComposeMaker()
check("a contradictory step is left out of the castsequence",
  badSeq:find("Fireball") == nil, badSeq)
MV:SetMakerMode("priority")
MV:ClearMakerSteps()

-- harm and help can never both hold either
MV:ClearMakerSteps()
MV:AddMakerStep("spell", "Frostbolt", 116)
MV:ToggleMakerStepCondition(1, "harm")
local okHH, whyHH = MV:ToggleMakerStepCondition(1, "help")
check("help is refused beside harm",
  okHH == false and tostring(whyHH):find("help") ~= nil and tostring(whyHH):find("harm") ~= nil,
  tostring(whyHH))
MV:ToggleMakerStepCondition(1, "harm")
check("help is accepted once harm is off", MV:ToggleMakerStepCondition(1, "help") == true)
check("harm and help together are reported",
  (function()
    table.insert(MV:GetMaker().steps, { kind = "spell", value = "Fireball", icon = 133,
      conditions = { "harm", "help" } })
    local _, problems = MV:ComposeMaker()
    return #problems == 1 and problems[1]:find("contradict") ~= nil
  end)())
MV:SetMakerMode("sequence")
check("the harm/help step is left out of the castsequence",
  MV:ComposeMaker():find("Fireball") == nil, MV:ComposeMaker())
MV:SetMakerMode("priority")
MV:ClearMakerSteps()

-- per-step targets share the bracket with conditions, in both modes
MV:ClearMakerSteps()
MV:AddMakerStep("spell", "Frostbolt", 116)
MV:AddMakerStep("spell", "Fireball", 133)
check("a step starts without a target", MV:MakerConditionClause(MV:GetMaker().steps[1]) == nil)
MV:SetMakerStepTarget(1, "mouseover")
check("a target alone writes its own bracket",
  MV:ComposeMaker():find("/cast %[@mouseover%] Frostbolt") ~= nil, MV:ComposeMaker())
MV:ToggleMakerStepCondition(1, "harm")
check("the target sits before the conditions",
  MV:ComposeMaker():find("%[@mouseover,harm%] Frostbolt") ~= nil, MV:ComposeMaker())
MV:SetMakerMode("sequence")
check("the target rides on the castsequence entry",
  MV:ComposeMaker():find("%[@mouseover,harm%]Frostbolt, Fireball") ~= nil, MV:ComposeMaker())
MV:SetMakerMode("priority")
check("targets are saved with the step",
  MacroVaultProDB.maker.steps[1].target == "mouseover", MacroVaultProDB.maker.steps[1].target)
MV:SetMakerStepTarget(1, "cursor")
check("@cursor goes into the same bracket",
  MV:ComposeMaker():find("/cast %[@cursor,harm%] Frostbolt") ~= nil, MV:ComposeMaker())
MV:SetMakerStepTarget(1, "none")
check("@none is a target of its own, not a clear",
  MV:ComposeMaker():find("/cast %[@none,harm%] Frostbolt") ~= nil, MV:ComposeMaker())
check("@none is saved with the step",
  MacroVaultProDB.maker.steps[1].target == "none", MacroVaultProDB.maker.steps[1].target)
MV:SetMakerStepTarget(1, "clear")
check("clearing the target keeps the conditions",
  MV:ComposeMaker():find("/cast %[harm%] Frostbolt") ~= nil, MV:ComposeMaker())
check("an unknown target is refused", MV:SetMakerStepTarget(1, "pet") == false)
MV:AddMakerStep("macro", "Trinket 1", 135000)
check("a macro step refuses a target", MV:SetMakerStepTarget(3, "player") == false)
MV:ClearMakerSteps()

-- a sequence travels as one string: export, import, and everything refused
MV:ClearMakerSteps()
MV:GetMaker().name = "Heals"
MV:SetMakerMode("sequence")
MV:SetMakerReset("target", true)
MV:SetMakerReset("combat", true)
MV:SetMakerReset("seconds", true)
MV:SetMakerResetSeconds(25)
MV:AddMakerStep("spell", "Flash Heal", 135907)
MV:SetMakerStepTarget(1, "mouseover")
MV:ToggleMakerStepCondition(1, "help")
-- two macros share this name in the stub list, so the scope has to be named
MV:AddMakerStep("macro", "Trinket 1", 135000, nil, "account")

local shared = MV:ExportMakerString()
check("export is one line", shared:find(NL) == nil and #shared < MV.MAKER_SHARE_MAX, shared)
check("export starts with its prefix", shared:sub(1, 8) == "MVPSEQ1|", shared)
check("export carries the reset and the bracket",
  shared:find("sequence|target%+combat%+25|") ~= nil
    and shared:find("s:Flash Heal@mouseover%*help") ~= nil
    and shared:find("m:Trinket 1#a") ~= nil, shared)

MV:ClearMakerSteps()
MV:GetMaker().name = "MV Combo"
MV:SetMakerMode("priority")
MV:SetMakerReset("target", false)
MV:SetMakerReset("combat", false)
MV:SetMakerReset("seconds", false)
MV:SetMakerResetSeconds(10)

local okLoad, loadedCount = MV:ImportMakerString(shared)
check("import accepts what export wrote", okLoad == true and loadedCount == 2,
  tostring(okLoad) .. " " .. tostring(loadedCount))
check("import restores the name and mode",
  MV:GetMaker().name == "Heals" and MV:GetMaker().mode == "sequence",
  MV:GetMaker().name .. "/" .. MV:GetMaker().mode)
check("import restores every reset choice",
  MV:GetMaker().resets.target == true and MV:GetMaker().resets.combat == true
    and MV:GetMaker().resets.seconds == true and MV:GetMaker().resetSeconds == 25,
  tostring(MV:GetMaker().resetSeconds))
check("import restores the target and conditions",
  MV:GetMaker().steps[1].target == "mouseover"
    and MV:MakerStepConditionText(MV:GetMaker().steps[1]) == "help",
  tostring(MV:GetMaker().steps[1].target))
check("import restores a macro step's scope", MV:GetMaker().steps[2].scope == "account",
  MV:GetMaker().steps[2].scope)
check("a round trip writes the same string again", MV:ExportMakerString() == shared, MV:ExportMakerString())

local function refuses(text, needle)
  local ok, why = MV:ImportMakerString(text)
  return ok == false and type(why) == "string" and why:find(needle) ~= nil
end
check("a foreign string is refused", refuses("hello there", "not a MacroVaultPro sequence"))
check("an empty box is refused", refuses("   ", "empty"))
check("an unknown mode is refused", refuses("MVPSEQ1|N|fancy|none", "not a mode"))
check("an unknown reset is refused", refuses("MVPSEQ1|N|sequence|target+99", "not a reset choice"))
check("an unknown target is refused", refuses("MVPSEQ1|N|priority|target|s:Frostbolt@pet", "asks for @pet"))
check("an unknown condition is refused", refuses("MVPSEQ1|N|priority|target|s:Frostbolt*flying", "never writes"))
check("a contradictory pair is refused", refuses("MVPSEQ1|N|priority|target|s:Frostbolt*harm,help", "contradict"))
check("a target on a macro step is refused",
  refuses("MVPSEQ1|N|priority|target|m:Trinket 1@focus", "only spell steps"))
check("a nameless step is refused", refuses("MVPSEQ1|N|priority|target|s:", "has no name"))
check("a step without a kind is refused", refuses("MVPSEQ1|N|priority|target|Frostbolt", "should start with s: or m:"))
check("too many steps are refused",
  refuses("MVPSEQ1|N|priority|target" .. string.rep("|s:A", MV.MAKER_MAX_STEPS + 1), "holds 12"))
check("a cut escape is refused", refuses("MVPSEQ1|N|priority|target|s:Frost%2", "damaged"))
check("a refused import changes nothing",
  MV:GetMaker().name == "Heals" and #MV:GetMaker().steps == 2,
  MV:GetMaker().name .. " " .. #MV:GetMaker().steps)

-- the card validates a paste before it asks to replace anything, so reading a
-- string has to leave the maker exactly as it was
local beforeRead = MV:ExportMakerString()
local readSpec = MV:ReadMakerString("MVPSEQ1|Other|sequence|target+5|s:Frostbolt@cursor")
check("reading a string writes nothing",
  type(readSpec) == "table" and MV:ExportMakerString() == beforeRead
    and MV:GetMaker().name == "Heals" and #MV:GetMaker().steps == 2,
  MV:GetMaker().name .. " " .. #MV:GetMaker().steps)
check("the spec carries what the string said",
  readSpec and readSpec.name == "Other" and readSpec.mode == "sequence"
    and readSpec.resets.target == true and readSpec.resets.seconds == true
    and readSpec.seconds == 5 and readSpec.steps[1].target == "cursor",
  readSpec and readSpec.steps[1].target)
check("a bad string reads as nil and a reason",
  (function()
    local spec, why = MV:ReadMakerString("MVPSEQ1|N|priority|target|s:Frostbolt@pet")
    return spec == nil and type(why) == "string" and why:find("asks for @pet") ~= nil
      and why:find("@cursor") ~= nil and why:find("@none") ~= nil
  end)())

-- reserved characters survive the trip, so a name with a delimiter is not mangled
MV:ClearMakerSteps()
MV:GetMaker().name = "A|B"
MV:AddMakerStep("spell", "Odd|Spell, One", 1)
local odd = MV:ExportMakerString()
check("reserved characters are escaped", odd:find("Odd|Spell") == nil and odd:find("A|B") == nil, odd)
local okOdd = MV:ImportMakerString(odd)
check("an escaped name survives the round trip",
  okOdd == true and MV:GetMaker().name == "A|B" and MV:GetMaker().steps[1].value == "Odd|Spell, One",
  MV:GetMaker().name .. " / " .. tostring(MV:GetMaker().steps[1] and MV:GetMaker().steps[1].value))

-- a macro step the new owner does not have is reported, not refused
local okGone, _, goneMissing = MV:ImportMakerString("MVPSEQ1|N|priority|none|m:Gone")
check("import names the macro steps it cannot find",
  okGone == true and goneMissing and goneMissing[1] == "Gone", goneMissing and goneMissing[1])

-- @cursor and @none travel like any other target
MV:ClearMakerSteps()
MV:GetMaker().name = "Ground"
MV:AddMakerStep("spell", "Rain of Fire", 1)
MV:SetMakerStepTarget(1, "cursor")
local groundText = MV:ExportMakerString()
check("export writes @cursor", groundText:find("s:Rain of Fire@cursor") ~= nil, groundText)
local okGround = MV:ImportMakerString(groundText)
check("@cursor survives the round trip",
  okGround == true and MV:GetMaker().steps[1].target == "cursor", tostring(okGround))
MV:SetMakerStepTarget(1, "none")
local noneText = MV:ExportMakerString()
check("@none is not read back as no target",
  noneText:find("s:Rain of Fire@none") ~= nil
    and MV:ImportMakerString(noneText) == true and MV:GetMaker().steps[1].target == "none",
  noneText)
check("none writes no reset clause",
  MV:ResetClause() == "" and next(MV:GetMaker().resets) == nil, MV:ResetClause())

-- a repeated error folds into one entry with a count and a last-seen time
MacroVaultProDB.errors, MacroVaultProDB.otherErrors = {}, {}
MV:LogError("Interface/AddOns/Other/Core.lua:7: boom", "", true)
MV:LogError("Interface/AddOns/Other/Core.lua:7: boom", "", true)
MV:LogError("Interface/AddOns/Other/Core.lua:7: boom", "", true)
MV:LogError("Interface/AddOns/Other/Core.lua:9: different", "", true)
local otherLog = MacroVaultProDB.otherErrors
check("a repeated error keeps one entry", #otherLog == 2, #otherLog)
check("the repeat carries its count", otherLog[2].count == 3 and otherLog[1].count == 1,
  tostring(otherLog[1].count) .. "/" .. tostring(otherLog[2].count))
check("the repeat records when it was last seen", type(otherLog[2].last) == "string",
  tostring(otherLog[2].last))
check("the log text shows the count", MV:ErrorsText():find("x3", 1, true) ~= nil)
check("the header counts every sighting", MV:ErrorsText():find("4 sightings", 1, true) ~= nil,
  MV:ErrorsText())

-- a log written by an older build folds its duplicates when it loads
MacroVaultProDB.otherErrors = {
  { when = "2026-01-02 10:00:00", text = "same" },
  { when = "2026-01-03 10:00:00", text = "same" },
  { when = "2026-01-01 10:00:00", text = "same" },
}
MV:FoldRepeats()
local folded = MacroVaultProDB.otherErrors
check("saved repeats fold on load", #folded == 1 and folded[1].count == 3
  and folded[1].when == "2026-01-01 10:00:00" and folded[1].last == "2026-01-03 10:00:00",
  tostring(#folded) .. " / " .. tostring(folded[1] and folded[1].count))

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

-- The counts README.md and the listing carry, read from the files that ship.
check("the documented twelve client tools are twelve", #MV.TOOLS == 12, #MV.TOOLS)
check("the documented 16-character name limit is 16", MV.MAX_NAME == 16, MV.MAX_NAME)
check("the documented 255-character body limit is 255", MV.MAX_BODY == 255, MV.MAX_BODY)
check("the documented 12-step maker cap is 12", MV.MAKER_MAX_STEPS == 12, MV.MAKER_MAX_STEPS)
check("the documented 26 ready-made macros are 26", #MV.LIBRARY == 26, #MV.LIBRARY)
local groups = {}
for _, entry in ipairs(MV.LIBRARY) do
  groups[entry.group] = (groups[entry.group] or 0) + 1
end
check("the library splits into the documented 10 / 11 / 5",
  groups.Targeting == 10 and groups.Utility == 11 and groups.Development == 5,
  tostring(groups.Targeting) .. "/" .. tostring(groups.Utility) .. "/" .. tostring(groups.Development))

-- The description promises a bounded log: 20 of the addon's own errors and 10
-- raised elsewhere. Log past both limits and read what the stores keep.
MacroVaultProDB.errors, MacroVaultProDB.otherErrors = {}, {}
for i = 1, 25 do MV:LogError("own " .. i .. ".lua:1: boom") end
for i = 1, 15 do MV:LogError("Interface/AddOns/Other/Core.lua:" .. i .. ": boom", "", true) end
check("the log keeps the last 20 of its own errors",
  #MacroVaultProDB.errors == 20, #MacroVaultProDB.errors)
check("the log keeps up to 10 raised by another addon",
  #MacroVaultProDB.otherErrors == 10, #MacroVaultProDB.otherErrors)

-- The listing promises that a tool runs the handler the client registered for
-- its command, and that a command with no handler goes through the chat parser
-- rather than being called missing.
local ran, seenRest = 0, nil
SlashCmdList["FSTACK"] = function(rest) ran = ran + 1 seenRest = rest end
SLASH_FSTACK1 = "/fstack"
check("a tool runs the client's registered handler",
  MV:RunTool({ cmd = "/fstack true" }) == true and ran == 1 and seenRest == "true",
  tostring(ran) .. " / " .. tostring(seenRest))

local sent
ChatFrame1EditBox = {
  text = "half typed",
  SetText = function(self, text) self.text = text end,
  GetText = function(self) return self.text end,
}
ChatEdit_SendText = function(box) sent = box.text; return true end
check("a command with no handler is handed to the chat parser",
  MV:RunSlash("/api") == true and sent == "/api", tostring(sent))
check("a half-typed chat line is put back",
  ChatFrame1EditBox.text == "half typed", tostring(ChatFrame1EditBox.text))

ChatFrame1EditBox = nil
local missingOk, missingErr = MV:RunSlash("/notacommand")
check("a command that is really missing is reported",
  missingOk == false and tostring(missingErr):find("not available") ~= nil, tostring(missingErr))

-- Opening the window reads the slot limits from the client and falls back to the
-- numbers the description quotes when the client exposes none.
MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS, Constants = 18, 12, nil
local clientLayout = MV:GetLayout(true)
check("the layout reads the client's slot limits",
  clientLayout.accountSlots == 18 and clientLayout.characterSlots == 12
    and clientLayout.source == "client limits",
  tostring(clientLayout.accountSlots) .. "/" .. tostring(clientLayout.characterSlots))

MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS, Constants = nil, nil, nil
local defaultLayout = MV:GetLayout(true)
check("with no client limit the layout shows the documented 120 / 30",
  defaultLayout.accountSlots == 120 and defaultLayout.characterSlots == 30
    and defaultLayout.source == "built-in defaults",
  tostring(defaultLayout.accountSlots) .. "/" .. tostring(defaultLayout.characterSlots))

-- Nothing is created, changed or picked up while in combat: the guard sits on
-- every write path, not only on the window's buttons.
local writes = 0
local createBefore = CreateMacro
CreateMacro = function() writes = writes + 1 return 9 end
InCombatLockdown = function() return true end
local cIndex, cErr = MV:CreateMacro("Combat", "/cast Frostbolt")
local uIndex, uErr = MV:UpdateMacro(9, "Combat", "/cast Frostbolt", 1)
local pOk, pErr = MV:Pickup(9)
InCombatLockdown = nil
CreateMacro = createBefore
check("creating a macro is refused in combat",
  cIndex == nil and tostring(cErr):find("combat") ~= nil, tostring(cErr))
check("changing a macro is refused in combat",
  uIndex == nil and tostring(uErr):find("combat") ~= nil, tostring(uErr))
check("picking a macro up is refused in combat",
  pOk == false and tostring(pErr):find("combat") ~= nil, tostring(pErr))
check("no macro write reaches the client in combat", writes == 0, writes)

return table.concat(log, NL) .. NL .. (FAILED and "RESULT FAIL" or "RESULT PASS")
`;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
// Library.lua takes the addon table as its second vararg, as the .toc load
// gives it; the harness passes the same thing explicitly.
const librarySource = fs
  .readFileSync(libPath, "utf8")
  .replace("local ADDON_NAME, MV = ...", 'local ADDON_NAME, MV = "MacroVaultPro", MacroVaultPro');
const src = stubs + coreSource + "\n" + librarySource + "\n" + tests;
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
