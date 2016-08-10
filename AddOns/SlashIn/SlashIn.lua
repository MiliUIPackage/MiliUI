--[[-------------------------------------------------------------------------
	SlashIn
	Please contact Morsker through PM on wowace.com.

	Provides the /in command for delayed execution.

	Copyright (c) 2010-2011  Morsker

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
---------------------------------------------------------------------------]]
local addonName, SlashIn = ...
LibStub("AceTimer-3.0"):Embed(SlashIn)

local print = print
local tonumber = tonumber
local MacroEditBox = MacroEditBox
local MacroEditBox_OnEvent = MacroEditBox:GetScript("OnEvent")

-- We execute lines by faking them as EXECUTE_CHAT_LINE events to the MacroEditBox defined in ChatFrame.lua.
-- The main benefit of this is that MacroEditBox gets special treatment in ChatEdit_OnEscapePressed.
-- It's also elegant, and reuses Blizzard code.
-- The main concern is taint, but I've tested it fairly well, and analyzed the execution path, and I'm
-- reasonably sure taint isn't an issue.
-- If taint does become a problem, there are other implementations that work just as well; they're just
-- less elegant. The dev version in Git has an alternative implementation commented out at the bottom.
local function OnCallback(command)
	MacroEditBox_OnEvent(MacroEditBox, "EXECUTE_CHAT_LINE", command)
end

-- GLOBALS: SLASH_SLASHIN_IN1
-- GLOBALS: SLASH_SLASHIN_IN2
SLASH_SLASHIN_IN1 = "/in"
SLASH_SLASHIN_IN2 = "/slashin"

function SlashCmdList.SLASHIN_IN(msg)
	local secs, command = msg:match("^([^%s]+)%s+(.*)$")
	secs = tonumber(secs)
	if (not secs) or (#command == 0) then
		local prefix = "|cff33ff99"..addonName.."|r:"
		print(prefix, "usage:\n /in <seconds> <command>")
		print(prefix, "example:\n /in 1.5 /say hi")
	else
		SlashIn:ScheduleTimer(OnCallback, secs, command)
	end
end
