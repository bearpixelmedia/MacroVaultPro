-- MacroVaultPro
-- Browse every macro on the account and character, inject them onto your bars,
-- and run the client's own UI/debug slash commands (like /fstack) from one panel.
--
-- Target client: World of Warcraft: Forever (interface 16001), modern API family.

-- The client passes (addonName, addonTable) to every addon file. Older clients
-- pass nothing at all, which would leave MV nil and stop the addon dead on the
-- next line, so build the table ourselves if it is missing.
local ADDON_NAME, MV = ...
ADDON_NAME = ADDON_NAME or "MacroVaultPro"
MV = MV or _G.MacroVaultPro or {}
_G.MacroVaultPro = MV

MV.VERSION       = "1.0.0"
MV.MAX_BODY      = 255
MV.MAX_NAME      = 16

-- Only used when a client exposes no limits at all. The real account /
-- character split is read from the client; /mvpro selftest confirms it.
MV.DEFAULT_ACCOUNT_SLOTS   = 120
MV.DEFAULT_CHARACTER_SLOTS = 30

local PREFIX = "|cffa78bfaMacroVaultPro|r  "

local function trim(value)
	return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end
MV.trim = trim

-------------------------------------------------------------------------------
-- Chat / status helpers
-------------------------------------------------------------------------------

function MV:Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message))
end

function MV:Notify(message, isError)
	self:Print(message)
	if self.UI and self.UI.SetStatus then
		self.UI:SetStatus(message, isError)
	end
end

-------------------------------------------------------------------------------
-- Macro API compatibility shims (globals are current, C_Macro is a fallback)
-------------------------------------------------------------------------------

local function macroInfo(index)
	if GetMacroInfo then
		return GetMacroInfo(index)
	end
	if C_Macro and C_Macro.GetMacroInfo then
		return C_Macro.GetMacroInfo(index)
	end
end

local function safeMacroInfo(index)
	local ok, name, icon, body = pcall(macroInfo, index)
	if not ok then return nil end
	return name, icon, body
end

local function macroCreate(name, icon, body, perCharacter)
	if CreateMacro then
		return CreateMacro(name, icon, body, perCharacter)
	end
	if C_Macro and C_Macro.CreateMacro then
		return C_Macro.CreateMacro(name, icon, body, perCharacter)
	end
end

local function macroEdit(...)
	if EditMacro then
		return EditMacro(...)
	end
	if C_Macro and C_Macro.EditMacro then
		return C_Macro.EditMacro(...)
	end
end

-------------------------------------------------------------------------------
-- Macro slot layout: where account macros end and character macros begin
--
-- Clients do not agree on the index where character slots start, so the
-- boundary is read from the client rather than assumed: the MAX_* globals or
-- Constants.MacroConsts, then the built-in defaults. Nothing in here creates a
-- macro, so opening the window never touches the player's macros: /mvpro
-- selftest is the only place that probes. Every macro MacroVaultPro creates also
-- teaches the exact scope of its own slot.
-------------------------------------------------------------------------------

local MAX_SANE_SLOTS = 1000

local function slotCount(value)
	if type(value) ~= "number" or value <= 0 then return nil end
	value = math.floor(value)
	if value > MAX_SANE_SLOTS then return nil end
	return value
end

-- Key spelling differs between builds: MAX_ACCOUNT_MACROS, MaxAccountMacros...
local function keyLooksLikeAccount(key)
	key = tostring(key):lower()
	return key:find("account", 1, true) ~= nil and key:find("macro", 1, true) ~= nil
end

local function keyLooksLikeCharacter(key)
	key = tostring(key):lower()
	if key:find("macro", 1, true) == nil then return false end
	return key:find("character", 1, true) ~= nil or key:find("perchar", 1, true) ~= nil
end

local function scanLimits(container, found)
	for key, value in pairs(container) do
		local slots = slotCount(value)
		if slots then
			if not found.account and keyLooksLikeAccount(key) then
				found.account = slots
			elseif not found.character and keyLooksLikeCharacter(key) then
				found.character = slots
			end
		elseif type(value) == "table" and tostring(key):find("Macro", 1, true) then
			scanLimits(value, found)
		end
	end
end

local function clientLimits()
	local found = {
		account   = slotCount(_G.MAX_ACCOUNT_MACROS),
		character = slotCount(_G.MAX_CHARACTER_MACROS),
	}

	if type(_G.Constants) == "table" then
		scanLimits(_G.Constants, found)
	end

	if not found.account and not found.character then return nil end
	return found.account, found.character
end

local function deleteMacro(index)
	local remove = DeleteMacro or (C_Macro and C_Macro.DeleteMacro)
	if not remove or type(index) ~= "number" then return false end
	local ok, result = pcall(remove, index)
	return ok and result ~= false
end

local probeCount = 0

-- Creates one throw-away macro in the requested scope and deletes it again.
-- The slot it lands in tells us where that scope's slots are.
-- Returns index, error, removed.
function MV:ProbeScope(perCharacter)
	local blocked = self:EditBlocked()
	if blocked then return nil, "in combat", false end

	local create = CreateMacro or (C_Macro and C_Macro.CreateMacro)
	if not create then return nil, "this client has no CreateMacro", false end

	probeCount = probeCount + 1
	local name = ("MVProbe%d"):format(probeCount)
	if #name > self.MAX_NAME then name = name:sub(1, self.MAX_NAME) end

	local ok, index = pcall(create, name, 134400, "/say MacroVaultPro probe", perCharacter and true or nil)
	if not ok or type(index) ~= "number" then
		return nil, ("could not create a %s macro (that scope may be full)"):format(
			perCharacter and "character" or "account"), false
	end

	return index, nil, deleteMacro(index)
end

-- Read-only on purpose: no temporary macros here, so simply opening the
-- window cannot touch anything the player owns.
function MV:BuildLayout()
	local account, character = clientLimits()

	local layout = {
		accountSlots   = account or self.DEFAULT_ACCOUNT_SLOTS,
		characterSlots = character or self.DEFAULT_CHARACTER_SLOTS,
		source         = (account or character) and "client limits" or "built-in defaults",
		known          = {},
	}
	layout.boundary = layout.accountSlots + 1
	layout.total = layout.accountSlots + layout.characterSlots
	return layout
end

function MV:GetLayout(force)
	if force then
		self.layout = nil
	end
	if not self.layout then
		self.layout = self:BuildLayout()
	end
	return self.layout
end

-- Scope of a slot. Slots we have probed or created ourselves are known exactly;
-- everything else is compared against the detected boundary.
function MV:ScopeOf(index)
	local layout = self:GetLayout()
	local known = layout.known[index]
	if known then return known end
	if index >= layout.boundary then return "char" end
	return "account"
end

-- Creates and deletes one temporary macro per scope and lets the result
-- correct the boundary. Returns layout, report.
function MV:VerifyLayout()
	local layout = self:GetLayout()
	local boundaryBefore = layout.boundary
	local report = {}

	local accountIndex, accountError, accountRemoved = self:ProbeScope(false)
	report.account, report.accountError, report.accountRemoved = accountIndex, accountError, accountRemoved
	if accountIndex then
		layout.known[accountIndex] = "account"
		-- An account macro cannot live in the character range, so slots run higher.
		if accountIndex >= layout.boundary then
			layout.accountSlots = accountIndex
		end
	end

	local characterIndex, characterError, characterRemoved = self:ProbeScope(true)
	report.character, report.characterError, report.characterRemoved = characterIndex, characterError, characterRemoved
	if characterIndex then
		layout.known[characterIndex] = "char"
		-- A character macro cannot live in the account range.
		if characterIndex <= layout.accountSlots then
			layout.accountSlots = math.max(characterIndex - 1, 1)
		end
	end

	layout.boundary = layout.accountSlots + 1
	layout.characterSlots = math.max(layout.total - layout.accountSlots, 0)

	report.boundaryBefore = boundaryBefore
	report.boundaryAfter = layout.boundary
	report.adjusted = boundaryBefore ~= layout.boundary
	if report.adjusted then
		layout.source = layout.source .. " + probe"
	end

	return layout, report
end

-------------------------------------------------------------------------------
-- Reading macros
-------------------------------------------------------------------------------

function MV:GetMacro(index)
	if not index then return nil end

	local name, icon, body = safeMacroInfo(index)
	if not name or name == "" then return nil end

	return {
		index = index,
		key   = index,
		name  = name,
		icon  = icon,
		body  = body or "",
		scope = self:ScopeOf(index),
	}
end

function MV:GetMacros()
	local macros = {}
	local layout = self:GetLayout()
	for index = 1, layout.total do
		local macro = self:GetMacro(index)
		if macro then
			macros[#macros + 1] = macro
		end
	end
	return macros
end

-------------------------------------------------------------------------------
-- Writing macros
-------------------------------------------------------------------------------

function MV:EditBlocked()
	if InCombatLockdown and InCombatLockdown() then
		return "You can't create or change macros while in combat."
	end
end

local function normalizeBody(body)
	return (tostring(body or ""):gsub("\r\n", "\n"):gsub("\r", "\n"))
end

function MV:CreateMacro(name, body, icon, perCharacter)
	local blocked = self:EditBlocked()
	if blocked then return nil, blocked end

	name = trim(name)
	if name == "" then name = "Macro" end
	if #name > self.MAX_NAME then name = name:sub(1, self.MAX_NAME) end

	body = normalizeBody(body)
	if trim(body) == "" then return nil, "The macro body is empty." end
	if #body > self.MAX_BODY then
		return nil, ("That body is %d characters; the client allows %d."):format(#body, self.MAX_BODY)
	end

	icon = tonumber(icon) or icon
	if icon == nil or icon == "" then icon = 134400 end

	local ok, index = pcall(macroCreate, name, icon, body, perCharacter and true or nil)
	if (not ok or not index) and type(icon) ~= "number" then
		-- Texture paths are accepted by most clients; fall back to the default icon if not.
		ok, index = pcall(macroCreate, name, 134400, body, perCharacter and true or nil)
	end
	if not ok or not index then
		return nil, "The client refused to create the macro - your macro slots may be full."
	end

	-- Remembering a macro we just created keeps that slot's scope exact even
	-- when the detected boundary is only an estimate.
	self:GetLayout().known[index] = perCharacter and "char" or "account"

	return index
end

function MV:UpdateMacro(index, name, body, icon)
	local blocked = self:EditBlocked()
	if blocked then return nil, blocked end

	local existing = self:GetMacro(index)
	if not existing then return nil, "That macro no longer exists." end

	name = trim(name)
	if name == "" then name = existing.name end
	if #name > self.MAX_NAME then name = name:sub(1, self.MAX_NAME) end

	body = normalizeBody(body)
	if trim(body) == "" then return nil, "The macro body is empty." end
	if #body > self.MAX_BODY then
		return nil, ("That body is %d characters; the client allows %d."):format(#body, self.MAX_BODY)
	end

	icon = tonumber(icon) or icon
	if icon == nil or icon == "" then icon = existing.icon or 134400 end

	local ok, newIndex = pcall(macroEdit, index, name, icon, body)
	if (not ok or not newIndex) and type(icon) ~= "number" then
		ok, newIndex = pcall(macroEdit, index, name, existing.icon or 134400, body)
	end
	if not ok or not newIndex then
		return nil, "The client refused to change that macro."
	end

	return newIndex
end

function MV:Pickup(index)
	local blocked = self:EditBlocked()
	if blocked then return false, blocked end
	if type(index) ~= "number" then return false, "Select a macro first." end
	local pickup = PickupMacro or (C_Macro and C_Macro.PickupMacro)
	if not pickup then return false, "This client has no PickupMacro." end

	local ok, picked = pcall(pickup, index)
	if not ok or picked == false then
		return false, "The client would not pick that macro up."
	end
	return true
end

-------------------------------------------------------------------------------
-- Slash command runner (UI/debug tools only - no combat actions)
-------------------------------------------------------------------------------

local aliasCache

local function buildAliasCache()
	local map = {}
	if not SlashCmdList then return map end

	for token, handler in pairs(SlashCmdList) do
		if type(handler) == "function" then
			local i = 1
			while i < 30 do
				local alias = _G["SLASH_" .. tostring(token) .. i]
				if type(alias) ~= "string" then break end
				map[alias:lower()] = handler
				i = i + 1
			end
		end
	end
	return map
end

function MV:RunSlash(command)
	local slash, rest = tostring(command or ""):match("^(%S+)%s*(.-)$")
	if not slash then return false, "No command given." end
	slash = slash:lower()

	-- Direct paths for two commands that matter most when debugging an addon.
	if slash == "/reload" and ReloadUI then
		pcall(ReloadUI)
		return true
	end
	if slash == "/console" and ConsoleExec then
		local consoleOk, consoleError = pcall(ConsoleExec, rest)
		if not consoleOk then
			return false, ("/console failed: %s"):format(tostring(consoleError))
		end
		return true
	end

	aliasCache = aliasCache or buildAliasCache()
	local handler = aliasCache[slash]
	if not handler then
		aliasCache = buildAliasCache()
		handler = aliasCache[slash]
	end
	if not handler then
		return false, ("%s is not available on this client."):format(slash)
	end

	local ok, err = pcall(handler, rest)
	if not ok then
		return false, ("%s failed: %s"):format(slash, tostring(err))
	end
	return true
end

function MV:RunTool(tool)
	if not tool then return false, "Unknown tool." end

	if tool.run then
		local ok, err = pcall(tool.run)
		if not ok then return false, tostring(err) end
		return true
	end

	if not tool.cmd then return false, "That tool has no command." end
	return self:RunSlash(tool.cmd)
end

function MV:OpenMacroUI()
	if SlashCmdList and SlashCmdList["MACRO"] then
		return self:RunSlash("/macro")
	end
	if ShowMacroFrame then
		pcall(ShowMacroFrame)
		return true
	end
	if MacroFrame and MacroFrame.Show then
		MacroFrame:Show()
		return true
	end
	return false, "The macro window is not available."
end

-------------------------------------------------------------------------------
-- Saved position
-------------------------------------------------------------------------------

function MV:SavePosition()
	local frame = self.UI and self.UI.frame
	if not frame or not MacroVaultProDB then return end

	local point, _, relPoint, x, y = frame:GetPoint(1)
	if point then
		MacroVaultProDB.position = { point = point, relPoint = relPoint, x = x, y = y }
	end
end

-------------------------------------------------------------------------------
-- Window entry points
-------------------------------------------------------------------------------

function MV:Open(tab)
	self.UI:Build()
	self.UI:Show(tab)
end

function MV:Toggle()
	local ui = self.UI
	ui:Build()
	if ui.frame:IsShown() then
		ui.frame:Hide()
	else
		ui:Show()
	end
end

-------------------------------------------------------------------------------
-- Self test: /mvpro selftest
-------------------------------------------------------------------------------

function MV:Selftest()
	local layout = self:GetLayout(true)

	local okBuild, clientVersion, clientBuild, _, tocVersion = pcall(GetBuildInfo)
	if not okBuild then
		clientVersion, clientBuild, tocVersion = "?", "?", "?"
	end

	self:Print(("selftest  -  MacroVaultPro %s on client %s (build %s, interface %s)"):format(
		self.VERSION, tostring(clientVersion), tostring(clientBuild), tostring(tocVersion)))

	self:Print(("globals: MAX_ACCOUNT_MACROS=%s  MAX_CHARACTER_MACROS=%s"):format(
		tostring(_G.MAX_ACCOUNT_MACROS or "unset"),
		tostring(_G.MAX_CHARACTER_MACROS or "unset")))

	self:Print(("detected: account slots 1-%d, character slots %d-%d  (from %s)"):format(
		layout.accountSlots, layout.boundary, layout.total, layout.source))

	local usedAccount, usedCharacter = 0, 0
	for index = 1, layout.total do
		if self:GetMacro(index) then
			if self:ScopeOf(index) == "char" then
				usedCharacter = usedCharacter + 1
			else
				usedAccount = usedAccount + 1
			end
		end
	end
	self:Print(("in use: account %d/%d, character %d/%d"):format(
		usedAccount, layout.accountSlots, usedCharacter, layout.characterSlots))

	if self:EditBlocked() then
		self:Print("|cffff8080temporary macro check skipped:|r you are in combat - run /mvpro selftest out of combat.")
		return
	end

	self:Print("creating and deleting one temporary macro per scope...")

	local verified, report = self:VerifyLayout()
	layout = verified

	if report.account then
		self:Print(("  account probe landed in slot %d, %s"):format(
			report.account,
			report.accountRemoved and "deleted again" or "|cffff8080could not delete it - check your macro window|r"))
	else
		self:Print(("  account probe skipped: %s"):format(tostring(report.accountError)))
	end

	if report.character then
		self:Print(("  character probe landed in slot %d, %s"):format(
			report.character,
			report.characterRemoved and "deleted again" or "|cffff8080could not delete it - check your macro window|r"))
	else
		self:Print(("  character probe skipped: %s"):format(tostring(report.characterError)))
	end

	local probes = (report.account and 1 or 0) + (report.character and 1 or 0)

	if report.adjusted then
		self:Print(("|cffffd166corrected:|r the probes moved the boundary from %d to %d."):format(
			report.boundaryBefore, report.boundaryAfter))
		self:Print(("now treating slots 1-%d as account-wide and %d-%d as this character."):format(
			layout.accountSlots, layout.boundary, layout.total))
	elseif probes == 2 then
		self:Print(("|cff88ff88confirmed:|r character macros start at slot %d, so slots 1-%d are account-wide."):format(
			layout.boundary, layout.accountSlots))
	elseif probes == 1 then
		self:Print(("|cffffd166partly confirmed:|r only one scope had a free slot, so the boundary stays %d (from %s)."):format(
			layout.boundary, layout.source))
	else
		self:Print(("|cffff8080unconfirmed:|r no temporary macro could be created, so the boundary comes from %s only."):format(
			layout.source))
	end

	if self.UI and self.UI.frame then
		self.UI:Refresh()
	end
end

-------------------------------------------------------------------------------
-- Events and slash commands
-------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_MACROS")
loader:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		MacroVaultProDB = MacroVaultProDB or {}
		local db = MacroVaultProDB
		if db.perCharacter == nil then db.perCharacter = false end
		if db.tab == nil then db.tab = "macros" end
		if MV.UI then MV.UI:ApplyPosition() end
	elseif event == "PLAYER_LOGIN" then
		MV:Print(("v%s loaded  -  /mvpro"):format(MV.VERSION))
	elseif event == "UPDATE_MACROS" then
		local ui = MV.UI
		if ui and ui.frame and ui.frame:IsShown() then
			ui:Refresh()
		end
	end
end)

SLASH_MACROVAULTPRO1 = "/macrovaultpro"
SLASH_MACROVAULTPRO2 = "/mvpro"
SlashCmdList["MACROVAULTPRO"] = function(msg)
	msg = trim(msg):lower()
	if msg == "" then
		MV:Toggle()
	elseif msg == "macros" or msg == "tools" or msg == "library" or msg == "editor" then
		MV:Open(msg)
	elseif msg == "selftest" or msg == "test" then
		MV:Selftest()
	elseif msg == "reset" then
		MacroVaultProDB = MacroVaultProDB or {}
		MacroVaultProDB.position = nil
		if MV.UI and MV.UI.frame then
			MV.UI:ApplyPosition()
			MV:Notify("Window position reset.")
		else
			MV:Print("Window position reset.")
		end
	else
		MV:Print("Usage: /mvpro  |  /mvpro tools  |  /mvpro library  |  /mvpro editor  |  /mvpro selftest  |  /mvpro reset")
	end
end
