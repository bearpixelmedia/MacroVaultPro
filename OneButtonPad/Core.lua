-- One Button Pad
-- Forever One Button's cells and the keys that press them, in one window.
--
-- Read-only on purpose. Forever One Button exports no API, so this one reads what
-- it does publish - its saved cells and keys - and never writes to it. Nothing
-- here can move a cell or change a key: that addon stays in charge of its own
-- data, and this window only says what it is doing.
--
-- The question it answers: which chord presses which cell, including the cells the
-- grid is not showing. Forever One Button's cells are keyboard chords (SHIFT-1,
-- CTRL-SHIFT-4), listed at a size that can be read from a sofa.

local ADDON_NAME, OPB = ...
ADDON_NAME = ADDON_NAME or "OneButtonPad"
OPB = OPB or _G.OneButtonPad or {}
_G.OneButtonPad = OPB

OPB.VERSION = "0.1.1"
-- Printed by /obp diag so a report says which copy of the files is loaded.
OPB.BUILD   = "2026-11-28a"

OPB.ONE_BUTTON = "ForeverOneButton"

-- Forever One Button's own maximum, and the cell count it shows without a choice.
OPB.MAX_CELLS     = 30
OPB.DEFAULT_SHOWN = 20

-- Forever One Button saves only the keys the player changed, so a cell with
-- nothing saved still has a key. This is a copy of its 1.2.14 table
-- (Core/Settings.lua, DEFAULT_KEYS), read-only, used only when the saved value is
-- absent. A key the player removed is saved as `false` and stays removed.
OPB.DEFAULT_KEYS = {
	"SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-4", "SHIFT-5",
	"SHIFT-6", "SHIFT-7", "SHIFT-8", "SHIFT-9", "SHIFT-0",
	"CTRL-SHIFT-1", "CTRL-SHIFT-2", "CTRL-SHIFT-3", "CTRL-SHIFT-4", "CTRL-SHIFT-5",
	"CTRL-SHIFT-6", "CTRL-SHIFT-7", "CTRL-SHIFT-8", "CTRL-SHIFT-9", "CTRL-SHIFT-0",
	"CTRL-1", "CTRL-2", "CTRL-3", "CTRL-4", "CTRL-5",
	"CTRL-6", "CTRL-7", "CTRL-8", "CTRL-9", "CTRL-0",
}

local PREFIX = "|cff56b6f7One Button Pad|r  "

function OPB:Print(message)
	if type(DEFAULT_CHAT_FRAME) == "table" and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message))
	end
end

-- A line of a copyable block: no prefix, no colour codes.
function OPB:PrintRaw(message)
	if type(DEFAULT_CHAT_FRAME) == "table" and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(tostring(message))
	end
end

local function trim(value)
	return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end
OPB.trim = trim

-------------------------------------------------------------------------------
-- Client lookups, every one of them guarded
-------------------------------------------------------------------------------

-- True, false, or nil when the client cannot answer. "Cannot answer" is kept
-- apart from "not loaded", so a report never calls the addon missing because a
-- function was absent.
local function addonLoaded(name)
	local fn = (type(_G.C_AddOns) == "table" and _G.C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
	if type(fn) ~= "function" then return nil end
	local ok, loaded = pcall(fn, name)
	if not ok then return nil end
	return loaded == true
end

local function addonVersion(name)
	local fn = (type(_G.C_AddOns) == "table" and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, name, "Version")
	if not ok or type(value) ~= "string" or value == "" then return nil end
	return value
end

local function spellName(id)
	if type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
		local ok, info = pcall(C_Spell.GetSpellInfo, id)
		if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
	end
	if type(GetSpellInfo) == "function" then
		local ok, name = pcall(GetSpellInfo, id)
		if ok and type(name) == "string" then return name end
	end
end

local function spellIcon(id)
	if type(C_Spell) == "table" and type(C_Spell.GetSpellTexture) == "function" then
		local ok, icon = pcall(C_Spell.GetSpellTexture, id)
		if ok and (type(icon) == "number" or type(icon) == "string") then return icon end
	end
	if type(GetSpellTexture) == "function" then
		local ok, icon = pcall(GetSpellTexture, id)
		if ok and (type(icon) == "number" or type(icon) == "string") then return icon end
	end
end

local function itemName(id)
	if type(C_Item) == "table" and type(C_Item.GetItemNameByID) == "function" then
		local ok, name = pcall(C_Item.GetItemNameByID, id)
		if ok and type(name) == "string" then return name end
	end
	if type(GetItemInfo) == "function" then
		local ok, name = pcall(GetItemInfo, id)
		if ok and type(name) == "string" then return name end
	end
end

local function itemIcon(id)
	if type(C_Item) == "table" and type(C_Item.GetItemIconByID) == "function" then
		local ok, icon = pcall(C_Item.GetItemIconByID, id)
		if ok and (type(icon) == "number" or type(icon) == "string") then return icon end
	end
	if type(GetItemInfo) == "function" then
		local ok, _, _, _, _, _, _, _, _, icon = pcall(GetItemInfo, id)
		if ok and (type(icon) == "number" or type(icon) == "string") then return icon end
	end
end

-------------------------------------------------------------------------------
-- Forever One Button: cells and the keys that press them
-------------------------------------------------------------------------------

function OPB:IsLoaded(name)
	name = name or self.ONE_BUTTON
	if name ~= self.ONE_BUTTON then return false end

	local loaded = addonLoaded(name)
	if loaded ~= nil then return loaded end

	-- A client with no loader check: the addon names its own saved variables and
	-- its own grid, and their presence says it is there.
	return type(_G.ForeverOneButtonDB) == "table" or _G.ForeverOneButtonGrid ~= nil
end

-- The key that presses a cell: a saved key string, nil for a cell the player
-- unbound, and Forever One Button's own default when nothing was ever saved.
function OPB:KeyFor(slot, account)
	local saved
	if type(account) == "table" and type(account.keys) == "table" then
		saved = account.keys[slot]
	end
	if saved == false then return nil end
	if type(saved) == "string" and saved ~= "" then return saved end
	return self.DEFAULT_KEYS[slot]
end

-- Every cell Forever One Button has filled, in cell order. A cell past the number
-- its grid shows is marked hidden rather than dropped: it still holds an action
-- the player assigned.
function OPB:Cells(account, character, shown)
	local saved = type(character) == "table" and type(character.cells) == "table" and character.cells or nil
	local list = {}
	if not saved then return list end

	shown = tonumber(shown) or 0
	for slot = 1, self.MAX_CELLS do
		local cell = saved[slot]
		local id = type(cell) == "table" and tonumber(cell.id) or nil
		if id and (cell.kind == "spell" or cell.kind == "item") then
			list[#list + 1] = {
				slot      = slot,
				kind      = cell.kind,
				id        = id,
				key       = self:KeyFor(slot, account),
				hidden    = shown > 0 and slot > shown,
				automatic = cell.auto == true,
			}
		end
	end
	return list
end

-- Fills in the name and icon a cell's id stands for. A resolved cell always has a
-- label, so a row is never blank: an id the client will not name shows as one.
function OPB:Resolve(cell)
	if type(cell) ~= "table" then return cell end

	if cell.kind == "item" then
		cell.name = itemName(cell.id)
		cell.icon = itemIcon(cell.id)
		if not cell.name then cell.name = ("item %d"):format(cell.id) end
	else
		cell.name = spellName(cell.id)
		cell.icon = spellIcon(cell.id)
		if not cell.name then cell.name = ("spell %d"):format(cell.id) end
	end
	return cell
end

-- Everything the window needs about Forever One Button, in one read.
function OPB:OneButton()
	local info = { present = self:IsLoaded(self.ONE_BUTTON), cells = {}, keyed = 0, keyless = 0 }
	if not info.present then return info end

	info.version = addonVersion(self.ONE_BUTTON)

	local account = _G.ForeverOneButtonDB
	local grid = type(account) == "table" and type(account.grid) == "table" and account.grid or {}
	info.shown = tonumber(grid.slots) or self.DEFAULT_SHOWN

	info.cells = self:Cells(account, _G.ForeverOneButtonCharDB, info.shown)
	for _, cell in ipairs(info.cells) do
		if cell.key then
			info.keyed = info.keyed + 1
		else
			info.keyless = info.keyless + 1
		end
	end
	return info
end

-------------------------------------------------------------------------------
-- Reports: one copyable block for chat, one line per read for /obp diag
-------------------------------------------------------------------------------

function OPB:ReportLines()
	local lines = {}
	local one = self:OneButton()

	if one.present then
		lines[#lines + 1] = ("Forever One Button %s - %d cells, %d with a key (shows %d)"):format(
			one.version or "version unread", #one.cells, one.keyed or 0, one.shown or 0)
		if #one.cells == 0 then
			lines[#lines + 1] = "  no cell is filled - /fob autofill now fills them"
		end
		for _, cell in ipairs(one.cells) do
			cell = self:Resolve(cell)
			lines[#lines + 1] = ("  cell %d  %-26s  %s%s"):format(
				cell.slot, tostring(cell.name), cell.key or "no key",
				cell.hidden and "  (past the cells it shows)" or "")
		end
		if (one.keyless or 0) > 0 then
			lines[#lines + 1] = ("  %d cell(s) have no key - they are in the grid, but no chord presses them"):format(
				one.keyless)
		end
	else
		lines[#lines + 1] = "Forever One Button is not loaded."
	end

	lines[#lines + 1] = "read-only: this window never moves a cell or changes a key."
	return lines
end

function OPB:PrintReport()
	for _, line in ipairs(self:ReportLines()) do
		self:PrintRaw(line)
	end
end

-- Each line names one read this addon makes, so a half-empty window can be told
-- apart from a half-empty saved variable.
function OPB:Diag()
	local one = self:OneButton()

	local db     = type(_G.ForeverOneButtonDB) == "table"
	local char   = type(_G.ForeverOneButtonCharDB) == "table"
	local cells  = char and type(_G.ForeverOneButtonCharDB.cells) == "table" or false
	local spells = (type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function")
		or type(GetSpellInfo) == "function"
	local items  = (type(C_Item) == "table" and type(C_Item.GetItemNameByID) == "function")
		or type(GetItemInfo) == "function"

	self:Print("--- One Button Pad diag ---")
	self:PrintRaw(("addon %s  build %s"):format(self.VERSION, self.BUILD))
	self:PrintRaw(("foreveronebutton %s  version %s  cells %d/%d keyed  shows %d"):format(
		one.present and "yes" or "no", tostring(one.version or "-"),
		one.keyed or 0, #one.cells or 0, one.shown or 0))
	self:PrintRaw(("reads db %s  char %s  cells %s  spells %s  items %s"):format(
		db and "yes" or "no", char and "yes" or "no", cells and "yes" or "no",
		spells and "yes" or "no", items and "yes" or "no"))
	self:PrintRaw(("window %s  saved %s"):format(
		self.UI and self.UI.frame and "built" or "not built",
		type(OneButtonPadDB) == "table" and "yes" or "no"))
	self:Print("--- end One Button Pad diag ---")
end

-------------------------------------------------------------------------------
-- Entry points
-------------------------------------------------------------------------------

function OPB:Open()
	self.UI:Build()
	self.UI:Refresh()
	self.UI.frame:Show()
end

function OPB:Toggle()
	self.UI:Build()
	if self.UI.frame:IsShown() then
		self.UI.frame:Hide()
	else
		self:Open()
	end
end

function OPB:SavePosition()
	local frame = self.UI and self.UI.frame
	if not frame or type(OneButtonPadDB) ~= "table" then return end

	local point, _, relPoint, x, y = frame:GetPoint(1)
	if point then
		OneButtonPadDB.position = { point = point, relPoint = relPoint, x = x, y = y }
	end
	OneButtonPadDB.scale = frame:GetScale()
end

function OPB:ResetPosition()
	if type(OneButtonPadDB) == "table" then
		OneButtonPadDB.position, OneButtonPadDB.scale = nil, nil
	end
	if self.UI and self.UI.frame then
		self.UI:ApplyPosition()
		self:Print("window position reset.")
	end
end

-------------------------------------------------------------------------------
-- Events and slash commands
-------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_BINDINGS")
loader:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		OneButtonPadDB = OneButtonPadDB or {}
		if type(OneButtonPadDB) ~= "table" then OneButtonPadDB = {} end
	elseif event == "PLAYER_LOGIN" then
		OPB:Print(("v%s loaded - /obp"):format(OPB.VERSION))
	elseif event == "UPDATE_BINDINGS" then
		-- A cell key can change while the window is open.
		if OPB.UI and OPB.UI.frame and OPB.UI.frame:IsShown() then
			OPB.UI:Refresh()
		end
	end
end)

SLASH_ONEBUTTONPAD1 = "/obp"
SLASH_ONEBUTTONPAD2 = "/onebuttonpad"
SlashCmdList["ONEBUTTONPAD"] = function(msg)
	msg = trim(msg):lower()
	if msg == "" then
		OPB:Toggle()
	elseif msg == "report" or msg == "bridge" then
		OPB:PrintReport()
	elseif msg == "diag" then
		OPB:Diag()
	elseif msg == "reset" then
		OPB:ResetPosition()
	else
		OPB:Print("Usage: /obp  |  /obp report  |  /obp diag  |  /obp reset")
	end
end
