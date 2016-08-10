--[[ ---------------------------------------------------------------------------

StopTheSpam, by Malreth of Silver Hand

Copyright (c) 2006, Tyler Riti
All Rights Reserved

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
          this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of the author nor the names of the contributors may be
      used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

----------------------------------------------------------------------------- ]]

--[[ ------------------------------------------------------------------------ ]]

if not StopTheSpam then
	StopTheSpam = {}
end

--[[ ------------------------------------------------------------------------ ]]

local AceHook = AceLibrary("AceHook-2.1"):embed(StopTheSpam)

--[[ ------------------------------------------------------------------------ ]]

local ALLOW = 1
local DENY  = 0

--[[ ------------------------------------------------------------------------ ]]

local DEBUG = nil

local function dprintf(...)
	if DEBUG then
		ChatFrame3:AddMessage(string.format("[%.03f] StopTheSpam: ", GetTime())..string.format(...))
	end
end

--[[ ------------------------------------------------------------------------ ]]

function StopTheSpam:Initialize()
	-- Hook the default chat frame's AddMessage method.
	self:Hook(ChatFrame1, "AddMessage", true)
	
	-- Hook the combat log frame's AddMessage method to catch Gatherer.
	self:Hook(ChatFrame2, "AddMessage", true)
	
	-- self:ScheduleEvent(self.Release, 5, self)
	local f = CreateFrame("Frame")
	f:SetScript("OnEvent", function (frame, event)
		dprintf("OnEvent(%s)", event)
		
		frame:UnregisterEvent(event)
		self:Release()
	end)
	
	-- Register for a late-firing event that happens on startup or reload.
	f:RegisterEvent("UPDATE_PENDING_MAIL")
	
	self.frame = f
	
	-- Spam the user with another addon loaded message.
	DEFAULT_CHAT_FRAME:AddMessage("Malreth's StopTheSpam Loaded!")
end

function StopTheSpam:AddMessage(obj, msg, r, g, b, id)
	if self:IsMessageSpam(msg, id, this) then
		-- Discard the message.
		dprintf("Message |cffff0000FAILS|r.")
	else
		-- Let the message pass through.
		dprintf("Message |cff00ff00PASSES|r.")
		self.hooks[obj].AddMessage(obj, msg, r, g, b, id)
	end
end

function StopTheSpam:IsMessageSpam(msg, id, frame)
	local ruleset = self.ruleset
	
	dprintf("IsMessageSpam(%s, %s, %s)", string.gsub(tostring(msg), "|", "||"), tostring(id), frame and (frame.GetName and frame:GetName() or "(no name)") or "(no frame)")
	
	if msg then
		for i, name in ipairs(ruleset.order) do
			local rule = ruleset.rules[name]
			
			-- Disabled rules should be ignored.
			if not rule.disabled then
				-- If the rule tests true then there is a match. The absence of a test implies a positive match.
				local match = not rule.test or rule.test(msg, id, frame)
				
				-- The rule matches but it may not actually be spam.
				if match then
					dprintf("    Rule %d '%s' |cff00ff00MATCHES|r. Result '%s' Action '%s'", i, name, tostring(match), rule.action == ALLOW and "ALLOW" or "DENY")
					
					-- Update the expiration count and handle expired rules if necessary.
					if rule.expire then
						if rule.expire <= 1 then
							dprintf("        Rule has |cffffff00EXPIRED|r.")
							table.remove(ruleset.order, i)
						else
							rule.expire = rule.expire - 1
							dprintf("        Rule will expire. Expire '%d'", rule.expire)
						end
					end
					
					-- If this is a deny rule, then this message is spam.
					return rule.action == DENY
				-- If the rule returned nil, then it is invalid.
				elseif match == nil then -- Must explicitly test for nil!
					dprintf("    Rule %d '%s' is |cffff0000INVALID|r.", i, name)
					-- If the rule is set to invalidate then it should be removed from further tests.
					if rule.invalidate then
						table.remove(ruleset.order, i)
						i = i - 1
						dprintf("        Rule has been |cffffff00REMOVED|r.")
					end
				else
					-- If the rule returned false, then there is no match and the message is not spam.
					dprintf("    Rule %d '%s' does not match. Result '%s'", i, name, tostring(match))
				end
			else
				dprintf("    Rule %d '%s' is |cff888888DISABLED|r.", i, name)
			end
		end
	end
end

function StopTheSpam:Release()
	dprintf("Unhooking the filters")
	
	self:Unhook(ChatFrame1, "AddMessage")
	self:Unhook(ChatFrame2, "AddMessage")
	
	self.frame:SetScript("OnEvent", nil)
	
	-- Discard anything that is no longer needed.
	self.frame = nil
	self.ruleset = nil
	self.Initialize = nil
	self.AddMessage = nil
	self.IsMessageSpam = nil
	self.Release = nil
	
	dprintf = nil
end

--[[ ------------------------------------------------------------------------ ]]

StopTheSpam:Initialize()

--[[ ------------------------------------------------------------------------ ]]
