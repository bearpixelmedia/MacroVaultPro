-- MacroVault - built-in tool palette and macro library
local ADDON_NAME, MV = ...

local ICONS = {
	debug   = "Interface\\Icons\\INV_Misc_Spyglass_02",
	note    = "Interface\\Icons\\INV_Misc_Note_01",
	scroll  = "Interface\\Icons\\INV_Scroll_03",
	gear    = "Interface\\Icons\\INV_Misc_Gear_01",
	target  = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
	focus   = "Interface\\Icons\\Spell_Holy_MagicalSentry",
	sword   = "Interface\\Icons\\Ability_Warrior_Charge",
	trinket = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01",
	mark    = "Interface\\Icons\\Ability_Hunter_SniperShot",
}

-- Instant tools. These call the client's own slash command handlers, so they
-- behave exactly as if the command were typed into chat.
MV.TOOLS = {
	{
		label = "Frame stack",
		icon  = ICONS.debug,
		cmd   = "/fstack",
		desc  = "Toggle the frame stack tooltip for whatever is under your cursor.",
	},
	{
		label = "Frame stack + hidden",
		icon  = ICONS.debug,
		cmd   = "/fstack true",
		desc  = "Same as /fstack, but also lists hidden frames.",
	},
	{
		label = "Event trace",
		icon  = ICONS.scroll,
		cmd   = "/etrace",
		desc  = "Toggle Blizzard's event trace window.",
	},
	{
		label = "Build info",
		icon  = ICONS.note,
		cmd   = "/dump select(4, GetBuildInfo())",
		desc  = "Print the client's interface version (Forever is 16001).",
	},
	{
		label = "API browser",
		icon  = ICONS.note,
		cmd   = "/api",
		desc  = "Open the API documentation browser.",
	},
	{
		label = "Macro window",
		icon  = ICONS.gear,
		desc  = "Open the game's own macro window.",
		run   = function()
			local ok, err = MV:OpenMacroUI()
			if ok then
				MV:Notify("Opened the macro window.")
			else
				MV:Notify(err or "Could not open the macro window.", true)
			end
		end,
	},
	{
		label = "Reload UI",
		icon  = ICONS.gear,
		cmd   = "/reload",
		desc  = "Reload the interface after changing addon files.",
	},
	{
		label = "Script errors on",
		icon  = ICONS.debug,
		cmd   = "/console scriptErrors 1",
		desc  = "Show Lua errors in a popup so you can see what broke.",
	},
	{
		label = "Script errors off",
		icon  = ICONS.debug,
		cmd   = "/console scriptErrors 0",
		desc  = "Hide the Lua error popup again.",
	},
	{
		label = "Taint log",
		icon  = ICONS.note,
		cmd   = "/console taintLog 1",
		desc  = "Enable the taint log (Logs\\taint.log). A reload is needed.",
	},
	{
		label = "Mouseover frame",
		icon  = ICONS.debug,
		desc  = "Print the name and type of the frame under your cursor.",
		run   = function()
			local frame = GetMouseFocus()
			if not frame then
				MV:Notify("No frame under the cursor.")
				return
			end
			local name = frame.GetName and frame:GetName() or nil
			local kind = frame.GetObjectType and frame:GetObjectType() or "Frame"
			MV:Notify(("%s  (%s)"):format(name or "<anonymous frame>", kind))
		end,
	},
	{
		label = "Dump mouseover frame",
		icon  = ICONS.note,
		cmd   = "/dump GetMouseFocus()",
		desc  = "Print the whole mouseover frame table, including its regions.",
	},
}

-- Ready-made macros. "Create" turns one into a real in-game macro; the body is
-- plain macro text, 255 characters maximum.
local nextId = 0
local function entry(group, label, icon, body, desc)
	nextId = nextId + 1
	return {
		id = nextId,
		key = nextId,
		group = group,
		label = label,
		icon = icon,
		body = body,
		desc = desc,
	}
end

MV.LIBRARY = {
	-- Targeting
	entry("Targeting", "Mouseover target", ICONS.target,
		"/target [@mouseover,harm,nodead]",
		"Target the hostile unit under your cursor."),
	entry("Targeting", "Mouseover target (any)", ICONS.target,
		"/target [@mouseover,exists,nodead]",
		"Target anything under your cursor, friendly or hostile."),
	entry("Targeting", "Mouseover focus", ICONS.focus,
		"/focus [@mouseover,exists,nodead][]",
		"Focus the unit under your cursor, falling back to your target."),
	entry("Targeting", "Mouseover's target", ICONS.target,
		"/target [@mouseovertarget,harm,nodead]",
		"Target whatever the unit under your cursor is targeting."),
	entry("Targeting", "Clear target", ICONS.target,
		"/cleartarget",
		"Drop your current target."),
	entry("Targeting", "Last target", ICONS.target,
		"/targetlasttarget",
		"Swap back to your previous target."),
	entry("Targeting", "Nearest enemy", ICONS.sword,
		"/targetenemy",
		"Target the closest enemy."),
	entry("Targeting", "Assist mouseover", ICONS.focus,
		"/assist mouseover",
		"Take the mouseover unit's target as your own."),
	entry("Targeting", "Skull marker", ICONS.mark,
		"/tm 8",
		"Put the skull raid marker on your target."),
	entry("Targeting", "Clear marker", ICONS.mark,
		"/tm 0",
		"Clear the raid marker from your target."),

	-- Utility
	entry("Utility", "Trinket 1", ICONS.trinket,
		"#showtooltip 13\n/use 13",
		"Use your top trinket, with its tooltip and cooldown on the button."),
	entry("Utility", "Both trinkets", ICONS.trinket,
		"#showtooltip 13\n/use 13\n/use 14",
		"Use both trinket slots in one press."),
	entry("Utility", "Start attack", ICONS.sword,
		"/startattack",
		"Start auto-attacking your target (melee classes)."),
	entry("Utility", "Stop casting", ICONS.sword,
		"/stopcasting",
		"Interrupt whatever you are casting right now."),
	entry("Utility", "Dismount", ICONS.gear,
		"/dismount",
		"Get off your mount."),
	entry("Utility", "Sit / stand", ICONS.gear,
		"/sit",
		"Sit down, or stand up if you are sitting."),
	entry("Utility", "Follow", ICONS.gear,
		"/follow",
		"Follow your current target."),
	entry("Utility", "Stopwatch", ICONS.gear,
		"/stopwatch",
		"Toggle the stopwatch."),
	entry("Utility", "Ready check", ICONS.note,
		"/readycheck",
		"Start a ready check in your party or raid."),
	entry("Utility", "Roll 100", ICONS.note,
		"/roll 100",
		"Roll 1-100 in group chat."),
	entry("Utility", "Played time", ICONS.note,
		"/played",
		"Print how long this character has been played."),

	-- Development
	entry("Development", "Frame stack", ICONS.debug,
		"/fstack",
		"Toggle the frame stack tooltip under your cursor."),
	entry("Development", "Event trace", ICONS.scroll,
		"/etrace",
		"Toggle the event trace window."),
	entry("Development", "Dump mouseover frame", ICONS.note,
		"/run local f = GetMouseFocus(); print(f and (f:GetName() or tostring(f)) or \"none\")",
		"Print the name of the frame under your cursor from a macro."),
	entry("Development", "Script errors", ICONS.debug,
		"/console scriptErrors 1",
		"Turn the Lua error popup on."),
	entry("Development", "Reload UI", ICONS.gear,
		"/reload",
		"Reload the interface."),
}
