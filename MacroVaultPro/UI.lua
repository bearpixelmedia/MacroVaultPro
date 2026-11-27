-- MacroVaultPro - the window: macro browser, tool palette, library and editor
local ADDON_NAME, MV = ...
MV = MV or _G.MacroVaultPro or {}

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
		-- A press starts a possible drag; the tracker decides when the pointer has
		-- actually moved. Waiting for OnDragStart leaves the row dead on a client
		-- that does not raise it for a plain Button.
		row:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" and list.onDrag then list.onDrag(self.item) end
		end)

		-- OnDragStart/OnDragStop are the client's own drag events. They are wired
		-- alongside the press tracker so the row drags on either path; both end
		-- in the same drop, which ignores a drag that is already finished.
		row:RegisterForDrag("LeftButton")
		row:SetScript("OnDragStart", function(self)
			if self.item and list.onDragStart then list.onDragStart(self.item) end
		end)
		row:SetScript("OnDragStop", function()
			UI:DropDrag()
		end)

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

	function list:SetItems(items, render, onSelect, onDrag, onDragStart)
		self.items = items
		self.render = render
		self.onSelect = onSelect
		self.onDrag = onDrag
		self.onDragStart = onDragStart

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
		self.libraryScope = (MacroVaultProDB and MacroVaultProDB.perCharacter) and "char" or "account"
	end
	if not self.editorScope then
		self.editorScope = (MacroVaultProDB and MacroVaultProDB.perCharacter) and "char" or "account"
	end

	local frame = CreateFrame("Frame", "MacroVaultProFrame", UIParent)
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

	tinsert(UISpecialFrames, "MacroVaultProFrame")
	self:ApplyPosition()

	local title = Text(frame, 19, ACCENT)
	title:SetPoint("TOPLEFT", 16, -12)
	title:SetText("MacroVaultPro")

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
		{ id = "maker",   label = "Maker" },
		{ id = "tools",   label = "Tools" },
		{ id = "library", label = "Library" },
		{ id = "editor",  label = "Editor" },
		{ id = "sheet",   label = "Sheet" },
	}
	local x = 14
	for _, tab in ipairs(tabs) do
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(88, 24)
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
		x = x + 92
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
	for _, id in ipairs({ "macros", "maker", "tools", "library", "editor", "sheet" }) do
		local panel = CreateFrame("Frame", nil, frame)
		panel:SetPoint("TOPLEFT", 12, -82)
		panel:SetPoint("BOTTOMRIGHT", -12, 34)
		panel:Hide()
		self.panels[id] = panel
	end

	self:BuildMacrosPanel(self.panels.macros)
	-- Guarded like the tab's own work: a mistake building one panel must not leave
	-- the window half-built, because Build() never runs a second time.
	local madeMaker, makerError = pcall(self.BuildMakerPanel, self, self.panels.maker)
	if not madeMaker then
		self.makerBroken = tostring(makerError)
		MV:LogError("maker panel: " .. tostring(makerError))
	end
	self:BuildToolsPanel(self.panels.tools)
	self:BuildLibraryPanel(self.panels.library)
	self:BuildEditorPanel(self.panels.editor)
	self:BuildSheetPanel(self.panels.sheet)

	local status = Text(frame, 11, MUTED)
	status:SetPoint("BOTTOMLEFT", 14, 13)
	status:SetWidth(640)
	self.status = status

	local footer = Text(frame, 10, MUTED, "RIGHT")
	footer:SetPoint("BOTTOMRIGHT", -14, 13)
	footer:SetText("Forever - /mvpro")

	self:SwitchTab((MacroVaultProDB and MacroVaultProDB.tab) or "macros")
end

function UI:ApplyPosition()
	local frame = self.frame
	if not frame then return end

	local position = MacroVaultProDB and MacroVaultProDB.position
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

-------------------------------------------------------------------------------
-- Error log window: read-only text, Copy selects it for Ctrl+C
-------------------------------------------------------------------------------

local ERROR_WIDTH, ERROR_HEIGHT = 470, 380

function UI:BuildErrorWindow()
	if self.errorFrame then return self.errorFrame end

	local frame = CreateFrame("Frame", "MacroVaultProErrorsFrame", UIParent)
	frame:SetSize(ERROR_WIDTH, ERROR_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	frame:Hide()

	Paint(frame, 0.045, 0.045, 0.06, 0.97)
	Border(frame, 0.30, 0.25, 0.45, 1)
	if type(UISpecialFrames) == "table" then
		tinsert(UISpecialFrames, "MacroVaultProErrorsFrame")
	end

	local title = Text(frame, 16, ACCENT)
	title:SetPoint("TOPLEFT", 14, -10)
	title:SetText("Error log")

	local summary = Text(frame, 11, MUTED)
	summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -3)
	summary:SetWidth(340)
	summary:SetText("")

	local close = self:MakeButton(frame, "X", 24, function() frame:Hide() end)
	close:SetPoint("TOPRIGHT", -8, -8)

	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", 6, -46)
	body:SetPoint("BOTTOMRIGHT", -6, 46)
	local _, bodyText, setBody = CreateBodyView(body)

	local copy = self:MakeButton(frame, "Copy", 84, function() self:CopyErrorLog() end)
	copy:SetPoint("BOTTOMLEFT", 12, 12)

	local clear = self:MakeButton(frame, "Clear log", 92, function() MV:ClearErrors() end)
	clear:SetPoint("LEFT", copy, "RIGHT", 8, 0)

	local hint = Text(frame, 10, MUTED)
	hint:SetPoint("LEFT", clear, "RIGHT", 10, 0)
	hint:SetWidth(190)
	hint:SetText("Copy selects the log - Ctrl+C")

	local done = self:MakeButton(frame, "Close", 76, function() frame:Hide() end)
	done:SetPoint("BOTTOMRIGHT", -12, 12)

	-- There is no clipboard API, so Copy puts the whole log in this focusable box
	-- and selects it; the player's Ctrl+C then copies the selection. The visible
	-- text above stays a FontString, so the window really is read-only.
	local box = CreateFrame("EditBox", nil, frame)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFont(FONT, 12, "")
	box:SetTextInsets(0, 0, 0, 0)
	box:SetSize(1, 1)
	box:SetPoint("BOTTOMLEFT", 10, 10)
	box:SetAlpha(0)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	frame:SetScript("OnHide", function()
		box:ClearFocus()
	end)

	self.errorFrame = frame
	self.errorSetText = setBody
	self.errorBodyText = bodyText
	self.errorSummary = summary
	self.errorHint = hint
	self.errorBox = box
	return frame
end

function UI:ShowErrorLog(text, summary)
	local frame = self:BuildErrorWindow()
	self.errorText = tostring(text or "")
	self.errorSummary:SetText(tostring(summary or ""))
	self.errorHint:SetText("Copy selects the log - Ctrl+C")
	self.errorBox:ClearFocus()
	self.errorSetText(self.errorText)
	frame:Show()
	frame:Raise()
end

function UI:CopyErrorLog()
	local box = self.errorBox
	if not box then return end
	box:SetText(self.errorText or "")
	box:SetFocus()
	box:HighlightText()
	self.errorHint:SetText("Selected - press Ctrl+C to copy")
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
	if MacroVaultProDB then MacroVaultProDB.tab = id end

	self:Refresh()
end

function UI:SearchTerm()
	local box = self.search
	if not box or not box:IsShown() then return "" end
	return (box:GetText() or ""):lower()
end

function UI:Refresh()
	if not self.frame then return end

	-- Macros come and go, so the sheet's own name lookup is rebuilt per refresh.
	self.sheetMacroMap = nil

	if self.activeTab == "macros" then
		self:RefreshMacros()
	elseif self.activeTab == "maker" then
		self:MakerRun("refresh", self.RefreshMaker)
	elseif self.activeTab == "library" then
		self:RefreshLibrary()
	elseif self.activeTab == "sheet" then
		self:RefreshSheet()
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
		function(item) self:SelectMacro(item.index) end,
		function(item) self:PressDrag({ macro = item }) end,
		function(item) self:BeginDrag({ macro = item }, "client") end
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
	intro:SetText("Runs the client's own UI and debug tools - /fstack included. The slash commands behave exactly as if you typed them; " ..
		"combat actions live in the Library as macros.")

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
		detail:SetText(tool.detail or tool.cmd or "open")
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
	if MacroVaultProDB then
		MacroVaultProDB.perCharacter = self.libraryScope == "char"
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
			self.editorScope = (MacroVaultProDB and MacroVaultProDB.perCharacter) and "char" or "account"
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

-------------------------------------------------------------------------------
-- Sheet: macros dropped into icon slots, arranged, and saved as you go
--
-- Slots remember a macro by name and scope, never by slot index: the client
-- renumbers macros whenever one is deleted, so an index would point at the
-- wrong macro a week later.
-------------------------------------------------------------------------------

local SHEET_COLUMNS = 6
local SHEET_ROWS    = 6
local SHEET_SLOTS   = SHEET_COLUMNS * SHEET_ROWS
local SHEET_ICON    = 48
local SHEET_GAP     = 6

local function sheetKey(entry)
	return tostring(entry.scope or "account") .. "|" .. tostring(entry.name or "")
end

function UI:GetSheet()
	if not self.sheet then
		self.sheet = {}
		local saved = MacroVaultProDB and MacroVaultProDB.sheet
		if type(saved) == "table" then
			for position = 1, SHEET_SLOTS do
				local entry = saved[position]
				if type(entry) == "table" and entry.name then
					self.sheet[position] = {
						name  = tostring(entry.name),
						scope = entry.scope == "char" and "char" or "account",
					}
				end
			end
		end
	end
	return self.sheet
end

function UI:SheetCount()
	local count = 0
	for _ in pairs(self:GetSheet()) do count = count + 1 end
	return count
end

function UI:SaveSheet()
	local saved = {}
	for position, entry in pairs(self:GetSheet()) do
		saved[position] = { name = entry.name, scope = entry.scope }
	end
	MacroVaultProDB = MacroVaultProDB or {}
	MacroVaultProDB.sheet = saved
end

-- One level of undo for the two destructive things this tab does: clearing a
-- slot and moving a macro between slots. The snapshot is a plain copy, so what
-- gets restored cannot be changed by anything that happens after it is taken.
function UI:CopySheet()
	local copy = {}
	for position, entry in pairs(self:GetSheet()) do
		copy[position] = { name = entry.name, scope = entry.scope }
	end
	return copy
end

function UI:SnapshotSheet(label)
	self.sheetUndo = { entries = self:CopySheet(), label = label }
end

function UI:UndoSheet()
	local undo = self.sheetUndo
	if not undo then
		self:SetStatus("Nothing to undo.")
		return false
	end

	self.sheet = undo.entries
	self.sheetUndo = nil
	self:SaveSheet()
	self:RefreshSheet()
	self:RefreshUndoButton()
	self:SetStatus(("Undid %s."):format(undo.label))
	return true
end

function UI:RefreshUndoButton()
	local button = self.undoButton
	if not button then return end
	button:SetAlpha(self.sheetUndo and 1 or 0.4)
end

function UI:SheetMap()
	if not self.sheetMacroMap then
		local map = {}
		for _, macro in ipairs(MV:GetMacros()) do
			local key = sheetKey(macro)
			if not map[key] then map[key] = macro end
		end
		self.sheetMacroMap = map
	end
	return self.sheetMacroMap
end

function UI:SheetMacroAt(position)
	local entry = self:GetSheet()[position]
	if not entry then return nil end
	return self:SheetMap()[sheetKey(entry)]
end

function UI:UpdateSlotBorder(slot)
	if not self:GetSheet()[slot.sheetSlot] then
		SetBorderColor(slot, 0.20, 0.18, 0.28, 1)
	elseif self:SheetMacroAt(slot.sheetSlot) then
		SetBorderColor(slot, 0.26, 0.23, 0.36, 1)
	else
		-- The macro behind this slot is gone; say so with the border.
		SetBorderColor(slot, 0.72, 0.30, 0.30, 1)
	end
end

function UI:RefreshSheet()
	if not self.sheetSlots then return end

	if self.sheetList then
		local items = {}
		for _, macro in ipairs(MV:GetMacros()) do
			items[#items + 1] = macro
		end
		table.sort(items, function(a, b)
			if a.scope ~= b.scope then
				return a.scope == "char"
			end
			return a.name:lower() < b.name:lower()
		end)

		self.sheetList:SetItems(
			items,
			function(row, item) self:RenderMacroRow(row, item) end,
			function(item) self:SelectMacro(item.index) end,
			function(item) self:PressDrag({ macro = item }) end,
			function(item) self:BeginDrag({ macro = item }, "client") end
		)
		self.sheetList:SetSelected(self.selectedMacroIndex)

		if self.sheetListHeader then
			self.sheetListHeader:SetText(("DRAG FROM HERE  %d"):format(#items))
		end
	end

	for _, slot in ipairs(self.sheetSlots) do
		local entry = self:GetSheet()[slot.sheetSlot]
		local macro = entry and self:SheetMacroAt(slot.sheetSlot)

		slot.icon:SetVertexColor(1, 1, 1)
		if macro then
			slot.icon:SetTexture(macro.icon or 134400)
			slot.icon:Show()
			slot.plus:Hide()
		elseif entry then
			slot.icon:SetTexture(134400)
			slot.icon:SetVertexColor(0.55, 0.45, 0.45)
			slot.icon:Show()
			slot.plus:Hide()
		else
			slot.icon:Hide()
			slot.plus:Show()
		end
		slot.macro = macro
		self:UpdateSlotBorder(slot)
	end

	if self.sheetHeader then
		self.sheetHeader:SetText(("MACRO SHEET  %d/%d"):format(self:SheetCount(), SHEET_SLOTS))
	end

	self:RefreshUndoButton()
end

function UI:ClearSheetSlot(position)
	local sheet = self:GetSheet()
	local entry = sheet[position]
	if not entry then return end

	self:SnapshotSheet(("clearing slot %d - %s"):format(position, entry.name))
	sheet[position] = nil
	self:SaveSheet()
	self:RefreshSheet()
	self:SetStatus(("Cleared slot %d - %s. Undo is in this tab."):format(position, entry.name))
end

function UI:BuildDragGhost()
	local ghost = CreateFrame("Frame", nil, UIParent)
	ghost:SetSize(SHEET_ICON, SHEET_ICON)
	ghost:SetFrameStrata("TOOLTIP")
	ghost:EnableMouse(false)

	ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
	ghost.icon:SetAllPoints(ghost)
	ghost.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	Border(ghost, ACCENT[1], ACCENT[2], ACCENT[3], 0.9)

	ghost:Hide()
	self.dragGhost = ghost
	return ghost
end

-- Drags are tracked from the mouse button rather than from OnDragStart: press,
-- watch the pointer, and drop on release. This starts on the first pixel of
-- movement and does not rely on the client raising a drag event for the frame.
function UI:PressDrag(payload)
	-- A list row drags a macro, a maker row drags its own icon and position.
	if type(payload) ~= "table" then return end

	local x, y = GetCursorPosition()
	self.pressDrag = { payload = payload, x = x or 0, y = y or 0 }
	self:TrackDrag()
end

function UI:TrackDrag()
	local tracker = self.dragTracker
	if not tracker then
		tracker = CreateFrame("Frame", nil, UIParent)
		tracker:SetSize(1, 1)
		tracker:SetPoint("TOPLEFT")
		tracker:SetScript("OnUpdate", function() UI:DragTick() end)
		self.dragTracker = tracker
	end
	tracker:Show()
end

function UI:StopDragTracking()
	if self.dragTracker then self.dragTracker:Hide() end
end

function UI:DragTick()
	local press = self.pressDrag
	local x, y = GetCursorPosition()

	if press and not self.drag then
		if x and y and (math.abs(x - press.x) + math.abs(y - press.y)) >= 6 then
			self.pressDrag = nil
			self:BeginDrag(press.payload, "press")
		end
	end

	if self.drag then
		self:MoveDragGhost()
	end

	-- Only the clients that report the button state can be dropped here; where
	-- the global is missing, OnDragStop is what ends the drag.
	if type(IsMouseButtonDown) == "function" and not IsMouseButtonDown("LeftButton") then
		self.pressDrag = nil
		if self.drag then self:DropDrag() end
		self:StopDragTracking()
	end
end

function UI:MoveDragGhost()
	local ghost = self.dragGhost
	if not ghost or not ghost:IsShown() then return end

	local root = self.frame or UIParent
	if not root or not root.GetEffectiveScale then return end
	local scale = root:GetEffectiveScale()
	if not scale or scale == 0 then return end

	local x, y = GetCursorPosition()
	if not x or not y then return end

	ghost:ClearAllPoints()
	ghost:SetPoint("CENTER", root, "BOTTOMLEFT", x / scale, y / scale)
end

-- Starts a drag. The payload is { macro = <macro> } from a list row, with
-- slot = <position> when the drag started on the sheet, or { icon = ...,
-- makerAdd/makerStep = ... } from the maker, which carries its icon rather than
-- a stand-in macro.
function UI:BeginDrag(payload, source)
	if type(payload) ~= "table" then return end
	if self.drag then return end
	if source then MV:CountDrag(source) end

	local ghost = self.dragGhost or self:BuildDragGhost()
	ghost.icon:SetTexture(payload.icon or (payload.macro and payload.macro.icon) or 134400)
	ghost:Show()

	self.pressDrag = nil
	self.drag = payload
	-- An OnDragStart drag can begin without the press tracker running, so make
	-- sure the ghost is being moved and the release is watched either way.
	self:TrackDrag()
	GameTooltip:Hide()
	if self.sheetSlots then
		self:RefreshSheet()
	end
end

-- The slot under the pointer, worked out from the slot rectangles. The frame
-- under the cursor is not a dependable answer once a mouse button is held.
function UI:SlotAtCursor()
	local slots = self.sheetSlots
	if not slots then return nil end

	local root = self.frame or UIParent
	if not root or not root.GetEffectiveScale then return nil end
	local scale = root:GetEffectiveScale()
	if not scale or scale == 0 then return nil end

	local x, y = GetCursorPosition()
	if not x or not y then return nil end
	x, y = x / scale, y / scale

	for _, slot in ipairs(slots) do
		local left, bottom = slot:GetLeft(), slot:GetBottom()
		local right, top = slot:GetRight(), slot:GetTop()
		if left and bottom and right and top
			and x >= left and x <= right and y >= bottom and y <= top then
			return slot.sheetSlot
		end
	end
	return nil
end

function UI:DropDrag()
	local ghost = self.dragGhost
	if ghost then ghost:Hide() end
	self:StopDragTracking()
	self.pressDrag = nil

	local drag = self.drag
	self.drag = nil
	if not drag then return end

	-- The maker's own payloads - a macro being added to the sequence, or a step
	-- being moved inside it - belong to the sequence, never to the sheet.
	if drag.makerAdd or drag.makerStep then
		self:MakerRun("drop", self.MakerDrop, drag)
		return
	end

	local target = self:SlotAtCursor()
	if not target then
		local focus = GetMouseFocus and GetMouseFocus()
		target = focus and focus.sheetSlot
	end
	if not target then
		self:RefreshSheet()
		return
	end

	MV:CountDrag("drops")
	self:DropOnSlot(target, drag)
end

function UI:DropOnSlot(target, drag)
	if type(target) ~= "number" or target < 1 or target > SHEET_SLOTS then return end

	local sheet = self:GetSheet()
	local before = self:CopySheet()
	local moved = false

	if drag.slot then
		if drag.slot ~= target then
			sheet[drag.slot], sheet[target] = sheet[target], sheet[drag.slot]
			moved = true
		end
	else
		-- One macro, one slot: take it out of wherever it already sat.
		local key = sheetKey(drag.macro)
		for position, entry in pairs(sheet) do
			if position ~= target and sheetKey(entry) == key then
				sheet[position] = nil
				break
			end
		end
		sheet[target] = { name = drag.macro.name, scope = drag.macro.scope }
		moved = true
	end

	if not moved then return end

	self.sheetUndo = {
		entries = before,
		label = drag.slot
			and ("moving slot %d to slot %d"):format(drag.slot, target)
			or ("placing %s in slot %d"):format(drag.macro.name, target),
	}

	self:SaveSheet()
	self:RefreshSheet()
	self:SetStatus(("Sheet saved - slot %d. Undo is in this tab."):format(target))
end

function UI:BuildSheetPanel(panel)
	local ui = self

	-- The list and the slots share the tab on purpose: a drag has to start and
	-- finish on two things the player can see at the same time.
	local listPane = CreateFrame("Frame", nil, panel)
	listPane:SetPoint("TOPLEFT")
	listPane:SetPoint("BOTTOMLEFT")
	listPane:SetWidth(344)
	Paint(listPane, 0.055, 0.055, 0.075, 0.9)

	local listHeader = Text(listPane, 10, MUTED)
	listHeader:SetPoint("TOPLEFT", 10, -9)
	listHeader:SetText("DRAG FROM HERE")
	self.sheetListHeader = listHeader

	local inner = CreateFrame("Frame", nil, listPane)
	inner:SetPoint("TOPLEFT", 4, -24)
	inner:SetPoint("BOTTOMRIGHT", -4, 4)

	self.sheetList = self:CreateList(inner)
	self.sheetList:SetEmptyText("No macros to drag yet.")

	local sheetPane = CreateFrame("Frame", nil, panel)
	sheetPane:SetPoint("TOPLEFT", listPane, "TOPRIGHT", 12, 0)
	sheetPane:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	Paint(sheetPane, 0.055, 0.055, 0.075, 0.9)

	local header = Text(sheetPane, 10, MUTED)
	header:SetPoint("TOPLEFT", 12, -9)
	header:SetText(("MACRO SHEET  0/%d"):format(SHEET_SLOTS))
	self.sheetHeader = header

	local hint = Text(sheetPane, 10, MUTED)
	hint:SetPoint("TOPLEFT", 12, -26)
	hint:SetWidth(310)
	hint:SetText("Drag a macro here, drag a slot onto another to reorder, right-click a slot to clear it.")

	local grid = CreateFrame("Frame", nil, sheetPane)
	grid:SetPoint("TOPLEFT", 12, -64)
	grid:SetSize(SHEET_COLUMNS * (SHEET_ICON + SHEET_GAP), SHEET_ROWS * (SHEET_ICON + SHEET_GAP))

	self.sheetSlots = {}
	for position = 1, SHEET_SLOTS do
		local column = (position - 1) % SHEET_COLUMNS
		local line   = math.floor((position - 1) / SHEET_COLUMNS)

		local slot = CreateFrame("Button", nil, grid)
		slot:SetSize(SHEET_ICON, SHEET_ICON)
		slot:SetPoint("TOPLEFT", column * (SHEET_ICON + SHEET_GAP), -line * (SHEET_ICON + SHEET_GAP))
		slot:EnableMouse(true)
		slot.sheetSlot = position

		slot.bg = slot:CreateTexture(nil, "BACKGROUND")
		slot.bg:SetAllPoints(slot)
		slot.bg:SetColorTexture(0.09, 0.085, 0.12, 1)

		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetPoint("TOPLEFT", 1, -1)
		slot.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		slot.icon:Hide()

		Border(slot, 0.20, 0.18, 0.28, 1)

		slot.plus = Text(slot, 15, { 0.30, 0.28, 0.40 }, "CENTER")
		slot.plus:SetPoint("CENTER", 0, 0)
		slot.plus:SetText("+")

		slot:SetScript("OnMouseDown", function(self, button)
			if button ~= "LeftButton" then return end
			local macro = ui:SheetMacroAt(self.sheetSlot)
			if macro then
				ui:PressDrag({ macro = macro, slot = self.sheetSlot })
			end
		end)

		-- The client's own drag events, wired next to the press tracker so a slot
		-- drags whichever of the two the client raises.
		slot:RegisterForDrag("LeftButton")
		slot:SetScript("OnDragStart", function(self)
			local macro = ui:SheetMacroAt(self.sheetSlot)
			if macro then
				ui:BeginDrag({ macro = macro, slot = self.sheetSlot }, "client")
			end
		end)
		slot:SetScript("OnDragStop", function()
			ui:DropDrag()
		end)

		slot:SetScript("OnEnter", function(self)
			local macro = ui:SheetMacroAt(self.sheetSlot)
			local entry = ui:GetSheet()[self.sheetSlot]

			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if macro then
				GameTooltip:SetText(macro.name, 1, 1, 1, 1, true)
				GameTooltip:AddLine(("%s macro  -  slot %d"):format(
					macro.scope == "char" and "Character" or "Account", macro.index), 0.82, 0.82, 0.88, true)
				GameTooltip:AddLine(macro.body, 0.72, 0.70, 0.80, true)
				GameTooltip:AddLine("Click to select it in My macros; right-click to clear this slot.", 0.55, 0.55, 0.63, true)
			elseif entry then
				GameTooltip:SetText(entry.name, 1, 0.5, 0.45)
				GameTooltip:AddLine("That macro has been renamed or deleted. Right-click to clear the slot.", 0.82, 0.82, 0.88, true)
			else
				GameTooltip:SetText("Empty slot", 1, 1, 1)
				GameTooltip:AddLine("Drag a macro here from My macros.", 0.72, 0.70, 0.80, true)
			end

			if ui.drag then
				SetBorderColor(self, ACCENT[1], ACCENT[2], ACCENT[3], 1)
			end
			GameTooltip:Show()
		end)

		slot:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
			ui:UpdateSlotBorder(self)
		end)

		slot:SetScript("OnClick", function(self, button)
			if button == "RightButton" then
				ui:ClearSheetSlot(self.sheetSlot)
				return
			end
			local macro = ui:SheetMacroAt(self.sheetSlot)
			if macro then
				ui.selectedMacroIndex = macro.index
				ui:SetStatus(("Selected %s - open My macros to work on it."):format(macro.name))
			end
		end)

		self.sheetSlots[position] = slot
	end

	local save = ui:MakeButton(sheetPane, "Save layout", 110, function()
		ui:SaveSheet()
		ui:RefreshSheet()
		ui:SetStatus(("Sheet saved - %d of %d slots filled."):format(ui:SheetCount(), SHEET_SLOTS))
	end)
	save:SetPoint("BOTTOMLEFT", 12, 10)

	-- One level back from the last clear or move. Dimmed rather than disabled, so
	-- it still explains itself when there is nothing to undo.
	local undo = ui:MakeButton(sheetPane, "Undo", 70, function()
		ui:UndoSheet()
	end)
	undo:SetPoint("BOTTOMLEFT", save, "BOTTOMRIGHT", 8, 0)
	undo:SetAlpha(0.4)
	undo:SetScript("OnEnter", function(self)
		local label = ui.sheetUndo and ui.sheetUndo.label
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Undo", 1, 1, 1)
		GameTooltip:AddLine(label and ("Undo %s."):format(label) or "Nothing to undo yet.",
			0.82, 0.82, 0.88, true)
		GameTooltip:Show()
	end)
	undo:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	ui.undoButton = undo
end

-------------------------------------------------------------------------------
-- Maker: spells and macros dropped into one ordered sequence
--
-- The sequence is not a new kind of macro - the client cannot run one macro from
-- inside another. It is copied into a single body in order, which is why the tab
-- shows the exact text and the character count while it is being built, and why
-- "Drag to bar" hands over the macro it just wrote.
-------------------------------------------------------------------------------

local MAKER_ROW_HEIGHT = 26
local MAKER_ICON_SIZE  = 24

-- The maker is the most mechanical tab here: it reads a client API's answer and
-- rebuilds frames under the cursor. Everything the rest of the window shares with
-- it - opening the window, switching to the tab, finishing a drag, pressing a
-- button - goes through this, so a mistake in this tab becomes a status line and
-- an entry in /mvpro errors instead of an error that keeps the window from
-- opening or a drop from finishing.
function UI:MakerRun(what, fn, ...)
	local ok, err = pcall(fn, self, ...)
	if not ok then
		self:SetStatus(("Maker %s failed - %s"):format(what, tostring(err)), true)
		MV:LogError(("maker %s: %s"):format(what, tostring(err)))
	end
	return ok
end

local function makerStepLabel(step)
	if step.kind == "spell" then
		return ("Cast %s"):format(step.value)
	end
	return ("Macro  %s"):format(step.value)
end

function UI:BuildMakerPanel(panel)
	local ui = self

	-- Left: the macros that can be nested into the sequence.
	local listPane = CreateFrame("Frame", nil, panel)
	listPane:SetPoint("TOPLEFT")
	listPane:SetPoint("BOTTOMLEFT")
	listPane:SetWidth(300)
	Paint(listPane, 0.055, 0.055, 0.075, 0.9)

	local listHeader = Text(listPane, 10, MUTED)
	listHeader:SetPoint("TOPLEFT", 10, -9)
	listHeader:SetText("YOUR MACROS")
	self.makerListHeader = listHeader

	local listHint = Text(listPane, 10, MUTED)
	listHint:SetPoint("TOPLEFT", 10, -24)
	listHint:SetWidth(276)
	listHint:SetText("Click one to add it, or drag it into the sequence on the right.")

	local inner = CreateFrame("Frame", nil, listPane)
	inner:SetPoint("TOPLEFT", 4, -56)
	inner:SetPoint("BOTTOMRIGHT", -4, 4)

	self.makerList = self:CreateList(inner)
	self.makerList:SetEmptyText("No macros yet - the Editor tab makes them.")

	local pane = CreateFrame("Frame", nil, panel)
	pane:SetPoint("TOPLEFT", listPane, "TOPRIGHT", 12, 0)
	pane:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	Paint(pane, 0.055, 0.055, 0.075, 0.9)

	local title = Text(pane, 10, MUTED)
	title:SetPoint("TOPLEFT", 12, -9)
	title:SetText("MACRO MAKER  -  the steps run in the order below")

	-- A spell dragged out of the spellbook is never delivered to a frame, so the
	-- release is read from the cursor here.
	local drop = CreateFrame("Frame", nil, pane)
	drop:SetPoint("TOPLEFT", 12, -24)
	drop:SetPoint("TOPRIGHT", -12, -24)
	drop:SetHeight(28)
	drop:EnableMouse(true)
	Paint(drop, 0.09, 0.085, 0.12, 1)
	Border(drop, 0.24, 0.21, 0.34, 1)

	local dropText = Text(drop, 10, MUTED, "CENTER")
	dropText:SetPoint("CENTER", 0, 0)
	dropText:SetWidth(420)
	dropText:SetText("Drop a spell from your spellbook here, or click a macro on the left")

	drop:SetScript("OnMouseUp", function() ui:MakerRun("add from cursor", ui.MakerTakeCursor) end)
	drop:SetScript("OnEnter", function() SetBorderColor(drop, ACCENT[1], ACCENT[2], ACCENT[3], 1) end)
	drop:SetScript("OnLeave", function() SetBorderColor(drop, 0.24, 0.21, 0.34, 1) end)

	local nameLabel = Text(pane, 10, MUTED)
	nameLabel:SetPoint("TOPLEFT", 12, -62)
	nameLabel:SetText("NAME")

	local name = ui:MakeEditBox(pane, 150, 24)
	name:SetPoint("TOPLEFT", 52, -58)
	name:SetMaxLetters(MV.MAX_NAME)
	name:SetScript("OnTextChanged", function(self)
		if ui.makerSettingName then return end
		local maker = MV:GetMaker()
		maker.name = self:GetText() or ""
		MV:SaveMaker()
	end)
	self.makerName = name

	local scope = ui:MakeButton(pane, "Create on: account", 156, function() ui:MakerRun("scope", ui.ToggleMakerScope) end)
	scope:SetPoint("LEFT", name, "RIGHT", 8, 0)
	self.makerScopeButton = scope

	local iconLabel = Text(pane, 10, MUTED)
	iconLabel:SetPoint("TOPLEFT", 12, -94)
	iconLabel:SetText("ICON")

	local iconRow = CreateFrame("Frame", nil, pane)
	iconRow:SetPoint("TOPLEFT", 52, -88)
	iconRow:SetSize(420, MAKER_ICON_SIZE)
	self.makerIconRow = iconRow
	self.makerIconButtons = {}

	local seqLabel = Text(pane, 10, MUTED)
	seqLabel:SetPoint("TOPLEFT", 12, -120)
	seqLabel:SetText("SEQUENCE")
	self.makerSeqLabel = seqLabel

	local counter = Text(pane, 10, MUTED, "RIGHT")
	counter:SetPoint("TOPRIGHT", -12, -120)
	counter:SetText("0 / " .. MV.MAX_BODY)
	self.makerCounter = counter
	counter:SetScript("OnEnter", function(self)
		local problems = ui.makerProblems
		if not problems or #problems == 0 then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("This sequence needs attention", 1, 0.6, 0.5)
		for _, line in ipairs(problems) do
			GameTooltip:AddLine(line, 0.82, 0.82, 0.88, true)
		end
		GameTooltip:Show()
	end)
	counter:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local scroll = CreateFrame("ScrollFrame", nil, pane)
	scroll:SetPoint("TOPLEFT", 12, -136)
	scroll:SetPoint("BOTTOMRIGHT", -12, 128)
	scroll:EnableMouseWheel(true)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(10, 10)
	scroll:SetScrollChild(child)
	child:EnableMouseWheel(true)
	self.makerStepScroll, self.makerStepChild = scroll, child

	local function scrollBy(_, delta)
		local maxScroll = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
		local value = scroll:GetVerticalScroll() - (delta or 0) * MAKER_ROW_HEIGHT
		scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, value)))
	end
	scroll:SetScript("OnMouseWheel", scrollBy)
	child:SetScript("OnMouseWheel", scrollBy)
	scroll:SetScript("OnSizeChanged", function(_, width)
		child:SetWidth(math.max(width or 10, 10))
	end)

	-- A spell released anywhere over the sequence works too, not only on the bar.
	-- A plain click here is not an add attempt, though: with an empty cursor it is
	-- just a click, and it must not report an error.
	local function addFromCursor()
		if ui:CursorHoldsSomething() then
			ui:MakerRun("add from cursor", ui.MakerTakeCursor)
		end
	end
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseUp", addFromCursor)
	child:SetScript("OnMouseUp", addFromCursor)

	local empty = Text(pane, 11, MUTED, "CENTER")
	empty:SetPoint("TOP", scroll, "TOP", 0, -40)
	empty:SetWidth(360)
	empty:SetText("Empty sequence - drop a spell above, or click a macro on the left.")
	self.makerEmpty = empty

	-- With no macros at all the pane on the left is empty, so the empty state
	-- carries the one button that gets out of it.
	local makeOne = ui:MakeButton(pane, "Make a macro", 120, function() ui:MakerRun("new macro", ui.NewEditor) end)
	makeOne:SetPoint("TOP", scroll, "TOP", 0, -88)
	self.makerMakeButton = makeOne

	local previewLabel = Text(pane, 10, MUTED)
	previewLabel:SetPoint("BOTTOMLEFT", 12, 112)
	previewLabel:SetText("MACRO TEXT")

	local previewBox = CreateFrame("Frame", nil, pane)
	previewBox:SetPoint("BOTTOMLEFT", 12, 44)
	previewBox:SetPoint("BOTTOMRIGHT", -12, 44)
	previewBox:SetHeight(64)
	Paint(previewBox, 0.02, 0.02, 0.03, 0.9)
	Border(previewBox, 0.16, 0.15, 0.22, 1)
	self.makerBodySet = select(3, CreateBodyView(previewBox))

	local build = ui:MakeButton(pane, "Build macro", 106, function() ui:MakerRun("build", ui.BuildMaker) end)
	build:SetPoint("BOTTOMLEFT", 12, 12)
	build:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Builds the macro from these steps", 1, 1, 1)
		GameTooltip:AddLine("It updates the same macro every time, so a bar button you already have keeps working.",
			0.72, 0.70, 0.80, true)
		GameTooltip:Show()
	end)
	build:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local pickup = ui:MakeButton(pane, "Drag to bar", 100, function() ui:MakerRun("pickup", ui.PickupMaker) end)
	pickup:SetPoint("LEFT", build, "RIGHT", 8, 0)

	local clear = ui:MakeButton(pane, "Clear steps", 92, function() ui:MakerRun("clear", ui.ClearMaker) end)
	clear:SetPoint("LEFT", pickup, "RIGHT", 8, 0)

end

function UI:RefreshMaker()
	if not self.makerStepChild then
		-- The panel failed to build; say so instead of showing a blank tab.
		if self.makerBroken then
			self:SetStatus(("Maker tab unavailable - %s"):format(self.makerBroken), true)
		end
		return
	end

	local maker = MV:GetMaker()

	if self.makerList then
		local items = MV:GetMacros()
		table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)

		self.makerList:SetItems(
			items,
			function(row, item) self:RenderMacroRow(row, item) end,
			function(item)
				self:MakerRun("add macro", self.MakerAddMacro, item)
			end,
			function(item)
				-- Counted here as well as on the step rows: a macro dragged out of
				-- this pane is still a maker drag, and diag has to show it.
				MV:CountDrag("makerPress")
				self:PressDrag({ icon = item.icon, makerAdd = item })
			end,
			function(item)
				MV:CountDrag("makerClient")
				self:BeginDrag({ icon = item.icon, makerAdd = item }, "client")
			end
		)

		if self.makerListHeader then
			self.makerListHeader:SetText(("YOUR MACROS  %d"):format(#items))
		end
	end

	local steps = maker.steps
	self.makerRows = self.makerRows or {}
	for index = 1, MV.MAKER_MAX_STEPS do
		local row = self.makerRows[index] or self:CreateMakerRow(index)
		local step = steps[index]
		if row then
			if step then
				row.stepIndex = index
				row.stepIcon = step.icon
				row.number:SetText(tostring(index))
				row.icon:SetTexture(step.icon or 134400)
				row.text:SetText(makerStepLabel(step))
				if step.kind == "macro" and not MV:MakerFindMacro(step.value, step.scope) then
					row.text:SetTextColor(1, 0.5, 0.45)
				else
					row.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
				end
				row:Show()
			else
				row.stepIndex = nil
				row:Hide()
			end
		end
	end

	self.makerStepChild:SetHeight(math.max(#steps * MAKER_ROW_HEIGHT + 2, 1))
	if self.makerEmpty then
		-- With no macros at all, "click a macro on the left" points at an empty
		-- pane; say where one comes from instead.
		if #MV:GetMacros() == 0 then
			self.makerEmpty:SetText("Nothing to add yet - drop a spell from your spellbook above, or make a macro below.")
		else
			self.makerEmpty:SetText("Empty sequence - drop a spell above, or click a macro on the left.")
		end
	end
	showIf(self.makerEmpty, #steps == 0)
	showIf(self.makerMakeButton, #steps == 0 and #MV:GetMacros() == 0)

	if self.makerSeqLabel then
		self.makerSeqLabel:SetText(("SEQUENCE  %d/%d"):format(#steps, MV.MAKER_MAX_STEPS))
	end

	if self.makerName then
		self.makerSettingName = true
		self.makerName:SetText(maker.name or "")
		self.makerSettingName = false
	end
	if self.makerScopeButton then
		self.makerScopeButton:SetLabel(("Create on: %s"):format(
			maker.scope == "char" and "this character" or "account"
		))
	end

	self:RefreshMakerIcons()

	local body, problems = MV:ComposeMaker(maker)
	self.makerProblems = problems
	-- With no steps the body is only the #showtooltip header, and "12 / 255" on an
	-- empty sequence reads as though something had already been added.
	local shown = #steps > 0 and body or ""
	if self.makerBodySet then self.makerBodySet(shown) end
	if self.makerCounter then
		self.makerCounter:SetText(("%d / %d"):format(#shown, MV.MAX_BODY))
		if #body > MV.MAX_BODY or #problems > 0 then
			self.makerCounter:SetTextColor(1, 0.5, 0.45)
		else
			self.makerCounter:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
	end
end

-- The icon choices are the ones the sequence already carries, plus the default
-- question mark: no invented palette, and any spell you drag in brings its own.
function UI:RefreshMakerIcons()
	local row = self.makerIconRow
	if not row then return end

	local maker = MV:GetMaker()
	local icons, seen = {}, {}
	local function add(value)
		if value == nil then return end
		local key = tostring(value)
		if seen[key] then return end
		seen[key] = true
		icons[#icons + 1] = value
	end
	for _, step in ipairs(maker.steps) do add(step.icon) end
	add(maker.icon)
	add(134400)

	self.makerIconButtons = self.makerIconButtons or {}
	for index = 1, 15 do
		local button = self.makerIconButtons[index]
		if not button then
			button = CreateFrame("Button", nil, row)
			button:SetSize(MAKER_ICON_SIZE, MAKER_ICON_SIZE)
			button:SetPoint("TOPLEFT", (index - 1) * (MAKER_ICON_SIZE + 4), 0)
			button.icon = button:CreateTexture(nil, "ARTWORK")
			button.icon:SetAllPoints(button)
			button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			Border(button, 0.20, 0.18, 0.28, 1)
			button:SetScript("OnClick", function(self)
				UI:MakerRun("icon", UI.ChooseMakerIcon, self.iconValue)
			end)
			button:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText("Use this icon for the macro", 1, 1, 1)
				GameTooltip:AddLine("The sequence's own icons, plus the default question mark.",
					0.72, 0.70, 0.80, true)
				GameTooltip:Show()
			end)
			button:SetScript("OnLeave", function() GameTooltip:Hide() end)
			self.makerIconButtons[index] = button
		end

		local icon = icons[index]
		if icon then
			button.iconValue = icon
			button.icon:SetTexture(icon)
			button:Show()
			local selected = maker.icon == icon or (maker.icon == nil and index == 1)
			if selected then
				SetBorderColor(button, ACCENT[1], ACCENT[2], ACCENT[3], 1)
			else
				SetBorderColor(button, 0.20, 0.18, 0.28, 1)
			end
		else
			button.iconValue = nil
			button:Hide()
		end
	end
end

function UI:CreateMakerRow(index)
	local ui = self
	local child = self.makerStepChild
	if not child then return nil end

	local row = CreateFrame("Button", nil, child)
	row:SetHeight(MAKER_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -((index - 1) * MAKER_ROW_HEIGHT))
	row:SetPoint("TOPRIGHT", 0, -((index - 1) * MAKER_ROW_HEIGHT))

	row.bg = Paint(row, 0.075, 0.07, 0.10, 0.9)
	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(row)
	highlight:SetColorTexture(1, 1, 1, 0.06)

	row.number = Text(row, 10, MUTED, "RIGHT")
	row.number:SetPoint("LEFT", 2, 0)
	row.number:SetWidth(16)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(18, 18)
	row.icon:SetPoint("LEFT", 24, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	row.text = Text(row, 12, TEXT)
	row.text:SetPoint("LEFT", 48, 0)
	row.text:SetWidth(320)
	if row.text.SetWordWrap then row.text:SetWordWrap(false) end

	local remove = CreateFrame("Button", nil, row)
	remove:SetSize(22, 22)
	remove:SetPoint("RIGHT", -2, 0)
	local removeText = Text(remove, 13, MUTED, "CENTER")
	removeText:SetPoint("CENTER", 0, 0)
	removeText:SetText("x")
	remove:SetScript("OnEnter", function() removeText:SetTextColor(1, 0.5, 0.45) end)
	remove:SetScript("OnLeave", function() removeText:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
	remove:SetScript("OnClick", function()
		ui:MakerRun("remove", ui.MakerRemoveStep, row.stepIndex)
	end)

	-- Reordering uses the same press tracker as the sheet, so it works on a client
	-- that does not raise a drag event for a plain button.
	row:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" or not self.stepIndex then return end
		MV:CountDrag("makerPress")
		ui:PressDrag({ icon = self.stepIcon, makerStep = self.stepIndex })
	end)
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", function(self)
		if not self.stepIndex then return end
		MV:CountDrag("makerClient")
		ui:BeginDrag({ icon = self.stepIcon, makerStep = self.stepIndex }, "client")
	end)
	row:SetScript("OnDragStop", function() ui:DropDrag() end)
	row:SetScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" then return end
		-- A release that ended one of this window's drags is not a spell drop.
		if ui.drag or ui.pressDrag then return end
		ui:MakerRun("add from cursor", ui.MakerTakeCursor, self.stepIndex)
	end)
	row:SetScript("OnEnter", function(self)
		local step = self.stepIndex and MV:GetMaker().steps[self.stepIndex]
		if not step then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(makerStepLabel(step), 1, 1, 1)
		local lines, why = MV:MakerStepLines(step)
		if lines then
			for _, line in ipairs(lines) do
				GameTooltip:AddLine(line, 0.72, 0.70, 0.80, true)
			end
			GameTooltip:AddLine("Drag to reorder it - x removes it.", 0.55, 0.55, 0.63)
		else
			GameTooltip:AddLine(why or "Unavailable.", 1, 0.5, 0.45, true)
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)

	self.makerRows[index] = row
	return row
end

-- Where a dropped step or macro belongs: the row under the cursor, or the end
-- of the sequence when the cursor is over the list but not over a row.
function UI:MakerInsertAt()
	local scroll = self.makerStepScroll
	if not scroll then return nil end

	local scale = UIParent and UIParent:GetEffectiveScale() or 1
	if not scale or scale == 0 then return nil end
	local x, y = GetCursorPosition()
	if not x or not y then return nil end
	x, y = x / scale, y / scale

	local left, bottom = scroll:GetLeft(), scroll:GetBottom()
	local right, top = scroll:GetRight(), scroll:GetTop()
	if not (left and bottom and right and top) then return nil end
	if x < left or x > right or y < bottom or y > top then return nil end

	for index, row in ipairs(self.makerRows or {}) do
		if row:IsShown() then
			local rowLeft, rowBottom = row:GetLeft(), row:GetBottom()
			local rowRight, rowTop = row:GetRight(), row:GetTop()
			if rowLeft and rowBottom and rowRight and rowTop
				and x >= rowLeft and x <= rowRight and y >= rowBottom and y <= rowTop then
				return index
			end
		end
	end

	return #MV:GetMaker().steps + 1
end

function UI:MakerDrop(drag)
	local position = self:MakerInsertAt()
	if not position then
		self:RefreshMaker()
		return
	end

	MV:CountDrag("drops")

	if drag.makerStep then
		local from = drag.makerStep
		local to = position
		-- Taking the step out first shifts everything after it down one place.
		if to > from then to = to - 1 end
		if to ~= from then
			MV:MoveMakerStep(from, to)
			MV:CountDrag("makerDrops")
			self:SetStatus(("Step %d moved to %d."):format(from, to))
		end
	elseif drag.makerAdd then
		local ok, err = MV:AddMakerStep("macro", drag.makerAdd.name, drag.makerAdd.icon, position, drag.makerAdd.scope)
		if not ok then
			self:SetStatus(err or "Could not add that macro.", true)
		else
			MV:CountDrag("makerDrops")
			self:SetStatus(("Added %s at step %d."):format(drag.makerAdd.name, position))
		end
	end

	self:RefreshMaker()
end

-- Whether the cursor carries something an add-from-cursor path should look at.
function UI:CursorHoldsSomething()
	if type(GetCursorInfo) ~= "function" then return false end
	local ok, kind = pcall(GetCursorInfo)
	return ok and kind ~= nil
end

function UI:MakerTakeCursor(position)
	local kind, value, icon, why = MV:CursorStep()
	if not kind then
		-- An empty cursor is not a mistake: the line says what to do instead of
		-- going red, and clicking the sequence area stays silent (see the guards).
		self:SetStatus(why or "Nothing on the cursor - drag a spell out of your spellbook, or click a macro on the left.", false)
		return
	end

	local ok, err = MV:AddMakerStep(kind, value, icon, position)
	if not ok then
		self:SetStatus(err, true)
		return
	end

	-- The spell is still held on the cursor; releasing it here stops the next
	-- click from dropping it somewhere else as well.
	if type(ClearCursor) == "function" then pcall(ClearCursor) end

	self:RefreshMaker()
	if kind == "spell" then
		self:SetStatus(("/cast %s added."):format(value))
	else
		self:SetStatus(("Macro %s added."):format(value))
	end
end

function UI:MakerAddMacro(item)
	if not item or not item.name then return end
	local ok, err = MV:AddMakerStep("macro", item.name, item.icon, nil, item.scope)
	if not ok then
		self:SetStatus(err or "Could not add that macro.", true)
		return
	end
	self:RefreshMaker()
	self:SetStatus(("Added %s to the end of the sequence."):format(item.name))
end

function UI:ChooseMakerIcon(iconValue)
	local current = MV:GetMaker()
	current.icon = iconValue
	MV:SaveMaker()
	self:RefreshMaker()
	self:SetStatus("Icon chosen - Build macro applies it.")
end

function UI:MakerRemoveStep(position)
	if position and MV:RemoveMakerStep(position) then
		self:RefreshMaker()
		self:SetStatus(("Removed step %d."):format(position))
	end
end

function UI:ToggleMakerScope()
	local maker = MV:GetMaker()
	maker.scope = maker.scope == "char" and "account" or "char"
	MV:SaveMaker()
	self:RefreshMaker()
	self:SetStatus(maker.scope == "char"
		and "The built macro goes to this character."
		or "The built macro is account-wide.")
end

function UI:BuildMaker()
	local index, err = MV:BuildMakerMacro()
	if not index then
		-- An empty sequence is a normal stage, not a failure.
		self:SetStatus(err or "Could not build the macro.", #MV:GetMaker().steps > 0)
		return
	end

	local macro = MV:GetMacro(index)
	self.selectedMacroIndex = index
	self:RefreshMaker()
	self:RefreshMacros()
	self:SetStatus(("Built '%s' in slot %d - %d characters. Drag to bar when the order is right."):format(
		macro and macro.name or "macro", index, #((macro and macro.body) or "")))
end

function UI:PickupMaker()
	local index, err = MV:BuildMakerMacro()
	if not index then
		self:SetStatus(err or "Could not build the macro.", #MV:GetMaker().steps > 0)
		return
	end

	local ok, pickupError = MV:Pickup(index)
	if not ok then
		self:SetStatus(pickupError or "Built the macro, but could not pick it up.", true)
		return
	end

	self:SetStatus("Macro on your cursor - drop it on an action bar.")
	self.frame:Hide()
end

function UI:ClearMaker()
	MV:ClearMakerSteps()
	self:RefreshMaker()
	self:SetStatus("Sequence cleared - the macro it built stays where it is.")
end
