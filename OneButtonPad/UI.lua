-- One Button Pad - the window.
--
-- One read-only list: Forever One Button's cells, the chord that presses each
-- one, and nothing else. Sized for a controller player reading across a room: one
-- row per line, a 34 px row, a 24 px icon and 13 px text. Every control refreshes
-- or copies - none of them changes a cell or a key.
local ADDON_NAME, OPB = ...
OPB = OPB or _G.OneButtonPad or {}

local UI = {}
OPB.UI = UI

local WIDTH, HEIGHT = 402, 468
local ROW_HEIGHT   = 34
local PANE_WIDTH   = 374
local LIST_HEIGHT  = 326

local FONT   = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local ACCENT = { 0.34, 0.72, 0.97 }
local TEXT   = { 0.90, 0.90, 0.94 }
local MUTED  = { 0.56, 0.56, 0.64 }

-------------------------------------------------------------------------------
-- Drawing helpers
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

local function showIf(region, condition)
	if condition then region:Show() else region:Hide() end
end

function UI:MakeButton(parent, label, width, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width or 110, 28)
	Paint(button, 0.15, 0.17, 0.22, 1)
	Border(button, 0.28, 0.34, 0.44, 1)

	local text = Text(button, 12, TEXT, "CENTER")
	text:SetPoint("CENTER", 0, 0)
	text:SetText(label or "")

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(button)
	highlight:SetColorTexture(1, 1, 1, 0.07)

	button.label = text
	button.SetLabel = function(self, value) self.label:SetText(value) end
	if onClick then button:SetScript("OnClick", onClick) end
	return button
end

-------------------------------------------------------------------------------
-- One scrolling list: rows are made once and reused
-------------------------------------------------------------------------------

function UI:MakeList(parent, height)
	local list = { rows = {} }

	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetPoint("TOPLEFT")
	scroll:SetSize(PANE_WIDTH - 16, height or LIST_HEIGHT)
	scroll:EnableMouseWheel(true)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(PANE_WIDTH - 16, 1)
	scroll:SetScrollChild(child)

	local empty = Text(scroll, 12, MUTED, "CENTER")
	empty:SetPoint("CENTER", 0, 0)
	empty:SetWidth(PANE_WIDTH - 60)
	empty:SetText("Nothing to show.")
	empty:Hide()

	local function scrollBy(_, delta)
		local maxScroll = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
		local value = scroll:GetVerticalScroll() - (delta or 0) * ROW_HEIGHT
		scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, value)))
	end
	scroll:SetScript("OnMouseWheel", scrollBy)

	list.scroll, list.child, list.empty = scroll, child, empty

	function list:CreateRow(index)
		local row = CreateFrame("Frame", nil, child)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
		row:SetPoint("TOPRIGHT", 0, -((index - 1) * ROW_HEIGHT))
		row:EnableMouseWheel(true)
		row:SetScript("OnMouseWheel", scrollBy)

		row.strip = row:CreateTexture(nil, "BACKGROUND")
		row.strip:SetAllPoints(row)
		row.strip:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.035 or 0)

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(24, 24)
		row.icon:SetPoint("LEFT", 4, 0)
		row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		row.icon:Hide()

		row.label = Text(row, 13, TEXT)
		row.label:SetPoint("LEFT", 8, 0)
		row.label:SetWidth(228)
		if row.label.SetWordWrap then row.label:SetWordWrap(false) end

		row.tag = Text(row, 12, MUTED, "RIGHT")
		row.tag:SetPoint("RIGHT", -6, 0)
		row.tag:SetWidth(118)

		return row
	end

	function list:SetItems(items, render)
		local count = #items
		for index = 1, count do
			local row = self.rows[index]
			if not row then
				row = self:CreateRow(index)
				self.rows[index] = row
			end
			row:Show()
			render(row, items[index])
		end

		for index = count + 1, #self.rows do
			self.rows[index]:Hide()
		end

		child:SetHeight(math.max(count * ROW_HEIGHT, 1))
		showIf(empty, count == 0)
		scroll:SetVerticalScroll(0)
	end

	return list
end

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------

function UI:ApplyPosition()
	local frame = self.frame
	if not frame then return end

	local saved = type(OneButtonPadDB) == "table" and OneButtonPadDB or {}
	local position = saved.position

	frame:ClearAllPoints()
	if type(position) == "table" and position.point then
		frame:SetPoint(position.point, UIParent, position.relPoint or position.point,
			position.x or 0, position.y or 0)
	else
		frame:SetPoint("CENTER")
	end

	local scale = tonumber(saved.scale) or 1
	if scale < 0.6 then scale = 0.6 elseif scale > 2 then scale = 2 end
	frame:SetScale(scale)
end

function UI:Build()
	if self.frame then return self.frame end

	local frame = CreateFrame("Frame", "OneButtonPadFrame", UIParent)
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
		OPB:SavePosition()
	end)
	frame:Hide()
	Paint(frame, 0.04, 0.045, 0.06, 0.97)
	Border(frame, 0.20, 0.28, 0.38, 1)

	self.frame = frame

	if type(UISpecialFrames) == "table" then
		tinsert(UISpecialFrames, "OneButtonPadFrame")
	end

	local title = Text(frame, 18, ACCENT)
	title:SetPoint("TOPLEFT", 16, -12)
	title:SetText("One Button Pad")

	local subtitle = Text(frame, 11, MUTED)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -3)
	subtitle:SetWidth(WIDTH - 60)
	subtitle:SetText("Forever One Button's cells and the chord that presses each one. Read-only: " ..
		"nothing here moves a cell or changes a key.")

	local close = self:MakeButton(frame, "X", 26, function() frame:Hide() end)
	close:SetPoint("TOPRIGHT", -10, -10)

	local pane = CreateFrame("Frame", nil, frame)
	pane:SetPoint("TOPLEFT", 14, -58)
	pane:SetSize(PANE_WIDTH, LIST_HEIGHT + 44)
	Paint(pane, 0.02, 0.025, 0.035, 0.85)
	Border(pane, 0.16, 0.22, 0.30, 1)

	local header = Text(pane, 10, MUTED)
	header:SetPoint("TOPLEFT", 10, -9)
	header:SetText("FOREVER ONE BUTTON  -  CELLS AND KEYS")

	self.cellStatus = Text(pane, 11, TEXT)
	self.cellStatus:SetPoint("TOPLEFT", 10, -25)
	self.cellStatus:SetWidth(PANE_WIDTH - 20)

	local body = CreateFrame("Frame", nil, pane)
	body:SetPoint("TOPLEFT", 4, -44)
	body:SetSize(PANE_WIDTH - 8, LIST_HEIGHT)
	self.cellList = self:MakeList(body)

	-- Footer: the two controls, and the sentence that keeps the list honest.
	local refresh = self:MakeButton(frame, "Refresh", 104, function() UI:Refresh() end)
	refresh:SetPoint("BOTTOMLEFT", 14, 14)

	local copy = self:MakeButton(frame, "Copy to chat", 124, function()
		OPB:PrintReport()
		UI:SetStatus("Report printed to chat - it can be copied from there.")
	end)
	copy:SetPoint("LEFT", refresh, "RIGHT", 8, 0)

	self.status = Text(frame, 10, MUTED)
	self.status:SetPoint("LEFT", copy, "RIGHT", 12, 0)
	self.status:SetWidth(WIDTH - 286)
	self.status:SetText("A cell is pressed by its chord, so the key on the right is what to press.")

	self:ApplyPosition()
	return frame
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

-------------------------------------------------------------------------------
-- Refresh: read Forever One Button once and put the list up
-------------------------------------------------------------------------------

function UI:Refresh()
	if not self.frame then return end

	local ok, err = pcall(self.RefreshLists, self)
	if not ok then
		self:SetStatus(("Could not read the cells - %s"):format(tostring(err)), true)
		self.cellStatus:SetText("")
		self.cellList:SetItems({}, function() end)
	end
end

function UI:RefreshLists()
	local one = OPB:OneButton()

	local cellRows = {}
	if one.present then
		for _, cell in ipairs(one.cells) do
			OPB:Resolve(cell)
			cellRows[#cellRows + 1] = {
				label = ("Cell %d    %s"):format(cell.slot, tostring(cell.name)),
				icon  = cell.icon,
				tag   = cell.key or "no key",
				dim   = cell.hidden or not cell.key,
			}
		end
		self.cellStatus:SetText((("version %s  -  %d cells, %d with a key"):format(
			one.version or "unread", #one.cells, one.keyed or 0))
			.. (one.keyless and one.keyless > 0 and ("  -  %d with no key"):format(one.keyless) or ""))
	else
		self.cellStatus:SetText("not loaded - install Forever One Button, then /reload")
	end

	self.cellList:SetItems(cellRows, function(row, item)
		row.icon:SetTexture(item.icon or 134400)
		showIf(row.icon, item.icon ~= nil)
		row.label:SetText(item.label)
		row.tag:SetText(item.tag)
		local color = item.dim and MUTED or TEXT
		row.label:SetTextColor(color[1], color[2], color[3])
		row.tag:SetTextColor(color[1], color[2], color[3])
	end)
end
