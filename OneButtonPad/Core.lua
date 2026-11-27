-- One Button Pad
-- The two halves of a controller setup in one window: what Forever One Button
-- holds in its cells, and what Console Port's pad buttons are bound to.
--
-- Read-only on purpose. Neither addon exports an API, so this one reads what they
-- do publish - Forever One Button's saved cells and keys, Console Port's public
-- binding calls - and never writes to either. That is why nothing here can move a
-- cell, change a key or rebind a pad button: the two addons stay in charge of
-- their own data, and this window only says what they are doing.
--
-- The question it answers for a controller player: Forever One Button's cells are
-- keyboard chords (SHIFT-1, CTRL-SHIFT-4), and a gamepad cannot produce those. A
-- pad button runs an action bar slot instead. So the window puts the cells on the
-- left and the pad's own binding map on the right, in the same place, at a size
-- that can be read from a sofa.

local ADDON_NAME, OPB = ...
ADDON_NAME = ADDON_NAME or "OneButtonPad"
OPB = OPB or _G.OneButtonPad or {}
_G.OneButtonPad = OPB

OPB.VERSION = "0.1.0"
-- Printed by /obp diag so a report says which copy of the files is loaded.
OPB.BUILD   = "2026-11-27a"

OPB.ONE_BUTTON   = "ForeverOneButton"
OPB.CONSOLE_PORT = "ConsolePort"

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
-- apart from "not loaded", so a report never calls an addon missing because a
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
	local loaded = addonLoaded(name)
	if loaded ~= nil then return loaded end

	-- A client with no loader check: both addons name their own saved variables or
	-- their own frames, and their presence says they are there.
	if name == self.ONE_BUTTON then
		return type(_G.ForeverOneButtonDB) == "table" or _G.ForeverOneButtonGrid ~= nil
	end
	return type(_G.ConsolePort) == "table"
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
	local info = { present = self:IsLoaded(self.ONE_BUTTON), cells = {}, keyed = 0 }
	if not info.present then return info end

	info.version = addonVersion(self.ONE_BUTTON)

	local account = _G.ForeverOneButtonDB
	local grid = type(account) == "table" and type(account.grid) == "table" and account.grid or {}
	info.shown = tonumber(grid.slots) or self.DEFAULT_SHOWN

	info.cells = self:Cells(account, _G.ForeverOneButtonCharDB, info.shown)
	for _, cell in ipairs(info.cells) do
		if cell.key then info.keyed = info.keyed + 1 end
	end
	return info
end

-------------------------------------------------------------------------------
-- Console Port: what each pad button is bound to
-------------------------------------------------------------------------------

function OPB:Controller()
	local info = { present = self:IsLoaded(self.CONSOLE_PORT) }
	if not info.present then return info end

	info.version = addonVersion(self.CONSOLE_PORT)

	local api = _G.ConsolePort
	info.api = type(api) == "table"
		and type(api.GetCurrentBindings) == "function"
		and type(api.GetFormattedButtonCombination) == "function"

	-- The client's own gamepad support is what Console Port drives on this build;
	-- its presence is reported, not guessed at.
	info.native = type(_G.GamepadMode) == "table"
		or (type(Enum) == "table" and type(Enum.BindingContext) == "table"
			and Enum.BindingContext.GamepadModeInGameCore ~= nil)

	return info
end

-- The Blizzard action bar widgets a pad button usually points at, in words a
-- player recognises. Longest prefix wins, so MultiBarBottomLeftButton3 is not
-- mistaken for MultiBarButton3.
local BAR_PREFIXES = {
	{ "MultiBarBottomLeftButton",  "bottom left bar" },
	{ "MultiBarBottomRightButton", "bottom right bar" },
	{ "MultiBarRightButton",       "right bar" },
	{ "MultiBarLeftButton",        "left bar" },
	{ "MultiBar5Button",           "bar 5" },
	{ "MultiBar6Button",           "bar 6" },
	{ "MultiBar7Button",           "bar 7" },
	{ "ActionButton",              "main bar" },
	{ "BonusActionButton",         "bonus bar" },
	{ "StanceButton",              "stance bar" },
	{ "PetActionButton",           "pet bar" },
	{ "ForeverOneButtonCell",      "Forever One Button cell" },
}
OPB.BAR_PREFIXES = BAR_PREFIXES

-- "main bar 3" for ActionButton3, nil when the widget name is not a bar button.
function OPB:DescribeWidget(name)
	if type(name) ~= "string" or name == "" then return nil end

	local best
	for _, entry in ipairs(BAR_PREFIXES) do
		if name:sub(1, #entry[1]) == entry[1] then
			if not best or #entry[1] > #best[1] then best = entry end
		end
	end
	if not best then return nil end

	local index = name:sub(#best[1] + 1)
	if index ~= "" then return best[2] .. " " .. index end
	return best[2]
end

-- What a binding string runs, in words: a bar button, or the binding's own name
-- when it is one of Console Port's own actions.
function OPB:DescribeBinding(binding)
	binding = tostring(binding or "")
	local widget = binding:match("^CLICK%s+([^:]+)")
	if not widget then return nil end
	return self:DescribeWidget(widget) or widget
end

-- Every pad binding Console Port currently has: button, modifier, the binding it
-- runs and, when the client can draw one, its glyph. Sorted, so the same
-- bindings always print in the same order.
function OPB:PadBindings()
	local controller = self:Controller()
	if not controller.present or not controller.api then return {} end

	local api = _G.ConsolePort
	local ok, current = pcall(api.GetCurrentBindings, api)
	if not ok or type(current) ~= "table" then return {} end

	local list = {}
	for button, set in pairs(current) do
		if type(set) == "table" then
			for modifier, binding in pairs(set) do
				if type(binding) == "string" and binding ~= "" then
					local glyph
					local got, value = pcall(api.GetFormattedButtonCombination, api, button, modifier)
					if got and type(value) == "string" and value ~= "" then glyph = value end

					list[#list + 1] = {
						button   = tostring(button),
						modifier = tostring(modifier),
						binding  = binding,
						glyph    = glyph,
						target   = self:DescribeBinding(binding),
					}
				end
			end
		end
	end

	table.sort(list, function(a, b)
		if a.button ~= b.button then return a.button < b.button end
		return a.modifier < b.modifier
	end)
	return list
end

-- "PAD1 + SHIFT" when there is no glyph. A glyph from Console Port is passed
-- through as it comes, because the client draws it.
function OPB:PadText(row)
	if type(row) ~= "table" then return "" end
	if row.glyph then return row.glyph end
	if row.modifier and row.modifier ~= "" and row.modifier ~= "NONE" then
		return row.button .. " + " .. row.modifier
	end
	return row.button
end

-------------------------------------------------------------------------------
-- Reports: one copyable block for chat, one line for /obp diag
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
	else
		lines[#lines + 1] = "Forever One Button is not loaded."
	end

	local controller = self:Controller()
	if controller.present then
		lines[#lines + 1] = ("Console Port %s - gamepad api %s"):format(
			controller.version or "version unread", controller.native and "present" or "not found")
		if not controller.api then
			lines[#lines + 1] = "  its binding calls were not found, so no pad button is listed"
		else
			local rows = self:PadBindings()
			lines[#lines + 1] = ("  %d pad bindings"):format(#rows)
			for _, row in ipairs(rows) do
				lines[#lines + 1] = ("  %-18s  %s"):format(
					self:PadText(row), row.target or row.binding)
			end
		end
	else
		lines[#lines + 1] = "Console Port is not loaded - the keys on the left are all there is."
	end

	lines[#lines + 1] = "cells answer keyboard chords; a pad button runs an action bar slot, so a cell a pad cannot reach needs its spell on a bar the pad is bound to."
	return lines
end

function OPB:PrintReport()
	for _, line in ipairs(self:ReportLines()) do
		self:PrintRaw(line)
	end
end

function OPB:Diag()
	local one = self:OneButton()
	local controller = self:Controller()
	local rows = self:PadBindings()

	self:Print("--- One Button Pad diag ---")
	self:PrintRaw(("addon %s  build %s"):format(self.VERSION, self.BUILD))
	self:PrintRaw(("foreveronebutton %s  version %s  cells %d/%d keyed  shows %d"):format(
		one.present and "yes" or "no", tostring(one.version or "-"),
		one.keyed or 0, #one.cells or 0, one.shown or 0))
	self:PrintRaw(("consoleport %s  version %s  binding api %s  gamepad api %s  bindings %d"):format(
		controller.present and "yes" or "no", tostring(controller.version or "-"),
		controller.api and "yes" or "no", controller.native and "yes" or "no", #rows))
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
		-- A pad binding or a cell key can change while the window is open.
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
