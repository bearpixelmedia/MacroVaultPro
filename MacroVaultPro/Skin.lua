-- MacroVaultPro - window skin
--
-- The window is built the way Lueur builds its own: the client's portrait frame
-- and title bar, the dark tooltip-texture cards the profession window uses for
-- its panels, icon tabs down the right edge, and Blizzard's panel-button chrome.
-- Every template is asked for through pcall and every one has a plain-texture
-- fallback, so a client without a template still gets a working window.

local ADDON_NAME, MV = ...
MV = MV or _G.MacroVaultPro or {}

local Skin = {}
MV.Skin = Skin

-- Which of the client's templates each piece of the skin actually managed to
-- use: nil until that piece is first built, then true when the template drew it
-- and false when a fallback did. /mvpro diag prints this, so a screenshot says
-- which path is drawing without guessing from the picture.
Skin.templates = {}

local PORTRAIT = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\icon.tga"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

Skin.PORTRAIT = PORTRAIT
Skin.ICON_UNKNOWN = UNKNOWN_ICON

-- The tooltip backdrop the game draws under its panels, darkened; the border is
-- the warm gold of the client's own window trim.
local CARD = {
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- A frame from one of the client's templates; nil on a client that lacks it.
function Skin.FromTemplate(kind, name, parent, template)
	local ok, frame = pcall(CreateFrame, kind, name, parent, template)
	return ok and frame or nil
end

function Skin.HasAtlas(atlas)
	if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
	local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
	return ok and info ~= nil
end

-- Gives a texture its file, or the client's question mark when the file is not
-- on this client.
function Skin.SetIcon(texture, file)
	if texture:SetTexture(file) == false then texture:SetTexture(UNKNOWN_ICON) end
end

-- Window: the portrait frame of the client's own windows, with this addon's icon
-- as the portrait. `frame.title` is its title, `frame.close` its close button.
function Skin.Window(name, width, height, titleText)
	local frame = Skin.FromTemplate("Frame", name, UIParent, "PortraitFrameTemplate")
	Skin.templates.PortraitFrameTemplate = frame ~= nil
	if frame then
		-- Where the title, the portrait and the close button sit has moved between
		-- client versions, so all three are looked for in both places.
		frame.title = frame.TitleContainer and frame.TitleContainer.TitleText or frame.TitleText
		frame.close = frame.CloseButton
		local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait or frame.portrait
		if portrait then Skin.SetIcon(portrait, PORTRAIT) end
	else
		frame = CreateFrame("Frame", name, UIParent)
		local back = frame:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.05, 0.04, 0.03, 0.96)
	end

	if frame.title then
		frame.title:SetText(titleText or "")
	else
		frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.title:SetPoint("TOP", 0, -6)
		frame.title:SetText(titleText or "")
	end

	if not frame.close then
		frame.close = Skin.FromTemplate("Button", nil, frame, "UIPanelCloseButton") or CreateFrame("Button", nil, frame)
		frame.close:SetSize(24, 24)
		frame.close:SetPoint("TOPRIGHT", -2, -2)
	end
	frame.close:SetScript("OnClick", function() frame:Hide() end)

	frame:Hide()
	frame:SetSize(width, height)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	return frame
end

-- Card: a panel with the tooltip backdrop, like the panels of the profession
-- window. Without the template it is a plain frame with a dark fill.
function Skin.Card(parent, width, height)
	local card = Skin.FromTemplate("Frame", nil, parent, "BackdropTemplate")
	Skin.templates.BackdropTemplate = (card ~= nil and card.SetBackdrop ~= nil) and true or false
	if card and card.SetBackdrop then
		card:SetBackdrop(CARD)
		card:SetBackdropColor(0.03, 0.03, 0.03, 0.72)
		card:SetBackdropBorderColor(0.62, 0.56, 0.46, 0.9)
	else
		card = card or CreateFrame("Frame", nil, parent)
		local back = card:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0, 0, 0, 0.55)
	end
	if width and height then card:SetSize(width, height) end
	return card
end

-- Card: applies the same panel styling to a frame that already exists, so the
-- panes inside a page read as cards too. Returns false when the frame cannot take
-- a backdrop, and the caller draws the plain version instead.
function Skin.Panel(frame)
	if not frame or not frame.SetBackdrop then
		Skin.templates.BackdropTemplate = false
		return false
	end
	local ok = pcall(frame.SetBackdrop, frame, CARD)
	Skin.templates.BackdropTemplate = ok and true or false
	if not ok then return false end
	pcall(frame.SetBackdropColor, frame, 0.03, 0.03, 0.03, 0.72)
	pcall(frame.SetBackdropBorderColor, frame, 0.62, 0.56, 0.46, 0.9)
	return true
end

local function tabTooltip(tab, text)
	if not text then return end
	tab.tooltipText = text
	tab:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipText, 1, 1, 1)
		GameTooltip:Show()
	end)
	tab:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- SideTab: an icon tab on the right edge of the window, under `previous` when
-- there is one. SetChecked shows it chosen.
function Skin.SideTab(window, previous, icon, onClick, tooltipText)
	local tab = Skin.FromTemplate("Frame", nil, window, "LargeSideTabButtonTemplate")
	tab = (tab and tab.Icon and tab.SetChecked and tab.SetCustomOnMouseUpHandler) and tab or nil
	Skin.templates.LargeSideTabButtonTemplate = tab ~= nil
	if tab then
		Skin.SetIcon(tab.Icon, icon)
		if tab.SetFillToInterior then tab:SetFillToInterior(true) end
		tab:SetCustomOnMouseUpHandler(function(_, mouseButton, inside)
			if mouseButton == "LeftButton" and inside then onClick() end
		end)
		if previous then
			tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
		else
			tab:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -60)
		end
		tabTooltip(tab, tooltipText)
		return tab
	end

	-- Without the side-tab template: the spellbook's own tab art.
	tab = CreateFrame("CheckButton", nil, window)
	tab:SetSize(32, 32)
	local back = tab:CreateTexture(nil, "BACKGROUND")
	back:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
	back:SetSize(64, 64)
	back:SetPoint("TOPLEFT", -3, 11)
	local face = tab:CreateTexture(nil, "ARTWORK")
	face:SetAllPoints()
	Skin.SetIcon(face, icon)
	tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
	local glow = tab:GetCheckedTexture()
	if glow then glow:SetBlendMode("ADD") end
	tab:SetScript("OnClick", function()
		if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
		onClick()
	end)
	if previous then
		tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -17)
	else
		tab:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -66)
	end
	tabTooltip(tab, tooltipText)
	return tab
end

-- Button: the client's panel button, so it carries the same gold trim, pressed
-- state and glow as the buttons in the client's own windows.
function Skin.Button(parent, text, width, onClick)
	local button = Skin.FromTemplate("Button", nil, parent, "UIPanelButtonTemplate")
	Skin.templates.UIPanelButtonTemplate = button ~= nil
	if not button then
		button = CreateFrame("Button", nil, parent)
		local back = button:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.16, 0.14, 0.10, 1)
	end
	button:SetSize(width or 130, 22)
	if button.SetText then button:SetText(text or "") end
	button.label = button.GetFontString and button:GetFontString() or nil

	if onClick then
		button:SetScript("OnClick", function(...)
			if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION) end
			onClick(...)
		end)
	end
	return button
end
