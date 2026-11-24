-- MacroVault - the window: macro browser, tool palette, library and editor
local ADDON_NAME, MV = ...

local UI = {}
MV.UI = UI

local WIDTH, HEIGHT = 820, 552

local FONT   = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local ACCENT = { 0.63, 0.50, 0.98 }
local TEXT   = { 0.88, 0.88, 0.92 }
local MUTED  = { 0.55, 0.55, 0.63 }

local ROW_HEIGHT = 28

-------------------------------------------------------------------------------
-- Small drawing helpers
-------------------------------------------------------------------------------

local function Text(parent, size, color, justify)
	local fs = parent:CreateFontString(nil, "ARTWORK")
	fs:SetFont(FONT, size or 12, "")
	fs:SetJustifyH(justify or "LEFT")
	local c = color or TEXT
	fs:SetTextColor(c[1], c[2], c[3])
	return fs
end

local function Paint(region, r, g, b, a)
	local texture = region:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints(region)
	texture:SetColorTexture(r, g, b, a)
	return texture
end

local function Border(region, r, g, b, a)
	local edges = {}

	local top = region:CreateTexture(nil, "BORDER")
	top:SetColorTexture(r, g, b, a)
	top:SetHeight(1)
	top:SetPoint("TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", 0, 0)
	edges[#edges + 1] = top

	local bottom = region:CreateTexture(nil, "BORDER")
	bottom:SetColorTexture(r, g, b, a)
	bottom:SetHeight(1)
	bottom:SetPoint("BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", 0, 0)
	edges[#edges + 1] = bottom

	local left = region:CreateTexture(nil, "BORDER")
	left:SetColorTexture(r, g, b, a)
	left:SetWidth(1)
	left:SetPoint("TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", 0, 0)
	edges[#edges + 1] = left

	local right = region:CreateTexture(nil, "BORDER")
	right:SetColorTexture(r, g, b, a)
	right:SetWidth(1)
	right:SetPoint("TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", 0, 0)
	edges[#edges + 1] = right

	region.borderEdges = edges
	return edges
end

local function SetBorderColor(region, r, g, b, a)
	for _, edge in ipairs(region.borderEdges or {}) do
		edge:SetColorTexture(r, g, b, a)
	end
end

local function showIf(region, condition)
	if condition then
		region:Show()
	else
		region:Hide()
	end
end

local function matches(haystack, needle)
	if not needle or needle == "" then return true end
	return (haystack or ""):lower():find(needle, 1, true) ~= nil
end

local function AttachTooltip(frame, title, lines)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1, 1, true)
		for _, line in ipairs(lines) do
			if line and line ~= "" then
				GameTooltip:AddLine(line, 0.82, 0.82, 0.88, true)
			end
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-------------------------------------------------------------------------------
-- Widget factories
-------------------------------------------------------------------------------

function UI:MakeButton(parent, label, width, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width or 100, 24)
	button.bg = Paint(button, 0.15, 0.14, 0.20, 1)

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(button)
	highlight:SetColorTexture(1, 1, 1, 0.07)

	button.label = Text(button, 12, TEXT, "CENTER")
	button.label:SetPoint("CENTER", 0, 0)
	button.label:SetText(label)

	button.SetActive = function(self, active)
		if active then
			self.bg:SetColorTexture(0.33, 0.25, 0.55, 1)
			self.label:SetTextColor(1, 1, 1)
		else
			self.bg:SetColorTexture(0.15, 0.14, 0.20, 1)
			self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		end
	end

	button.SetLabel = function(self, text)
		self.label:SetText(text)
	end

	if onClick then
		button:SetScript("OnClick", onClick)
	end

	button:SetActive(false)
	return button
end

function UI:MakeEditBox(parent, width, height)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(width, height or 24)
	box:SetAutoFocus(false)
	box:SetFont(FONT, 12, "")
	box:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	box:SetTextInsets(8, 8, 0, 0)
	Paint(box, 0.09, 0.09, 0.12, 1)
	Border(box, 0.22, 0.20, 0.30, 1)

	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEditFocusGained", function(self)
		SetBorderColor(self, ACCENT[1], ACCENT[2], ACCENT[3], 1)
	end)
	box:SetScript("OnEditFocusLost", function(self)
		SetBorderColor(self, 0.22, 0.20, 0.30, 1)
	end)

	return box
end

-- Read-only scrolling text block. Returns scrollFrame, fontString, setText.
local function CreateBodyView(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -8, 8)
	scroll:EnableMouseWheel(true)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(10, 10)
	scroll:SetScrollChild(child)

	local text = child:CreateFontString(nil, "ARTWORK")
	text:SetFont(FONT, 12, "")
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetPoint("TOPLEFT", 0, 0)
	text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])

	local function resize()
		local width = math.max((scroll:GetWidth() or 200) - 6, 60)
		child:SetWidth(width)
		text:SetWidth(width - 4)
		local height = text:GetStringHeight() or 0
		child:SetHeight(math.max(height + 8, 1))
	end

	local function scrollBy(_, delta)
		local maxScroll = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
		local value = scroll:GetVerticalScroll() - (delta or 0) * 40
		scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, value)))
	end

	scroll:SetScript("OnMouseWheel", scrollBy)
	scroll:SetScript("OnSizeChanged", resize)
	child:EnableMouseWheel(true)
	child:SetScript("OnMouseWheel", scrollBy)

	local function setText(value)
		text:SetText(value or "")
		resize()
		scroll:SetVerticalScroll(0)
	end

	return scroll, text, setText
end

-------------------------------------------------------------------------------
-- Scrollable list
-------------------------------------------------------------------------------

function UI:CreateList(parent)
	local list = { rows = {}, items = {}, selectedKey = nil }

	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetPoint("TOPLEFT")
	scroll:SetPoint("BOTTOMRIGHT")
	scroll:EnableMouseWheel(true)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(10, 10)
	scroll:SetScrollChild(child)

	local empty = Text(scroll, 12, MUTED, "CENTER")
	empty:SetPoint("CENTER", 0, 0)
	empty:SetWidth(250)
	empty:SetText("Nothing here yet.")
	empty:Hide()

	local function scrollBy(_, delta)
		local maxScroll = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
		local value = scroll:GetVerticalScroll() - (delta or 0) * ROW_HEIGHT * 1.5
		scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, value)))
	end

	scroll:SetScript("OnMouseWheel", scrollBy)
	child:EnableMouseWheel(true)
	child:SetScript("OnMouseWheel", scrollBy)
	scroll:SetScript("OnSizeChanged", function(_, width)
		child:SetWidth(math.max(width or 10, 10))
	end)

	function list:SetEmptyText(value)
		empty:SetText(value)
	end

	function list:CreateRow(index)
		local row = CreateFrame("Button", nil, child)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
		row:SetPoint("TOPRIGHT", 0, -((index - 1) * ROW_HEIGHT))
		row:EnableMouseWheel(true)
		row:SetScript("OnMouseWheel", scrollBy)

		row.sel = row:CreateTexture(nil, "BACKGROUND")
		row.sel:SetAllPoints(row)
		row.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)
		row.sel:Hide()

		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints(row)
		highlight:SetColorTexture(1, 1, 1, 0.06)

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(20, 20)
		row.icon:SetPoint("LEFT", 8, 0)
		row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		row.name = Text(row, 12, TEXT)
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
		row.name:SetWidth(200)
		if row.name.SetWordWrap then
			row.name:SetWordWrap(false)
		end

		row.tag = Text(row, 10, MUTED, "RIGHT")
		row.tag:SetPoint("RIGHT", -8, 0)

		row:SetScript("OnClick", function(self)
			if list.onSelect then
				list.onSelect(self.item)
			end
		end)

		return row
	end

	function list:ApplySelection()
		for _, row in ipairs(self.rows) do
			showIf(row.sel, row.item ~= nil and row.item.key == self.selectedKey)
		end
	end

	function list:SetSelected(key)
		self.selectedKey = key
		self:ApplySelection()
	end

	function list:SetItems(items, render, onSelect)
		self.items = items
		self.render = render
		self.onSelect = onSelect

		local count = #items
		for i = 1, count do
			local row = self.rows[i]
			if not row then
				row = self:CreateRow(i)
				self.rows[i] = row
			end
			row.item = items[i]
			row:Show()
			if render then render(row, items[i]) end
		end

		for i = count + 1, #self.rows do
			self.rows[i].item = nil
			self.rows[i]:Hide()
		end

		child:SetHeight(math.max(count * ROW_HEIGHT + 2, 1))
		showIf(empty, count == 0)
		scroll:SetVerticalScroll(0)
		self:ApplySelection()
	end

	return list
end

-------------------------------------------------------------------------------
-- Window construction
-------------------------------------------------------------------------------

function UI:Build()
	if self.frame then return end

	if not self.libraryScope then
		self.libraryScope = (MacroVaultDB and MacroVaultDB.perCharacter) and "char" or "account"
	end
	if not self.editorScope then
		self.editorScope = (MacroVaultDB and MacroVaultDB.perCharacter) and "char" or "account"
	end

	local frame = CreateFrame("Frame", "MacroVaultFrame", UIParent)
	self.frame = frame
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		MV:SavePosition()
	end)
	frame:Hide()

	Paint(frame, 0.045, 0.045, 0.06, 0.97)
	Border(frame, 0.30, 0.25, 0.45, 1)

	tinsert(UISpecialFrames, "MacroVaultFrame")
	self:ApplyPosition()

	local title = Text(frame, 19, ACCENT)
	title:SetPoint("TOPLEFT", 16, -12)
	title:SetText("MacroVault")

	local subtitle = Text(frame, 11, MUTED)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -2)
	subtitle:SetText("every macro you own, plus the client's own tools")

	local close = CreateFrame("Button", nil, frame)
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -8, -8)
	local closeText = Text(close, 15, MUTED, "CENTER")
	closeText:SetPoint("CENTER", 0, 0)
	closeText:SetText("X")
	close:SetScript("OnEnter", function() closeText:SetTextColor(1, 1, 1) end)
	close:SetScript("OnLeave", function() closeText:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
	close:SetScript("OnClick", function() frame:Hide() end)

	self.tabs = {}
	local tabs = {
		{ id = "macros",  label = "My macros" },
		{ id = "tools",   label = "Tools" },
		{ id = "library", label = "Library" },
		{ id = "editor",  label = "Editor" },
	}
	local x = 14
	for _, tab in ipairs(tabs) do
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(92, 24)
		button:SetPoint("TOPLEFT", x, -50)

		local label = Text(button, 13, MUTED, "CENTER")
		label:SetPoint("CENTER", 0, 1)
		label:SetText(tab.label)

		local line = button:CreateTexture(nil, "ARTWORK")
		line:SetHeight(2)
		line:SetPoint("BOTTOMLEFT", 6, 0)
		line:SetPoint("BOTTOMRIGHT", -6, 0)
		line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
		line:Hide()

		button.label = label
		button.line = line
		button:SetScript("OnClick", function() self:SwitchTab(tab.id) end)
		button:SetScript("OnEnter", function()
			if self.activeTab ~= tab.id then label:SetTextColor(0.8, 0.8, 0.86) end
		end)
		button:SetScript("OnLeave", function()
			if self.activeTab ~= tab.id then label:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end
		end)

		self.tabs[tab.id] = button
		x = x + 96
	end

	local search = self:MakeEditBox(frame, 220, 24)
	search:SetPoint("TOPRIGHT", -14, -50)
	local placeholder = Text(search, 11, MUTED)
	placeholder:SetPoint("LEFT", 9, 0)
	placeholder:SetText("search")
	search:SetScript("OnTextChanged", function(self)
		showIf(placeholder, (self:GetText() or "") == "")
		UI:Refresh()
	end)
	self.search = search

	self.panels = {}
	for _, id in ipairs({ "macros", "tools", "library", "editor" }) do
		local panel = CreateFrame("Frame", nil, frame)
		panel:SetPoint("TOPLEFT", 12, -82)
		panel:SetPoint("BOTTOMRIGHT", -12, 34)
		panel:Hide()
		self.panels[id] = panel
	end

	self:BuildMacrosPanel(self.panels.macros)
	self:BuildToolsPanel(self.panels.tools)
	self:BuildLibraryPanel(self.panels.library)
	self:BuildEditorPanel(self.panels.editor)

	local status = Text(frame, 11, MUTED)
	status:SetPoint("BOTTOMLEFT", 14, 13)
	status:SetWidth(640)
	self.status = status

	local footer = Text(frame, 10, MUTED, "RIGHT")
	footer:SetPoint("BOTTOMRIGHT", -14, 13)
	footer:SetText("Forever - /mvault")

	self:SwitchTab((MacroVaultDB and MacroVaultDB.tab) or "macros")
end

function UI:ApplyPosition()
	local frame = self.frame
	if not frame then return end

	local position = MacroVaultDB and MacroVaultDB.position
	frame:ClearAllPoints()
	if position and position.point then
		frame:SetPoint(position.point, UIParent, position.relPoint or position.point, position.x or 0, position.y or 0)
	else
		frame:SetPoint("CENTER")
	end
end

function UI:Show(tab)
	self:Build()
	if not self.frame:IsShown() then
		self.frame:Show()
	end
	self:SwitchTab(tab or self.activeTab or "macros")
end

function UI:SetStatus(message, isError)
	if not self.status then return end
	self.status:SetText(tostring(message or ""))
	if isError then
		self.status:SetTextColor(1, 0.5, 0.45)
	else
		self.status:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	end
end

function UI:SwitchTab(id)
	if not self.frame or not self.panels[id] then return end

	self.activeTab = id
	for key, panel in pairs(self.panels) do
		showIf(panel, key == id)
	end

	for key, tab in pairs(self.tabs) do
		local active = key == id
		if active then
			tab.label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		else
			tab.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
		showIf(tab.line, active)
	end

	showIf(self.search, id == "macros" or id == "library")
	if MacroVaultDB then MacroVaultDB.tab = id end

	self:Refresh()
end

function UI:SearchTerm()
	local box = self.search
	if not box or not box:IsShown() then return "" end
	return (box:GetText() or ""):lower()
end

function UI:Refresh()
	if not self.frame then return end

	if self.activeTab == "macros" then
		self:RefreshMacros()
	elseif self.activeTab == "library" then
		self:RefreshLibrary()
	end
end

-------------------------------------------------------------------------------
-- My macros tab
-------------------------------------------------------------------------------

function UI:BuildMacrosPanel(panel)
	local listPane = CreateFrame("Frame", nil, panel)
	listPane:SetPoint("TOPLEFT")
	listPane:SetPoint("BOTTOMLEFT")
	listPane:SetWidth(344)
	Paint(listPane, 0.055, 0.055, 0.075, 0.9)

	local header = Text(listPane, 10, MUTED)
	header:SetPoint("TOPLEFT", 10, -9)
	header:SetWidth(330)
	header:SetText("MY MACROS")
	self.macroListHeader = header

	local inner = CreateFrame("Frame", nil, listPane)
	inner:SetPoint("TOPLEFT", 4, -24)
	inner:SetPoint("BOTTOMRIGHT", -4, 4)

	self.macroList = self:CreateList(inner)
	self.macroList:SetEmptyText("No macros match.")

	local detail = CreateFrame("Frame", nil, panel)
	detail:SetPoint("TOPLEFT", listPane, "TOPRIGHT", 12, 0)
	detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	Paint(detail, 0.055, 0.055, 0.075, 0.9)

	self:BuildMacroDetail(detail)
end

function UI:BuildMacroDetail(detail)
	local ui = self

	local content = CreateFrame("Frame", nil, detail)
	content:SetAllPoints(detail)
	self.macroContent = content

	local icon = content:CreateTexture(nil, "ARTWORK")
	icon:SetSize(46, 46)
	icon:SetPoint("TOPLEFT", 16, -14)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	self.macroIcon = icon

	local name = Text(content, 17, TEXT)
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4)
	name:SetWidth(340)
	self.macroName = name

	local meta = Text(content, 11, MUTED)
	meta:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 1, -4)
	meta:SetWidth(340)
	self.macroMeta = meta

	local bodyLabel = Text(content, 10, MUTED)
	bodyLabel:SetPoint("TOPLEFT", 16, -78)
	bodyLabel:SetText("BODY")
	self.macroBodyLabel = bodyLabel

	local bodyBox = CreateFrame("Frame", nil, content)
	bodyBox:SetPoint("TOPLEFT", 16, -92)
	bodyBox:SetPoint("BOTTOMRIGHT", -16, 50)
	Paint(bodyBox, 0.02, 0.02, 0.03, 0.9)
	Border(bodyBox, 0.16, 0.15, 0.22, 1)

	self.macroBodyScroll, self.macroBodyText, self.macroBodySet = CreateBodyView(bodyBox)

	local inject = ui:MakeButton(content, "Inject (pick up)", 128, function() ui:PickupSelected() end)
	inject:SetPoint("BOTTOMLEFT", 16, 14)

	local edit = ui:MakeButton(content, "Edit", 64, function() ui:EditSelected() end)
	edit:SetPoint("LEFT", inject, "RIGHT", 8, 0)

	local duplicate = ui:MakeButton(content, "Duplicate", 86, function() ui:DuplicateSelected() end)
	duplicate:SetPoint("LEFT", edit, "RIGHT", 8, 0)

	local macroUI = ui:MakeButton(content, "Macro UI", 84, function() ui:OpenMacroWindow() end)
	macroUI:SetPoint("LEFT", duplicate, "RIGHT", 8, 0)

	local empty = Text(detail, 12, MUTED, "CENTER")
	empty:SetPoint("CENTER", 0, 30)
	empty:SetWidth(320)
	empty:SetText("Select a macro on the left to read it and inject it.")
	self.macroEmpty = empty
end

function UI:RenderMacroRow(row, macro)
	row.icon:SetTexture(macro.icon or 134400)
	row.name:SetText(macro.name)
	row.tag:SetText(macro.scope == "char" and "character" or "account")
	if macro.scope == "char" then
		row.tag:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
	else
		row.tag:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	end
end

function UI:RefreshMacros()
	if not self.macroList then return end

	local term = self:SearchTerm()
	local items = {}
	local accountCount, characterCount = 0, 0
	for _, macro in ipairs(MV:GetMacros()) do
		if macro.scope == "char" then
			characterCount = characterCount + 1
		else
			accountCount = accountCount + 1
		end
		if matches(macro.name .. " " .. macro.body .. " " .. macro.scope, term) then
			items[#items + 1] = macro
		end
	end

	table.sort(items, function(a, b)
		if a.scope ~= b.scope then
			return a.scope == "char"
		end
		return a.name:lower() < b.name:lower()
	end)

	local layout = MV:GetLayout()
	self.macroListHeader:SetText(("MY MACROS   account %d/%d   character %d/%d"):format(
		accountCount, layout.accountSlots, characterCount, layout.characterSlots
	))
	self.macroList:SetItems(
		items,
		function(row, item) self:RenderMacroRow(row, item) end,
		function(item) self:SelectMacro(item.index) end
	)
	self.macroList:SetSelected(self.selectedMacroIndex)

	if self.selectedMacroIndex then
		local macro = MV:GetMacro(self.selectedMacroIndex)
		if not macro then
			self.selectedMacroIndex = nil
			self:ShowMacroDetail(nil)
		else
			self:ShowMacroDetail(macro)
		end
	elseif #items > 0 then
		self:SelectMacro(items[1].index)
	else
		self:ShowMacroDetail(nil)
	end
end

function UI:SelectMacro(index)
	self.selectedMacroIndex = index
	local macro = MV:GetMacro(index)
	self:ShowMacroDetail(macro)
	if self.macroList then
		self.macroList:SetSelected(index)
	end
end

function UI:ShowMacroDetail(macro)
	if not self.macroContent then return end

	if not macro then
		self.macroContent:Hide()
		self.macroEmpty:Show()
		return
	end

	self.macroContent:Show()
	self.macroEmpty:Hide()
	self.macroIcon:SetTexture(macro.icon or 134400)
	self.macroName:SetText(macro.name)
	self.macroMeta:SetText(("%s macro  -  slot %d  -  %d characters"):format(
		macro.scope == "char" and "Character" or "Account",
		macro.index,
		#macro.body
	))
	self.macroBodyLabel:SetText(("BODY  (%d/%d)"):format(#macro.body, MV.MAX_BODY))
	self.macroBodySet(macro.body)
end

function UI:PickupSelected()
	if not self.selectedMacroIndex then
		self:SetStatus("Select a macro first.", true)
		return
	end

	local ok, err = MV:Pickup(self.selectedMacroIndex)
	if not ok then
		self:SetStatus(err or "Could not pick up that macro.", true)
		return
	end

	self:SetStatus("Macro on your cursor - drop it on an action bar.")
	self.frame:Hide()
end

function UI:EditSelected()
	if not self.selectedMacroIndex then
		self:SetStatus("Select a macro first.", true)
		return
	end
	self:LoadEditor(self.selectedMacroIndex)
end

function UI:DuplicateSelected()
	local macro = self.selectedMacroIndex and MV:GetMacro(self.selectedMacroIndex)
	if not macro then
		self:SetStatus("Select a macro first.", true)
		return
	end

	self:LoadEditor(nil, {
		name = macro.name,
		body = macro.body,
		icon = macro.icon,
		scope = macro.scope,
	})
	self:SetStatus("Editing a copy - change the name, then press Save macro.")
end

function UI:OpenMacroWindow()
	self.frame:Hide()
	local ok, err = MV:OpenMacroUI()
	if not ok then
		self.frame:Show()
		self:SetStatus(err or "Could not open the macro window.", true)
	end
end

-------------------------------------------------------------------------------
-- Tools tab
-------------------------------------------------------------------------------

function UI:BuildToolsPanel(panel)
	local intro = Text(panel, 11, MUTED)
	intro:SetPoint("TOPLEFT", 2, -2)
	intro:SetWidth(780)
	intro:SetText("Runs the client's own slash commands, exactly as if you typed them - /fstack included. " ..
		"These are UI and debug tools; combat actions live in the Library as macros.")

	local grid = CreateFrame("Frame", nil, panel)
	grid:SetPoint("TOPLEFT", 0, -42)
	grid:SetPoint("BOTTOMRIGHT", 0, 0)

	local ui = self
	for index, tool in ipairs(MV.TOOLS) do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)

		local button = CreateFrame("Button", nil, grid)
		button:SetSize(380, 40)
		button:SetPoint("TOPLEFT", column * 396, -row * 46)
		Paint(button, 0.075, 0.07, 0.10, 0.95)

		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints(button)
		highlight:SetColorTexture(1, 1, 1, 0.06)

		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetSize(26, 26)
		icon:SetPoint("LEFT", 8, 0)
		icon:SetTexture(tool.icon)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		local label = Text(button, 13, TEXT)
		label:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -3)
		label:SetText(tool.label)

		local detail = Text(button, 10, MUTED)
		detail:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
		detail:SetWidth(310)
		detail:SetText(tool.cmd or "open")
		if detail.SetWordWrap then
			detail:SetWordWrap(false)
		end

		button:SetScript("OnClick", function()
			local ok, err = MV:RunTool(tool)
			if not ok then
				ui:SetStatus(err or "The client blocked that command.", true)
			elseif not tool.run then
				ui:SetStatus(("%s: ran %s"):format(tool.label, tool.cmd))
			end
		end)

		AttachTooltip(button, tool.label, { tool.desc or "", tool.cmd or "" })
	end
end

-------------------------------------------------------------------------------
-- Library tab
-------------------------------------------------------------------------------

function UI:BuildLibraryPanel(panel)
	local listPane = CreateFrame("Frame", nil, panel)
	listPane:SetPoint("TOPLEFT")
	listPane:SetPoint("BOTTOMLEFT")
	listPane:SetWidth(344)
	Paint(listPane, 0.055, 0.055, 0.075, 0.9)

	local header = Text(listPane, 10, MUTED)
	header:SetPoint("TOPLEFT", 10, -9)
	header:SetText("LIBRARY")
	self.libraryListHeader = header

	local inner = CreateFrame("Frame", nil, listPane)
	inner:SetPoint("TOPLEFT", 4, -24)
	inner:SetPoint("BOTTOMRIGHT", -4, 4)

	self.libraryList = self:CreateList(inner)
	self.libraryList:SetEmptyText("No library macros match.")

	local detail = CreateFrame("Frame", nil, panel)
	detail:SetPoint("TOPLEFT", listPane, "TOPRIGHT", 12, 0)
	detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	Paint(detail, 0.055, 0.055, 0.075, 0.9)

	self:BuildLibraryDetail(detail)
end

function UI:BuildLibraryDetail(detail)
	local ui = self

	local content = CreateFrame("Frame", nil, detail)
	content:SetAllPoints(detail)
	self.libraryContent = content

	local icon = content:CreateTexture(nil, "ARTWORK")
	icon:SetSize(42, 42)
	icon:SetPoint("TOPLEFT", 16, -14)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	self.libraryIcon = icon

	local title = Text(content, 16, TEXT)
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
	title:SetWidth(350)
	self.libraryTitle = title

	local group = Text(content, 11, ACCENT)
	group:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -4)
	self.libraryGroup = group

	local desc = Text(content, 11, MUTED)
	desc:SetPoint("TOPLEFT", 16, -68)
	desc:SetWidth(400)
	self.libraryDesc = desc

	local bodyLabel = Text(content, 10, MUTED)
	bodyLabel:SetPoint("TOPLEFT", 16, -106)
	bodyLabel:SetText("MACRO TEXT")
	self.libraryBodyLabel = bodyLabel

	local bodyBox = CreateFrame("Frame", nil, content)
	bodyBox:SetPoint("TOPLEFT", 16, -120)
	bodyBox:SetPoint("BOTTOMRIGHT", -16, 90)
	Paint(bodyBox, 0.02, 0.02, 0.03, 0.9)
	Border(bodyBox, 0.16, 0.15, 0.22, 1)

	self.libraryBodySet = select(3, CreateBodyView(bodyBox))

	local scope = ui:MakeButton(content, "Create on: account-wide", 184, function() ui:ToggleLibraryScope() end)
	scope:SetPoint("BOTTOMLEFT", 16, 48)
	self.libraryScopeButton = scope

	local createPickup = ui:MakeButton(content, "Create & pick up", 136, function() ui:CreateLibraryMacro(true) end)
	createPickup:SetPoint("BOTTOMLEFT", 16, 14)

	local create = ui:MakeButton(content, "Create", 72, function() ui:CreateLibraryMacro(false) end)
	create:SetPoint("LEFT", createPickup, "RIGHT", 8, 0)

	local edit = ui:MakeButton(content, "Edit", 64, function() ui:EditLibraryMacro() end)
	edit:SetPoint("LEFT", create, "RIGHT", 8, 0)

	local empty = Text(detail, 12, MUTED, "CENTER")
	empty:SetPoint("CENTER", 0, 30)
	empty:SetWidth(320)
	empty:SetText("Select a library macro on the left.")
	self.libraryEmpty = empty
end

function UI:RenderLibraryRow(row, item)
	row.icon:SetTexture(item.icon)
	row.name:SetText(item.label)
	row.tag:SetText(item.group)
	row.tag:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
end

function UI:RefreshLibrary()
	if not self.libraryList then return end

	local term = self:SearchTerm()
	local items = {}
	for _, item in ipairs(MV.LIBRARY) do
		if matches(item.label .. " " .. item.group .. " " .. (item.desc or "") .. " " .. item.body, term) then
			items[#items + 1] = item
		end
	end

	self.libraryListHeader:SetText(("LIBRARY  %d"):format(#items))
	self.libraryList:SetItems(
		items,
		function(row, item) self:RenderLibraryRow(row, item) end,
		function(item) self:SelectLibrary(item) end
	)

	if not self.selectedLibrary or not self.selectedLibrary.id then
		self.selectedLibrary = items[1]
	elseif #items > 0 then
		local found
		for _, item in ipairs(items) do
			if item.id == self.selectedLibrary.id then
				found = item
				break
			end
		end
		self.selectedLibrary = found or items[1]
	end

	if self.selectedLibrary then
		self.libraryList:SetSelected(self.selectedLibrary.id)
		self:ShowLibraryDetail(self.selectedLibrary)
	else
		self.libraryList:SetSelected(nil)
		self:ShowLibraryDetail(nil)
	end
end

function UI:SelectLibrary(item)
	self.selectedLibrary = item
	if self.libraryList then
		self.libraryList:SetSelected(item and item.id)
	end
	self:ShowLibraryDetail(item)
end

function UI:ShowLibraryDetail(item)
	if not self.libraryContent then return end

	if not item then
		self.libraryContent:Hide()
		self.libraryEmpty:Show()
		return
	end

	self.libraryContent:Show()
	self.libraryEmpty:Hide()
	self.libraryIcon:SetTexture(item.icon)
	self.libraryTitle:SetText(item.label)
	self.libraryGroup:SetText(item.group)
	self.libraryDesc:SetText(item.desc or "")
	self.libraryBodyLabel:SetText(("MACRO TEXT  (%d/%d)"):format(#item.body, MV.MAX_BODY))
	self.libraryBodySet(item.body)
	self.libraryScopeButton:SetLabel(("Create on: %s"):format(
		self.libraryScope == "char" and "this character" or "account-wide"
	))
end

function UI:ToggleLibraryScope()
	self.libraryScope = self.libraryScope == "char" and "account" or "char"
	if MacroVaultDB then
		MacroVaultDB.perCharacter = self.libraryScope == "char"
	end
	if self.selectedLibrary then
		self:ShowLibraryDetail(self.selectedLibrary)
	end
	self:SetStatus(self.libraryScope == "char"
		and "New library macros go to this character."
		or "New library macros are account-wide.")
end

function UI:CreateLibraryMacro(pickup)
	local item = self.selectedLibrary
	if not item then
		self:SetStatus("Select a library macro first.", true)
		return
	end

	local index, err = MV:CreateMacro(item.label, item.body, item.icon, self.libraryScope == "char")
	if not index then
		self:SetStatus(err or "Could not create the macro.", true)
		return
	end

	local macro = MV:GetMacro(index)
	self.selectedMacroIndex = index

	if pickup then
		local ok, pickupError = MV:Pickup(index)
		if ok then
			self:SetStatus("Macro on your cursor - drop it on an action bar.")
			self.frame:Hide()
		else
			self:SetStatus(pickupError or "Created the macro, but could not pick it up.", true)
		end
	else
		self:SetStatus(("Created '%s' in slot %d."):format(macro and macro.name or item.label, index))
	end
end

function UI:EditLibraryMacro()
	local item = self.selectedLibrary
	if not item then
		self:SetStatus("Select a library macro first.", true)
		return
	end
	self:LoadEditor(nil, {
		name = item.label,
		body = item.body,
		icon = item.icon,
		scope = self.libraryScope,
	})
end

-------------------------------------------------------------------------------
-- Editor tab
-------------------------------------------------------------------------------

function UI:BuildEditorPanel(panel)
	local ui = self

	local header = Text(panel, 15, ACCENT)
	header:SetPoint("TOPLEFT", 4, -2)
	header:SetText("New macro")
	self.editorHeader = header

	local nameLabel = Text(panel, 10, MUTED)
	nameLabel:SetPoint("TOPLEFT", 4, -38)
	nameLabel:SetText("NAME (16 characters max)")

	local name = ui:MakeEditBox(panel, 300, 26)
	name:SetPoint("TOPLEFT", 4, -52)
	name:SetMaxLetters(MV.MAX_NAME)
	self.editorName = name

	local iconLabel = Text(panel, 10, MUTED)
	iconLabel:SetPoint("TOPLEFT", 320, -38)
	iconLabel:SetText("ICON (fileID or texture path)")

	local icon = ui:MakeEditBox(panel, 300, 26)
	icon:SetPoint("TOPLEFT", 320, -52)
	self.editorIcon = icon

	local preview = panel:CreateTexture(nil, "ARTWORK")
	preview:SetSize(26, 26)
	preview:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	preview:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	preview:SetTexture(134400)
	self.editorIconPreview = preview

	icon:SetScript("OnTextChanged", function()
		local value = MV.trim(icon:GetText())
		if value == "" then value = 134400 end
		preview:SetTexture(tonumber(value) or value)
	end)

	local scopeLabel = Text(panel, 10, MUTED)
	scopeLabel:SetPoint("TOPLEFT", 4, -90)
	scopeLabel:SetText("SCOPE")

	self.scopeButtons = {}
	local account = ui:MakeButton(panel, "Account-wide", 104, function() ui:SetEditorScope("account") end)
	account:SetPoint("TOPLEFT", 4, -104)

	local character = ui:MakeButton(panel, "Character only", 112, function() ui:SetEditorScope("char") end)
	character:SetPoint("LEFT", account, "RIGHT", 6, 0)

	self.scopeButtons.account = account
	self.scopeButtons.char = character

	local scopeNote = Text(panel, 10, MUTED)
	scopeNote:SetPoint("LEFT", character, "RIGHT", 10, 0)
	scopeNote:SetText("choose where new macros live")
	self.scopeNote = scopeNote

	local bodyLabel = Text(panel, 10, MUTED)
	bodyLabel:SetPoint("TOPLEFT", 4, -140)
	bodyLabel:SetText("BODY")

	local counter = Text(panel, 10, MUTED, "RIGHT")
	counter:SetPoint("TOPRIGHT", -4, -140)
	counter:SetText("0 / " .. MV.MAX_BODY)
	self.editorCounter = counter

	local body = CreateFrame("EditBox", nil, panel)
	body:SetPoint("TOPLEFT", 4, -154)
	body:SetPoint("BOTTOMRIGHT", -4, 48)
	body:SetMultiLine(true)
	body:SetAutoFocus(false)
	body:SetFont(FONT, 12, "")
	body:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	body:SetTextInsets(8, 8, 8, 8)
	body:SetMaxLetters(4000)
	Paint(body, 0.02, 0.02, 0.03, 0.92)
	Border(body, 0.20, 0.18, 0.28, 1)
	body:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	body:SetScript("OnTextChanged", function(self)
		local count = #(self:GetText() or "")
		counter:SetText(("%d / %d"):format(count, MV.MAX_BODY))
		if count > MV.MAX_BODY then
			counter:SetTextColor(1, 0.5, 0.45)
		else
			counter:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
	end)
	self.editorBody = body

	local save = ui:MakeButton(panel, "Save macro", 110, function() ui:SaveEditor() end)
	save:SetPoint("BOTTOMLEFT", 4, 6)

	local pickup = ui:MakeButton(panel, "Pick up", 82, function() ui:PickupEditor() end)
	pickup:SetPoint("LEFT", save, "RIGHT", 8, 0)

	local fresh = ui:MakeButton(panel, "New", 64, function() ui:NewEditor() end)
	fresh:SetPoint("LEFT", pickup, "RIGHT", 8, 0)

	local macroUI = ui:MakeButton(panel, "Macro UI", 84, function() ui:OpenMacroWindow() end)
	macroUI:SetPoint("LEFT", fresh, "RIGHT", 8, 0)

	self:UpdateEditorScope()
end

function UI:UpdateEditorHeader()
	if not self.editorHeader then return end

	if self.editorIndex then
		local macro = MV:GetMacro(self.editorIndex)
		self.editorHeader:SetText(("Editing  %s  -  slot %d"):format(macro and macro.name or "?", self.editorIndex))
	else
		self.editorHeader:SetText("New macro")
	end
end

function UI:UpdateEditorScope()
	if not self.scopeButtons then return end

	local isChar = self.editorScope == "char"
	self.scopeButtons.account:SetActive(not isChar)
	self.scopeButtons.char:SetActive(isChar)
	self.scopeNote:SetText(self.editorIndex
		and "scope is fixed once a macro exists"
		or "choose where new macros live")
end

function UI:SetEditorScope(scope)
	if self.editorIndex then
		self:SetStatus("Scope can't change on an existing macro - duplicate it instead.", true)
		return
	end
	self.editorScope = scope
	self:UpdateEditorScope()
end

function UI:LoadEditor(index, template)
	if index then
		local macro = MV:GetMacro(index)
		if not macro then
			self:SetStatus("That macro no longer exists.", true)
			return
		end
		template = macro
		self.editorIndex = index
		self.editorScope = macro.scope
	else
		self.editorIndex = nil
		if template then
			self.editorScope = template.scope or "account"
		else
			self.editorScope = (MacroVaultDB and MacroVaultDB.perCharacter) and "char" or "account"
		end
	end

	local name = template and template.name or ""
	if #name > MV.MAX_NAME then name = name:sub(1, MV.MAX_NAME) end
	local body = template and template.body or ""
	local icon = template and template.icon or 134400

	self.editorName:SetText(name)
	self.editorIcon:SetText(tostring(icon))
	self.editorBody:SetText(body)
	self.editorBody:SetCursorPosition(0)

	self:UpdateEditorHeader()
	self:UpdateEditorScope()
	self:SwitchTab("editor")
end

function UI:NewEditor()
	self:LoadEditor(nil, nil)
	self:SetStatus("New macro.")
end

function UI:SaveEditor()
	local name = self.editorName:GetText() or ""
	local body = self.editorBody:GetText() or ""
	local iconText = MV.trim(self.editorIcon:GetText())
	local icon = tonumber(iconText) or iconText
	if icon == "" then icon = 134400 end

	local editing = self.editorIndex ~= nil
	local index, err
	if editing then
		index, err = MV:UpdateMacro(self.editorIndex, name, body, icon)
	else
		index, err = MV:CreateMacro(name, body, icon, self.editorScope == "char")
	end

	if not index then
		self:SetStatus(err or "Could not save the macro.", true)
		return
	end

	self.editorIndex = index
	self.selectedMacroIndex = index

	local macro = MV:GetMacro(index)
	self:SetStatus(("%s '%s' in slot %d."):format(
		editing and "Saved" or "Created",
		macro and macro.name or name,
		index
	))

	self:UpdateEditorHeader()
	self:UpdateEditorScope()
	self:RefreshMacros()
	self:ShowMacroDetail(MV:GetMacro(index))
end

function UI:PickupEditor()
	if not self.editorIndex then
		self:SetStatus("Save the macro first, then pick it up.", true)
		return
	end

	local ok, err = MV:Pickup(self.editorIndex)
	if not ok then
		self:SetStatus(err or "Could not pick up that macro.", true)
		return
	end

	self:SetStatus("Macro on your cursor - drop it on an action bar.")
	self.frame:Hide()
end
