-- lib/chatinput.lua — mirrored chat-input panel anchored to the bottom
-- of the primary FancyChat window.
--
-- Phase 1 (this file): VISUAL MIRROR ONLY.  FFXI still owns the real
-- text entry (keystrokes, auto-translate, IME, history); we just read
-- the current input each frame and draw our own box directly under the
-- window-1 background plate.  The native input bar is NOT hidden yet —
-- that's Phase 2.  This phase exists to validate anchoring/styling, so
-- expect to see both our box and the native bar simultaneously.
--
-- Self-contained: a single d3d_present handler drives two gdi objects
-- (a background rect + a text object).  It reads the live plate
-- geometry from ro.RectBG[1].settings, so it follows window 1 through
-- moves, resizes, menu-avoidance, etc. for free, and gates on the same
-- visibility conditions render.lua uses for the primary window.

require('common')
local gdi   = require('gdifonts.include')
local utils = require('utils')
local state = require('lib.state')

local fcw         = state.fcw
local ro          = state.ro
local uiw         = state.uiw
local allSettings = state.allSettings

local M = {}

-- gdi objects, created on first use (after settings + the gdi interface
-- are live).  Kept module-local; never added to state.
local panelBG  = nil
local panelTxt = nil
local panelLbl = nil   -- channel indicator drawn left of the input frame
local objs_ok  = false

-- Map a leading chat command to a display channel + the allSettings.colors
-- key used to tint the indicator.  /say (and anything unrecognised) returns
-- nil → no indicator, matching "show what channel unless it's /say".
--
-- NOTE: this reads the *typed* command prefix, so it catches "/p ...",
-- "/l2 ...", "/t name ...", etc.  It does NOT yet know FFXI's persistent
-- chat mode (where you've set party mode and type with no slash); that
-- needs a memory read and is deferred to a later pass.
local CHANNELS = {
	sh = 'Shout',      shout = 'Shout',
	y  = 'Yell',       yell  = 'Yell',
	p  = 'Party',      party = 'Party',
	l  = 'Linkshell',  linkshell  = 'Linkshell',  li = 'Linkshell',
	l2 = 'Linkshell2', linkshell2 = 'Linkshell2',
	t  = 'Tell',       tell  = 'Tell',
	u  = 'Unity',      unity = 'Unity',
	ae = 'Assist E.',  aj = 'Assist J.',
	-- s / say intentionally absent → nil → no indicator.
}
-- Assist channels share this blue with modesDA modes 220/222 in utils.lua.
local ASSIST_BLUE = 0xFF4D9FFF
local CH_COLORKEY = {
	Shout = 'shout', Yell = 'shout',
	Party = 'party',
	Linkshell = 'linkshell1', Linkshell2 = 'linkshell2',
	Tell = 'tell', Unity = 'party',
	['Assist E.'] = 'assist', ['Assist J.'] = 'assist',
}
-- Fallback colors for channels whose allSettings.colors key may be absent
-- (e.g. before load_cb backfills a newly-added slot).
local CH_FIXEDCOLOR = {
	['Assist E.'] = ASSIST_BLUE,
	['Assist J.'] = ASSIST_BLUE,
}

-- Returns the channel label for the current input text, or nil for
-- say / non-chat commands.
local function detect_channel(text)
	local cmd = text:match('^%s*/(%S+)')
	if not cmd then return nil end
	return CHANNELS[cmd:lower()]
end

local function ensure_objects()
	if objs_ok then return true end
	-- Reuse the chat plate / font settings as a base; object:new deep-
	-- copies them, so our per-frame overrides don't touch the shared
	-- allSettings tables that style the chat windows.
	panelBG = gdi:create_rect(allSettings.rectSettings, false)
	panelBG:set_visible(false)

	panelTxt = gdi:create_object(allSettings.fontSettings, false)
	panelTxt:set_font_height(allSettings.fontSettings.font_height)
	panelTxt:set_font_color(0xFFFFFFFF)
	panelTxt:set_text('')
	panelTxt:set_visible(false)
	-- Draw text above its background.
	panelTxt:set_z_order(1)

	panelLbl = gdi:create_object(allSettings.fontSettings, false)
	panelLbl:set_font_height(allSettings.fontSettings.font_height)
	panelLbl:set_text('')
	panelLbl:set_visible(false)
	panelLbl:set_z_order(1)

	objs_ok = true
	return true
end

local function hide()
	if objs_ok then
		panelBG:set_visible(false)
		panelTxt:set_visible(false)
		panelLbl:set_visible(false)
	end
end

-- Whether the primary window is currently on-screen.  Mirrors the gate
-- guarding the window-1 render branch in render.lua (line ~667) so our
-- panel appears/disappears in lockstep with the chat it anchors to.
local function window1_visible()
	-- Mirror render.lua's window-1 gate, including the Phase 2 "keep
	-- visible while typing" disjunct so the panel shows whenever the
	-- chat plate is actually being rendered.
	local keepForInput = allSettings.ChatInputPanel[1]
		and AshitaCore:GetChatManager():IsInputOpen() == 0x11
	return (not uiw.LegacyChatOpen or allSettings.ShowWithLegacy[1] or keepForInput)
		and not fcw[1].HideChat
		and not fcw[1].Closing
		and (fcw[1].autoHideFade or 0) < 1
		and not (fcw[3] and fcw[3].BigMode)
end

local function update()
	-- Master toggle off → make sure nothing lingers on screen.
	if not (allSettings.ChatInputPanel and allSettings.ChatInputPanel[1]) then
		hide()
		return
	end

	-- Only while the native input is actually open (0x11 == open).
	if AshitaCore:GetChatManager():IsInputOpen() ~= 0x11 then
		hide()
		return
	end

	-- Need the chat plate to anchor to, and the window must be visible.
	if not ro.RectBG[1] or not window1_visible() then
		hide()
		return
	end

	ensure_objects()

	local plate = ro.RectBG[1].settings
	local fh    = allSettings.fontSettings.font_height
	local boxX  = plate.position_x + (allSettings.ChatInputPanelOffsetX or 0)
	local boxW  = plate.width
	local boxH  = fh + 6

	-- Anchor below the chat plate, but the tab selector (All/Combat/
	-- Linkshell/...) is a separate ImGui window at fcw[1].TabsPos that
	-- sits just under the plate and overlaps its bottom edge.  If that
	-- row extends lower than the plate, drop beneath it so we never
	-- cover the tab buttons.  Tab-window height mirrors the
	-- SetNextWindowSize used for the tabs window in render.lua.
	local boxY = plate.position_y + plate.height
	local tp   = fcw[1].TabsPos
	if tp and tp[2] and allSettings.ChatLines and allSettings.ChatLines > 0 then
		local tabsBottom = tp[2] + plate.height / (allSettings.ChatLines * 0.7)
		if tabsBottom > boxY then boxY = tabsBottom end
	end
	boxY = boxY + 2 + (allSettings.ChatInputPanelOffsetY or 0)

	-- Live input text → UTF-8 for the gdi renderer, rendered exactly like
	-- chat: expand auto-translate tokens (same as parser.lua), then run
	-- the full FFXI transcoder so SJIS, game glyphs, and the auto-
	-- translate brackets (\xEF\x27/\x28 → ❮ ❯) map correctly instead of
	-- turning into gibberish / centered dots.
	local raw    = AshitaCore:GetChatManager():GetInputTextRaw() or ''
	local parsed = AshitaCore:GetChatManager():ParseAutoTranslate(raw, true)
	local text   = utils.TranscodeFFXI(parsed or raw, false, false)

	-- Caret: blink only when enabled; the off-phase is a space (not empty)
	-- so the mirrored text doesn't jitter by a glyph width.
	local blink  = allSettings.ChatInputPanelCaret and allSettings.ChatInputPanelCaret[1]
	local caret  = blink and (((os.clock() % 1) < 0.5) and '|' or ' ') or ''

	-- Background = chat-plate fill scaled by the opacity setting (%).
	local op    = (allSettings.ChatInputPanelOpacity or 100) / 100
	local fill  = plate.fill_color
	local alpha = math.floor((math.floor(fill / 0x1000000) % 256) * op)
	fill = (alpha * 0x1000000) + (fill % 0x1000000)

	panelBG:set_fill_color(fill)
	panelBG:set_width(boxW)
	panelBG:set_height(boxH)
	panelBG:set_position_x(boxX)
	panelBG:set_position_y(boxY)
	panelBG:set_visible(true)

	panelTxt:set_position_x(boxX + math.floor(fh * 0.3))
	panelTxt:set_position_y(boxY + 3)
	panelTxt:set_text(text .. caret)
	panelTxt:set_visible(true)

	-- Channel indicator, just left of the input frame.  Hidden for /say
	-- (default) and non-chat commands.  Width is estimated from the label
	-- length so we can left-place it without a measure round-trip.
	local ch = detect_channel(text)
	if ch then
		local key   = CH_COLORKEY[ch]
		local color = (key and allSettings.colors[key] and allSettings.colors[key][1])
			or CH_FIXEDCOLOR[ch] or 0xFFFFFFFF
		local labelW = math.floor(#ch * fh * 0.6) + 6
		panelLbl:set_text(ch)
		panelLbl:set_font_color(color)
		panelLbl:set_position_x(boxX - labelW - 4)
		panelLbl:set_position_y(boxY + 3)
		panelLbl:set_visible(true)
	else
		panelLbl:set_visible(false)
	end
end

-- ===================================================================
-- Approach-B RE helper (read-only): dump the inline menu's stack-entry
-- handler pointer (MenuID +0x0C, stable across opens) and the words it
-- points at, to test whether it's a function table / vtable we can hook.
-- Armed by /fchat vt; fires the next time the input is open (typing the
-- command itself closes the input, so a one-shot read can't see it).
-- ===================================================================
local vt_armed = false

function M.vt_arm()
	vt_armed = true
	print('[fchat] vt armed — open the chat input; result prints while it is open.')
end
_G.FCVtArm = M.vt_arm

local function vt_capture()
	vt_armed = false
	local mp = uiw.MenuPtr
	if not mp or mp == 0 then print('[fchat] vt: MenuPtr unresolved'); return end
	local menuID = ashita.memory.read_uint32(mp)
	if menuID == 0 then print('[fchat] vt: no menu on stack'); return end
	local obj     = ashita.memory.read_uint32(menuID + 4)
	local name    = ashita.memory.read_string(obj + 0x46, 16):gsub('\x00', ''):trimex()
	local handler = ashita.memory.read_uint32(menuID + 0x0C)
	print(('[fchat] vt name="%s" obj=0x%08X MenuID=0x%08X handler(+0C)=0x%08X'):format(name, obj, menuID, handler))
	if handler ~= 0 then
		-- Code pointers will look like FFXiMain.dll addresses (~0x10xxxxxx);
		-- heap/data will look like 0x04/0x0C/0x20xxxxxx.
		for row = 0, 0x3C, 0x10 do
			print(('[fchat]   +%02X: %08X %08X %08X %08X'):format(row,
				ashita.memory.read_uint32(handler + row),     ashita.memory.read_uint32(handler + row + 4),
				ashita.memory.read_uint32(handler + row + 8), ashita.memory.read_uint32(handler + row + 12)))
		end
	end
end

-- Phase 2: drive the native-bar hide hook in gdifonttexture.dll.  Each
-- frame, when the panel is on and the chat input is open, locate the
-- inline-prompt element (the same one the vt probe found:
-- element = [MenuID+0x0C], with the menu name confirmed as "inline") and
-- tell the DLL to suppress its draw.  Otherwise suppress = false so the
-- native bar renders normally.
local function update_bar_hook()
	if not gdi.UpdateInputBarHook then return end
	local element, ownerMenu, suppress = 0, 0, false
	if allSettings.ChatInputPanel and allSettings.ChatInputPanel[1]
		and AshitaCore:GetChatManager():IsInputOpen() == 0x11
		and uiw.MenuPtr and uiw.MenuPtr ~= 0 then
		local menuID = ashita.memory.read_uint32(uiw.MenuPtr)
		if menuID ~= 0 then
			local obj  = ashita.memory.read_uint32(menuID + 4)
			local name = ashita.memory.read_string(obj + 0x46, 16)
			if name and name:find('inline') then
				element   = ashita.memory.read_uint32(menuID + 0x0C)
				ownerMenu = menuID   -- elements store their MenuID at +0x08
				suppress  = true
			end
		end
	end
	gdi:UpdateInputBarHook(element, ownerMenu, suppress)
end

function M.register()
	-- Registered AFTER render.register() (see fancychat.lua) so the
	-- plate geometry we read has already been updated for this frame.
	ashita.events.register('d3d_present', 'fc_chatinput_present', function ()
		if vt_armed and AshitaCore:GetChatManager():IsInputOpen() == 0x11 then
			pcall(vt_capture)
		end
		pcall(update_bar_hook)
		-- Never let a draw error kill the frame; just skip the panel.
		local ok, err = pcall(update)
		if not ok then hide() end
	end)
end

-- Remove the DLL vtable patch on addon unload so a reload can't leave a
-- dangling pointer into freed code.
function M.unhook()
	if gdi.RemoveInputBarHook then pcall(function() gdi:RemoveInputBarHook() end) end
end
_G.ChatInputUnhook = M.unhook

return M
