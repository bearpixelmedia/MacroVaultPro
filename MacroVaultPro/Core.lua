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

MV.VERSION       = "1.0.3"
-- Printed by /mvpro selftest so a report says which copy of the files is loaded.
MV.BUILD         = "2026-11-27a"

-- Drag bookkeeping for /mvpro diag. A counter is bumped by the path that
-- actually started or finished the drag, so a retest report can say which of
-- the two paths the client raised. In memory only: a reload starts again at 0.
MV.dragStats = MV.dragStats or {
	press = 0, client = 0, drops = 0,
	minimapPress = 0, minimapClient = 0,
}
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
-- Error log: /mvpro errors
--
-- Installed from the top of the first file the .toc loads, so mistakes in this
-- file and in Library.lua / UI.lua are still caught while the addon is loading.
-- The saved variables do not exist yet at that point, so early entries wait in
-- MV.pending* and are folded into the DB when ADDON_LOADED fires.
--
-- Attribution is best effort. Some clients report stack paths too short to carry
-- an addon name ("Core.lua:12"), which no name match can catch, so those errors
-- go to a second list instead of being dropped: nothing this addon raises goes
-- unrecorded, attributed or not.
-------------------------------------------------------------------------------

local MAX_OWN_ERRORS   = 20
local MAX_OTHER_ERRORS = 10
local MAX_ERROR_CHARS  = 4000

MV.pendingErrors      = MV.pendingErrors or {}
MV.pendingOtherErrors = MV.pendingOtherErrors or {}

local function ownStore()
	if type(MacroVaultProDB) == "table" then
		MacroVaultProDB.errors = MacroVaultProDB.errors or {}
		return MacroVaultProDB.errors
	end
	return MV.pendingErrors
end

local function otherStore()
	if type(MacroVaultProDB) == "table" then
		MacroVaultProDB.otherErrors = MacroVaultProDB.otherErrors or {}
		return MacroVaultProDB.otherErrors
	end
	return MV.pendingOtherErrors
end

-- Prints without going through MV:Print, which does not exist yet while the
-- addon is still loading.
local function notice(message)
	if type(DEFAULT_CHAT_FRAME) == "table" and DEFAULT_CHAT_FRAME.AddMessage then
		pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, PREFIX .. message)
	end
end

function MV:LogError(message, stack, unattributed)
	local text = tostring(message or "unknown error")
	stack = tostring(stack or "")
	if stack ~= "" and not text:find(stack, 1, true) then
		text = text .. "\n" .. stack
	end
	if #text > MAX_ERROR_CHARS then
		text = text:sub(1, MAX_ERROR_CHARS) .. "\n... (truncated)"
	end

	local list  = unattributed and otherStore() or ownStore()
	local limit = unattributed and MAX_OTHER_ERRORS or MAX_OWN_ERRORS
	local stamp = (type(date) == "function" and date("%Y-%m-%d %H:%M:%S")) or "?"
	table.insert(list, 1, { when = stamp, text = text, unattributed = unattributed and true or nil })
	while #list > limit do
		table.remove(list)
	end

	-- A mistake repeated every frame must not flood the chat frame.
	local now = (type(time) == "function" and time()) or 0
	if now - (self.errorNotice or 0) > 3 then
		self.errorNotice = now
		notice("|cffff8080error logged|r - /mvpro errors to copy it")
	end
end

-- Moves anything caught during load into the saved variables, which only exist
-- once ADDON_LOADED has fired. Pending lists are newest-first, like the stores.
function MV:FoldPendingErrors()
	local own, other = ownStore(), otherStore()
	for i = #MV.pendingErrors, 1, -1 do
		table.insert(own, 1, MV.pendingErrors[i])
	end
	for i = #MV.pendingOtherErrors, 1, -1 do
		table.insert(other, 1, MV.pendingOtherErrors[i])
	end
	MV.pendingErrors, MV.pendingOtherErrors = {}, {}
	while #own > MAX_OWN_ERRORS do table.remove(own) end
	while #other > MAX_OTHER_ERRORS do table.remove(other) end
end

-- Routes the client's error handler through the log. The original handler still
-- runs, so the usual error dialog is untouched; this only records.
function MV:InstallErrorLog()
	if self.errorLogHooked then return end
	self.errorLogHooked = true

	if type(seterrorhandler) ~= "function" then return end
	local original = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(original) ~= "function" then original = nil end

	local logging = false

	seterrorhandler(function(message)
		if not logging then
			logging = true
			local ok, stack = pcall(debugstack, 2, 20, 20)
			stack = (ok and type(stack) == "string") and stack or ""
			local text = tostring(message or "unknown error")
			local ours = text:find("MacroVaultPro", 1, true) ~= nil
				or stack:find("MacroVaultPro", 1, true) ~= nil
			MV:LogError(text, stack, not ours)
			logging = false
		end
		if original then return original(message) end
	end)
end

MV:InstallErrorLog()

local function appendEntry(lines, entry)
	local tag = entry.unattributed and "  (no addon path)" or ""
	lines[#lines + 1] = ("[%s]%s"):format(tostring(entry.when or "?"), tag)
	for line in tostring(entry.text or ""):gmatch("[^\n]+") do
		lines[#lines + 1] = line
	end
	lines[#lines + 1] = ""
end

-- The whole log as one plain-text block - no prefix and no colour codes - so
-- the window's Copy button hands over exactly what a bug report needs.
function MV:ErrorsText()
	local own, other = ownStore(), otherStore()

	local ok, clientVersion, clientBuild, _, tocVersion = pcall(GetBuildInfo)
	if not ok then clientVersion, clientBuild, tocVersion = "?", "?", "?" end

	local lines = {
		("MacroVaultPro %s  build %s  client %s (build %s)  interface %s"):format(
			self.VERSION, self.BUILD, tostring(clientVersion), tostring(clientBuild), tostring(tocVersion)),
	}

	if #own == 0 and #other == 0 then
		lines[#lines + 1] = "nothing logged."
		return table.concat(lines, "\n")
	end

	lines[#lines + 1] = ("%d own + %d unattributed  -  saved in WTF/Account/<account>/SavedVariables/MacroVaultPro.lua"):format(
		#own, #other)
	lines[#lines + 1] = ""

	for i = #own, 1, -1 do appendEntry(lines, own[i]) end

	if #other > 0 then
		lines[#lines + 1] = ("-- %d with no addon path in the traceback - listed in case one is ours --"):format(#other)
		for i = #other, 1, -1 do appendEntry(lines, other[i]) end
	end

	return table.concat(lines, "\n")
end

-- Opens the log in its own small read-only window. Chat is only the fallback
-- for the case where the UI is missing, which should not happen after load.
function MV:ShowErrors()
	local own, other = ownStore(), otherStore()
	local text = self:ErrorsText()
	if self.UI and self.UI.ShowErrorLog then
		self.UI:ShowErrorLog(text, ("%d own, %d unattributed"):format(#own, #other))
	else
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			self:PrintRaw(line)
		end
	end
end

function MV:ClearErrors()
	MacroVaultProDB = MacroVaultProDB or {}
	MacroVaultProDB.errors, MacroVaultProDB.otherErrors = {}, {}
	MV.pendingErrors, MV.pendingOtherErrors = {}, {}
	if self.UI and self.UI.errorFrame and self.UI.errorFrame:IsShown() then
		self:ShowErrors()
	end
	self:Print("error log cleared.")
end

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

-- A line of a copyable block: no prefix and no colour codes, so the whole block
-- can be pasted into a message as it stands.
function MV:PrintRaw(message)
	if type(DEFAULT_CHAT_FRAME) == "table" and DEFAULT_CHAT_FRAME.AddMessage then
		pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, tostring(message))
	end
end

function MV:CountDrag(key)
	self.dragStats = self.dragStats or {}
	self.dragStats[key] = (self.dragStats[key] or 0) + 1
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

-- Not every command the tools ship lives in SlashCmdList: /dump, /api and
-- /fstack are handled by the client itself or by a Blizzard addon that only
-- loads once the command is typed, so there is no handler to call and the
-- lookup below would report them missing. Sending the line through the chat
-- parser is the path a typed command takes, so anything that works when typed
-- works from here too.
local function runThroughChat(line)
	local editBox = _G.ChatFrame1EditBox or (_G.ChatFrame1 and _G.ChatFrame1.editBox)
	if not editBox or type(_G.ChatEdit_SendText) ~= "function" then return false end
	if type(editBox.SetText) ~= "function" then return false end

	-- Never swallow a message the player had half-typed.
	local previous = ""
	if type(editBox.GetText) == "function" then
		local got, value = pcall(editBox.GetText, editBox)
		if got and value then previous = value end
	end

	editBox:SetText(line)
	local ok = pcall(_G.ChatEdit_SendText, editBox, false)
	pcall(editBox.SetText, editBox, previous)
	return ok
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
		-- Client-native and lazily loaded commands end up here. Hand the exact
		-- line to the chat parser before calling the command missing.
		local line = rest ~= "" and (slash .. " " .. rest) or slash
		if runThroughChat(line) then return true end
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
-- Macro maker: spells and macros as one ordered macro
--
-- The client cannot run one macro from inside another, so "do these in order"
-- is composition: every step is copied into a single body, top to bottom, and
-- the client runs the lines in that order. Two things follow from that, and both
-- are visible in the window: the body is capped at 255 characters, and it is
-- shown and counted while the sequence is built, because a truncated macro would
-- silently lose whichever step came last.
--
-- A macro step is remembered by name, never by slot index: the client renumbers
-- slots when a macro is deleted, so an index would point at a different macro a
-- week later.
-------------------------------------------------------------------------------

MV.MAKER_MAX_STEPS    = 12
MV.MAKER_DEFAULT_NAME = "MV Combo"

local MAKER_KINDS = { spell = true, macro = true }

function MV:GetMaker()
	if self.maker then return self.maker end

	local maker = { name = self.MAKER_DEFAULT_NAME, scope = "account", steps = {} }
	local saved = (type(MacroVaultProDB) == "table") and MacroVaultProDB.maker or nil

	if type(saved) == "table" then
		if type(saved.name) == "string" and trim(saved.name) ~= "" then
			maker.name = saved.name
		end
		maker.scope = saved.scope == "char" and "char" or "account"
		if type(saved.icon) == "number" or type(saved.icon) == "string" then
			maker.icon = saved.icon
		end
		if type(saved.macroIndex) == "number" then
			maker.macroIndex = saved.macroIndex
		end

		for _, step in ipairs(type(saved.steps) == "table" and saved.steps or {}) do
			if type(step) == "table" and MAKER_KINDS[step.kind]
				and type(step.value) == "string" and trim(step.value) ~= "" then
				maker.steps[#maker.steps + 1] = {
					kind  = step.kind,
					value = trim(step.value),
					icon  = step.icon,
				}
			end
		end
	end

	self.maker = maker
	return maker
end

function MV:SaveMaker()
	MacroVaultProDB = MacroVaultProDB or {}
	local maker = self:GetMaker()

	local steps = {}
	for index, step in ipairs(maker.steps) do
		steps[index] = { kind = step.kind, value = step.value, icon = step.icon }
	end

	MacroVaultProDB.maker = {
		name       = maker.name,
		scope      = maker.scope,
		icon       = maker.icon,
		macroIndex = maker.macroIndex,
		steps      = steps,
	}
end

-- The macro with this name, or nil. A saved sequence can only rely on names.
function MV:MakerFindMacro(name)
	if type(name) ~= "string" or name == "" then return nil end
	for _, macro in ipairs(self:GetMacros()) do
		if macro.name == name then return macro end
	end
	return nil
end

-- What one step adds to the body: its lines, or nil and why it cannot be used.
function MV:MakerStepLines(step)
	if type(step) ~= "table" then return nil, "not a step" end

	if step.kind == "spell" then
		return { "/cast " .. step.value }
	end

	if step.kind == "macro" then
		local macro = self:MakerFindMacro(step.value)
		if not macro then
			return nil, ("the macro '%s' has been renamed or deleted"):format(tostring(step.value))
		end

		local lines = {}
		for line in (normalizeBody(macro.body) .. "\n"):gmatch("([^\n]*)\n") do
			local trimmed = trim(line)
			-- Another macro's #showtooltip / #show lines are display directives for
			-- that macro; in the middle of this one they would do nothing and spend
			-- part of the 255 characters.
			if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
				lines[#lines + 1] = trimmed
			end
		end
		return lines
	end

	return nil, "unknown step"
end

-- The exact macro text, and anything that could not go in.
function MV:ComposeMaker(maker)
	maker = maker or self:GetMaker()

	local parts = { "#showtooltip" }
	local problems = {}

	for index, step in ipairs(maker.steps) do
		local lines, why = self:MakerStepLines(step)
		if not lines then
			problems[#problems + 1] = ("step %d: %s"):format(index, why or "cannot be used")
		else
			for _, line in ipairs(lines) do
				parts[#parts + 1] = line
			end
		end
	end

	return table.concat(parts, "\n"), problems
end

function MV:AddMakerStep(kind, value, icon, position)
	local maker = self:GetMaker()
	if not MAKER_KINDS[kind] then
		return false, "This maker takes spells and macros."
	end
	if type(value) ~= "string" or trim(value) == "" then
		return false, "That step has no name."
	end
	if #maker.steps >= self.MAKER_MAX_STEPS then
		return false, ("The sequence holds %d steps - remove one to add another."):format(self.MAKER_MAX_STEPS)
	end

	local step = { kind = kind, value = trim(value), icon = icon }
	if type(position) == "number" and position >= 1 and position <= #maker.steps then
		table.insert(maker.steps, position, step)
	else
		maker.steps[#maker.steps + 1] = step
	end

	self:SaveMaker()
	return true
end

-- Moves one step to another place in the list. The target is the index the step
-- should end up at after it has been taken out.
function MV:MoveMakerStep(from, to)
	local maker = self:GetMaker()
	if type(from) ~= "number" or type(to) ~= "number" then return false end
	if not maker.steps[from] then return false end
	if to < 1 then to = 1 end
	if to > #maker.steps then to = #maker.steps end

	local step = table.remove(maker.steps, from)
	table.insert(maker.steps, to, step)
	self:SaveMaker()
	return true
end

function MV:RemoveMakerStep(position)
	local maker = self:GetMaker()
	if not maker.steps[position] then return false end
	table.remove(maker.steps, position)
	self:SaveMaker()
	return true
end

function MV:ClearMakerSteps()
	local maker = self:GetMaker()
	maker.steps = {}
	self:SaveMaker()
end

-- Creates the real macro, or updates the one this sequence made last time.
-- Updating is what keeps a hotbar button working: an action button points at a
-- macro slot, so a second macro would leave the old button running the old
-- sequence.
function MV:BuildMakerMacro()
	local blocked = self:EditBlocked()
	if blocked then return nil, blocked end

	local maker = self:GetMaker()
	if #maker.steps == 0 then
		return nil, "Add at least one spell or macro to the sequence first."
	end

	local body, problems = self:ComposeMaker(maker)
	if #problems > 0 then
		return nil, "The sequence cannot be built yet - " .. table.concat(problems, "; ") .. "."
	end
	if #body > self.MAX_BODY then
		return nil, ("The sequence is %d characters; the client allows %d. Remove a step, or shorten one of its macros."):format(#body, self.MAX_BODY)
	end

	local name = trim(maker.name)
	if name == "" then name = self.MAKER_DEFAULT_NAME end
	if #name > self.MAX_NAME then name = name:sub(1, self.MAX_NAME) end
	maker.name = name

	local icon = maker.icon or (maker.steps[1] and maker.steps[1].icon) or 134400

	local existing = maker.macroIndex and self:GetMacro(maker.macroIndex)
	if existing and existing.name ~= name then existing = nil end

	local index, err
	if existing then
		index, err = self:UpdateMacro(existing.index, name, body, icon)
	else
		index, err = self:CreateMacro(name, body, icon, maker.scope == "char")
	end
	if not index then return nil, err end

	maker.macroIndex = index
	self:SaveMaker()
	return index
end

-- What is on the cursor, in the two shapes this maker accepts. A spell dragged
-- out of the spellbook is not delivered to any frame - it sits on the cursor,
-- so that is where it has to be read from.
function MV:CursorStep()
	if type(GetCursorInfo) ~= "function" then
		return nil, "This client does not report what is on the cursor."
	end

	local ok, kind, first, second = pcall(GetCursorInfo)
	if not ok or not kind then
		return nil, "Nothing is on the cursor - drag a spell from your spellbook, or use the list on the left."
	end

	if kind == "spell" then
		-- Which argument carries the spell id has moved between clients, so both
		-- are tried instead of trusting one of them.
		for _, candidate in ipairs({ first, second }) do
			if type(candidate) == "number" and candidate > 0 and type(GetSpellInfo) == "function" then
				local got, spellName, third, fourth = pcall(GetSpellInfo, candidate)
				if got and spellName then
					-- name, rank, icon on this client family; a client that drops the
					-- rank puts the icon in the next slot along.
					local icon = third
					if type(icon) ~= "number" and not (type(icon) == "string" and icon:find("\\", 1, true)) then
						icon = fourth
					end
					if type(icon) ~= "number" and not (type(icon) == "string" and icon:find("\\", 1, true)) then
						icon = 134400
					end
					return "spell", spellName, icon
				end
			end
		end
		return nil, "Could not read that spell's name from the cursor."
	end

	if kind == "macro" then
		local macro = self:GetMacro(first)
		if not macro then return nil, "That macro no longer exists." end
		return "macro", macro.name, macro.icon
	end

	return nil, ("The cursor holds a %s, which this maker cannot use."):format(tostring(kind))
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
-- Minimap button: the icon that sits by the map
--
-- Hand-rolled rather than pulled in from a library, so the addon still ships
-- with no dependencies. The angle around the minimap is what gets saved; the
-- radius is fixed, so the button stays in its ring on any minimap size.
-------------------------------------------------------------------------------

local MINIMAP_ICON  = "Interface\\AddOns\\MacroVaultPro\\Media\\icon.tga"
local MINIMAP_ANGLE = math.rad(220)

-- Sit on the rim of whatever minimap the client uses; a fixed radius drifts off
-- a smaller map and leaves a gap on a larger one.
local function minimapRadius()
	local width = Minimap and Minimap.GetWidth and Minimap:GetWidth()
	if type(width) == "number" and width > 0 then
		return width / 2 + 10
	end
	return 80
end

local function placeMinimapButton(button, angle)
	local radius = minimapRadius()
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function MV:CreateMinimapButton()
	if self.minimapButton or not Minimap then return end

	local button = CreateFrame("Button", "MacroVaultProMinimapButton", Minimap)
	button:SetSize(32, 32)
	button:SetFrameStrata("MEDIUM")
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- Dark plate behind the icon: the addon's own art is square, and a bare
	-- square on top of a round minimap edge reads as a hole.
	button.plate = button:CreateTexture(nil, "BACKGROUND")
	button.plate:SetAllPoints(button)
	button.plate:SetColorTexture(0.09, 0.08, 0.13, 0.95)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", 3, -3)
	button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
	button.icon:SetTexture(MINIMAP_ICON)

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(button)
	highlight:SetColorTexture(1, 1, 1, 0.12)

	button.angle = (MacroVaultProDB and type(MacroVaultProDB.minimapAngle) == "number")
		and MacroVaultProDB.minimapAngle or MINIMAP_ANGLE
	placeMinimapButton(button, button.angle)
	button:Raise()

	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then
			self.angle = MINIMAP_ANGLE
			placeMinimapButton(self, self.angle)
			if MacroVaultProDB then MacroVaultProDB.minimapAngle = self.angle end
			MV:Notify("Minimap button reset.")
		elseif self.moved then
			-- That press moved the icon around the ring, so it was a drag, not a click.
			self.moved = false
		else
			MV:Toggle()
		end
	end)

	-- Press, move, release: this is the path that does not depend on the client
	-- raising a drag event. OnDragStart/OnDragStop are wired below as well, so
	-- whichever of the two the client offers moves the icon.
	local function trackMinimap(self)
		local x, y = GetCursorPosition()
		if not x or not y then return end

		if not self.moved then
			if math.abs(x - (self.pressX or x)) + math.abs(y - (self.pressY or y)) < 6 then
				return
			end
			self.moved = true
			MV:CountDrag("minimapPress")
		end

		local scale = Minimap:GetEffectiveScale()
		if not scale or scale == 0 then return end
		local centerX, centerY = Minimap:GetCenter()
		if not centerX or not centerY then return end

		self.angle = (math.atan2 or math.atan)(y / scale - centerY, x / scale - centerX)
		placeMinimapButton(self, self.angle)
	end

	-- Ends a drag from either path. Running twice is harmless.
	local function finishMinimapDrag(self)
		self:SetScript("OnUpdate", nil)
		if self.moved and MacroVaultProDB then
			MacroVaultProDB.minimapAngle = self.angle
		end
	end

	-- Starts tracking from either path. OnDragStart only fires once the pointer
	-- has moved, so that press counts as a drag even before our own threshold
	-- has had a frame to run.
	local function startMinimapDrag(self, fromDragEvent)
		if fromDragEvent then
			if not self.moved then
				MV:CountDrag("minimapClient")
			end
			self.moved = true
		end
		self:SetScript("OnUpdate", trackMinimap)
	end

	button:RegisterForDrag("LeftButton")

	button:SetScript("OnDragStart", function(self)
		startMinimapDrag(self, true)
	end)

	button:SetScript("OnDragStop", function(self)
		finishMinimapDrag(self)
	end)

	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton ~= "LeftButton" then return end
		local x, y = GetCursorPosition()
		self.pressX, self.pressY = x or 0, y or 0
		self.moved = false
		startMinimapDrag(self, false)
	end)

	button:SetScript("OnMouseUp", function(self, mouseButton)
		if mouseButton ~= "LeftButton" then return end
		finishMinimapDrag(self)
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("MacroVaultPro", 1, 1, 1)
		GameTooltip:AddLine("Left-click to open the window.", 0.82, 0.82, 0.88)
		GameTooltip:AddLine("Drag to move it around the minimap.", 0.82, 0.82, 0.88)
		GameTooltip:AddLine("Right-click to put it back.", 0.82, 0.82, 0.88)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- A hidden button still gets built; it just never shows. Building it once and
	-- toggling its visibility keeps the saved angle and the drag scripts intact.
	-- Both branches are explicit rather than leaning on the client's default.
	if self:MinimapShown() then button:Show() else button:Hide() end

	self.minimapButton = button
end

-- Whether the button should be on screen. No setting means shown, so a fresh
-- install gets the button without having to opt in.
function MV:MinimapShown()
	return not (type(MacroVaultProDB) == "table" and MacroVaultProDB.minimapHidden)
end

function MV:SetMinimapShown(shown)
	self:CreateMinimapButton()
	local button = self.minimapButton
	if not button then return false, "The minimap is not available on this client." end

	MacroVaultProDB = MacroVaultProDB or {}
	if shown then
		MacroVaultProDB.minimapHidden = nil
		button:Show()
	else
		MacroVaultProDB.minimapHidden = true
		button:Hide()
	end
	return true
end

function MV:ToggleMinimap()
	local show = not self:MinimapShown()
	local ok, err = self:SetMinimapShown(show)
	if not ok then
		self:Notify(err, true)
		return
	end
	if show then
		self:Notify("Minimap button shown.")
	else
		self:Notify("Minimap button hidden - /mvpro minimap brings it back.")
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

	self:Print(("selftest  -  MacroVaultPro %s [%s] on client %s (build %s, interface %s)"):format(
		self.VERSION, self.BUILD, tostring(clientVersion), tostring(clientBuild), tostring(tocVersion)))

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
-- Diag: /mvpro diag
--
-- One block, meant to be pasted whole into a bug report. It answers the
-- questions a drag bug raises: which copy of the files is loaded, whether the
-- client has the APIs the two drag paths use, and which path actually fired the
-- last time something was dragged. The counts start again after a reload.
-------------------------------------------------------------------------------

local function yesNo(value)
	return value and "yes" or "no"
end

local function angleText(angle)
	if type(angle) ~= "number" then return "?" end
	if type(math.deg) == "function" then
		return ("%.0f deg"):format(math.deg(angle))
	end
	return ("%.2f rad"):format(angle)
end

function MV:Diag()
	local layout = self:GetLayout(true)
	local stats  = self.dragStats or {}

	local okBuild, clientVersion, clientBuild, _, tocVersion = pcall(GetBuildInfo)
	if not okBuild then
		clientVersion, clientBuild, tocVersion = "?", "?", "?"
	end

	-- Widget methods are globals on most clients; the frame probe covers a client
	-- that only answers RegisterForDrag on a frame that exists.
	local frame = self.UI and self.UI.frame
	if not frame and type(CreateFrame) == "function" then
		local made, probe = pcall(CreateFrame, "Frame")
		if made then frame = probe end
	end
	local registerForDrag = type(_G.RegisterForDrag) == "function"
		or (frame and type(frame.RegisterForDrag) == "function")

	local minimap  = _G.Minimap
	local mapWidth  = minimap and minimap.GetWidth  and minimap:GetWidth()
	local mapHeight = minimap and minimap.GetHeight and minimap:GetHeight()
	local mapShape  = minimap and minimap.GetShape  and minimap:GetShape()
	local button    = self.minimapButton

	self:Print("--- MacroVaultPro diag ---  copy down to the end line")
	self:PrintRaw(("addon %s  build %s  interface %s"):format(
		self.VERSION, self.BUILD, tostring(tocVersion)))
	self:PrintRaw(("client %s  build %s"):format(tostring(clientVersion), tostring(clientBuild)))
	self:PrintRaw(("globals MAX_ACCOUNT_MACROS=%s  MAX_CHARACTER_MACROS=%s"):format(
		tostring(_G.MAX_ACCOUNT_MACROS or "unset"), tostring(_G.MAX_CHARACTER_MACROS or "unset")))
	self:PrintRaw(("slots account 1-%d  character %d-%d  total %d  (from %s)"):format(
		layout.accountSlots, layout.boundary, layout.total, layout.total, layout.source))
	self:PrintRaw(("drag api RegisterForDrag=%s  IsMouseButtonDown=%s  GetMouseFocus=%s"):format(
		yesNo(registerForDrag),
		yesNo(type(_G.IsMouseButtonDown) == "function"),
		yesNo(type(_G.GetMouseFocus) == "function")))
	self:PrintRaw(("drag counts since load  press=%d  client=%d  drops=%d"):format(
		stats.press or 0, stats.client or 0, stats.drops or 0))
	self:PrintRaw(("minimap drags since load  press=%d  client=%d"):format(
		stats.minimapPress or 0, stats.minimapClient or 0))
	self:PrintRaw(("minimap %sx%s  shape %s  button %s  shown %s  angle %s"):format(
		mapWidth and math.floor(mapWidth + 0.5) or "?",
		mapHeight and math.floor(mapHeight + 0.5) or "?",
		tostring(mapShape or "?"),
		button and "built" or "missing",
		yesNo(self:MinimapShown()),
		angleText(button and button.angle)))
	self:PrintRaw("paths: press = button tracker, client = OnDragStart/OnDragStop")
	self:Print("--- end MacroVaultPro diag ---")
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
		if db.errors == nil then db.errors = {} end
		if db.otherErrors == nil then db.otherErrors = {} end
		if MV.UI then MV.UI:ApplyPosition() end
		MV:FoldPendingErrors()
		MV:CreateMinimapButton()
	elseif event == "PLAYER_LOGIN" then
		MV:Print(("v%s loaded - /mvpro"):format(MV.VERSION))
		-- The minimap may only be built by login on some clients, so both events
		-- ask for the button; it creates itself once and ignores the second call.
		MV:CreateMinimapButton()
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
	elseif msg == "macros" or msg == "maker" or msg == "tools" or msg == "library" or msg == "editor" or msg == "sheet" then
		MV:Open(msg)
	elseif msg == "selftest" or msg == "test" then
		MV:Selftest()
	elseif msg == "diag" then
		MV:Diag()
	elseif msg == "undo" then
		MV.UI:Build()
		MV.UI:UndoSheet()
	elseif msg == "minimap" then
		MV:ToggleMinimap()
	elseif msg == "errors" then
		MV:ShowErrors()
	elseif msg == "errors clear" or msg == "clearerrors" then
		MV:ClearErrors()
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
		MV:Print("Usage: /mvpro  |  /mvpro macros  |  /mvpro maker  |  /mvpro tools  |  /mvpro library  |  /mvpro editor  |  /mvpro sheet  |  /mvpro undo  |  /mvpro minimap  |  /mvpro selftest  |  /mvpro diag  |  /mvpro errors  |  /mvpro reset")
	end
end
