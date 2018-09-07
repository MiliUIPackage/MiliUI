-- Credits to Tukz (ripped from Tukui)

local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end

local L = Engine.Locales

-- Communicate to other players through our AddOn
local LocalVersion = GetAddOnMetadata(ADDON_NAME, "Version")
local PlayerName = select(1, UnitName("player"))
local MessagePrefix = "CMVersion"
local SendAddonMessage = SendAddonMessage

local registered = nil

--
local function CheckVersion(self, event, prefix, message, channel, sender)
--print("CheckVersion:"..tostring(event).."  "..tostring(prefix).."  "..tostring(message).."  "..tostring(channel).."  "..tostring(sender))
	if event == "CHAT_MSG_ADDON" then
--print("CHAT_MSG_ADDON:"..tostring(sender).."  "..tostring(message).."  "..tostring(prefix))
		if (prefix ~= MessagePrefix) or (sender == PlayerName) then
			return
		end
		if (Engine.CompareVersion(LocalVersion, message) == 1 ) then -- We received a higher version, we're outdated. :(
			print("|cffffff00"..L.classmonitor_outdated.."|r")
			self:UnregisterEvent("CHAT_MSG_ADDON")
		end
	elseif registered == true then
--print("OK")
		-- Tell everyone what version we use.
		if (not IsInGroup(LE_PARTY_CATEGORY_HOME)) or (not IsInRaid(LE_PARTY_CATEGORY_HOME)) then
--print("1")
			C_ChatInfo.SendAddonMessage(MessagePrefix, LocalVersion, "INSTANCE_CHAT")
		elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
--print("2")
			C_ChatInfo.SendAddonMessage(MessagePrefix, LocalVersion, "RAID")
		elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
--print("3")
			C_ChatInfo.SendAddonMessage(MessagePrefix, LocalVersion, "PARTY")
		elseif IsInGuild() then
--print("4")
			C_ChatInfo.SendAddonMessage(MessagePrefix, LocalVersion, "GUILD")
		end
	end
end

local ClassMonitorVersionFrame = CreateFrame("Frame")
ClassMonitorVersionFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
ClassMonitorVersionFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
ClassMonitorVersionFrame:RegisterEvent("CHAT_MSG_ADDON")
ClassMonitorVersionFrame:SetScript("OnEvent", CheckVersion)

registered = C_ChatInfo.RegisterAddonMessagePrefix(MessagePrefix)
-- if registered is not true, we cannot send message because prefix has not been registered