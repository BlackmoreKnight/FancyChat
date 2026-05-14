-- lib/commands.lua — /fancychat (alias /fchat) slash-command handler.

require('common')
local utils = require('utils')
local help  = require('help')
local state = require('lib.state')

local fcw         = state.fcw
local dw          = state.dw
local b           = state.b
local par         = state.par
local allSettings = state.allSettings

local M = {}

function M.register()
	ashita.events.register('command', 'command_cb', function (e)
		local args = e.command:args()
		if (#args == 0 or (not args[1]:any('/fancychat') and not args[1]:any('/fchat'))) then
			return
		end

		e.blocked = true

		if (#args == 2 and args[2] == 'bigmode') then
			fcw[3].BigMode = not fcw[3].BigMode
			return
		end
		if (#args == 2 and args[2] == 'savelogs') then
			local ts = os.date('[%Y_%m_%d-%H_%M_%S]', os.time())
			utils.SaveLogs(b.ChatBuffer[1][2].text, b.ChatBuffer[1][2].auxText, 'All',       fcw[1].PlayerName, addon.path, ts); coroutine.sleep(0.5)
			utils.SaveLogs(b.ChatBuffer[3][2].text, b.ChatBuffer[3][2].auxText, 'Combat',    fcw[1].PlayerName, addon.path, ts); coroutine.sleep(0.5)
			utils.SaveLogs(b.ChatBuffer[4][2].text, b.ChatBuffer[4][2].auxText, 'Linkshell', fcw[1].PlayerName, addon.path, ts); coroutine.sleep(0.5)
			utils.SaveLogs(b.ChatBuffer[5][2].text, b.ChatBuffer[5][2].auxText, 'Party',     fcw[1].PlayerName, addon.path, ts); coroutine.sleep(0.5)
			utils.SaveLogs(b.ChatBuffer[6][2].text, b.ChatBuffer[6][2].auxText, 'Tell',      fcw[1].PlayerName, addon.path, ts); coroutine.sleep(0.5)
			utils.SaveLogs(b.ChatBuffer[7][2].text, b.ChatBuffer[7][2].auxText, 'Shout',     fcw[1].PlayerName, addon.path, ts); coroutine.sleep(0.5)
			utils.SaveLogs(b.ChatBuffer[8][2].text, b.ChatBuffer[8][2].auxText, 'Custom',    fcw[1].PlayerName, addon.path, ts); coroutine.sleep(0.5)
			return
		end


		if not fcw[1].Closing and fcw[1].InitDone and fcw[1].LoggedIn then
			if (#args == 2 and args[2] == 'guideme') then
				fcw[1].GuideMeOpened[1] = not fcw[1].GuideMeOpened[1]
				if fcw[1].GuideMeOpened[1] then
					fcw[1].NotepadOpened[1] = false
				end
				return
			end
			if (#args == 2 and args[2] == 'settings') then
				allSettings.settingsOpened[1] = not allSettings.settingsOpened[1]
				SaveSettings()
				return
			end
			if (#args == 2 and args[2] == 'compact') then
				allSettings.CompactTabs = not allSettings.CompactTabs
				fcw[1].PosChanged = true
				fcw[2].PosChanged = true
				SaveSettings()
				return
			end
			if (#args == 2 and args[2] == 'manual') then
				help.opened[1] = not help.opened[1]
				return
			end
			if (#args == 2 and args[2] == 'notes') then
				fcw[1].NotepadOpened[1] = not fcw[1].NotepadOpened[1]
				if fcw[1].NotepadOpened[1] then
					fcw[1].GuideMeOpened[1] = false
				end
				return
			end
			if (#args == 2 and args[2] == 'tod') then
				allSettings.PreciseTS[1] = not allSettings.PreciseTS[1]
				SaveSettings()
				return
			end
			if (#args == 2 and args[2] == 'ts') then
				print('Current Time: '..os.date(par.FormatTS[1], os.time()))
				return
			end
		end
	end)
end

return M
