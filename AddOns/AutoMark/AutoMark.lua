-------------------------------------------------------------------------------
-- AutoMark v1.1.8
-- ===============
--
--	Auto Mark
--
--------------------------------------------------------------------------------

local addonName, MyAddon = ...

SLASH_AUTOMARK1 = "/automark"
SLASH_AUTOMARK2 = "/am"

local Frame = CreateFrame("Frame")

local Mobs = {}
local Icons = {}
local PlayerMarks = {}
local MaxNameplates = 40
local PlayerName
local RealmName
local PlayerGUID
local ExpiryTime = 120
local Active = false
local Marker = false
local InstanceName
local InstanceType
local InstanceID
local MarkerGUID = "-"
local MarkerName = "-"
local GroupDetails = {}
local InfoFrame
local StatusFrame
local WAPrefix = "MYTHICAUTOMARK"
local Hold = false
local ShowGUIDs = false
local StatusIcons = false
local Debug = false
local MobInstance
local MobsLoaded = 0
local msgErrors = 0
local Scan = false

local SoundFiles = {
	update	=	{id=567489, t=0},
	remark	=	{id=567422, t=0},
	nofree	=	{id=567432, t=5},
}

-- Update mark table for any marked mob (not just those in Mobs).
-- Could cause problems with mobs marked by DBM!
local UpdateTableForAllMarked = false

-- Restore missing mark for all (not just those in Mobs).
-- Note that this causes multiple attempts(!) until the mark has actually been placed.
-- Could cause problems with mobs marked by DBM!
ReMarkAll = false

local TestMode = false	-- Show group members as online and send dummy replies to REQUEST_INFO.
local TestParty = false	-- Add dummy group members from TestPartyData.

local TestPartyData = {
	["Player-0001-00000001"] = {unit = "party2",name="Test1-Server1",online=true,role="TANK",leader=false},
}

local Marks = {
	[1] = {active = false, color = "Yellow", shape = "Star", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t"},
	[2] = {active = false, color = "Orange", shape = "Circle", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t"},
	[3] = {active = false, color = "Purple", shape = "Diamond", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t"},
	[4] = {active = false, color = "Green", shape = "Triangle", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t"},
	[5] = {active = false, color = "White", shape = "Moon", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t"},
	[6] = {active = false, color = "Blue", shape = "Square", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t"},
	[7] = {active = false, color = "Red", shape = "Cross", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t"},
	[8] = {active = false, color = "White", shape = "Skull", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t"},
}

-- Events registered when enabled.
local MainEvents = {	
"GROUP_ROSTER_UPDATE",
"CHAT_MSG_ADDON",
"READY_CHECK",
"PARTY_MEMBER_ENABLE",
"CHALLENGE_MODE_START",
"GROUP_LEFT",
"GROUP_JOINED",
}

-- Events registered when active.
local ActiveEvents = {
"UPDATE_MOUSEOVER_UNIT",
"PLAYER_REGEN_ENABLED",
"COMBAT_LOG_EVENT_UNFILTERED",
"MODIFIER_STATE_CHANGED",
"NAME_PLATE_UNIT_ADDED",
"UNIT_THREAT_LIST_UPDATE",
}

local GUIDs = {}

--------------------------------------------------------------------------------
function MyAddon.Init()

if AutoMark_DB == nil then AutoMark_DB = {} end

if AutoMark_Mobs == nil then AutoMark_Mobs = {} end
if AutoMark_DB.enabled == nil then AutoMark_DB.enabled = true end
if AutoMark_DB.markerIndicator == nil then AutoMark_DB.markerIndicator = true end
if AutoMark_DB.vip == nil then AutoMark_DB.vip = false end
if AutoMark_DB.sounds == nil then AutoMark_DB.sounds = false end
if AutoMark_DB.reMark == nil then AutoMark_DB.reMark = true end
if AutoMark_DB.updateMarked == nil then AutoMark_DB.updateMarked = true end
if AutoMark_DB.verbose == nil then AutoMark_DB.verbose = false end
if AutoMark_DB.playerMarks == nil then AutoMark_DB.playerMarks = {} end

for _,k in ipairs({"TANK","HEALER"}) do
	PlayerMarks[k] = AutoMark_DB.playerMarks[k] or MyAddon.PlayerMarks[k]
end

MyAddon.InitMinimapIcon(AutoMark_DB)

MyAddon.UpdateIcon()

if AutoMark_DB.icons then
	Icons =  AutoMark_DB.icons
else
	Icons = MyAddon.Icons
end

StatusFrame = MyAddon.CreateStatusFrame()

end
--------------------------------------------------------------------------------
function MyAddon.Message(...)

print("|cff00ff00" .. addonName .. "|r",...)

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.Debug(...)

if Debug then
	print("|cffff0000" .. addonName .. "|r",...)
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.UpdateIcon()

local icon

if not AutoMark_DB.enabled then
	MyAddon.UpdateMinimapIcon(icon,0.5,0.5,0.5)
	return
end

if Marker then
	if Hold then
		MyAddon.UpdateMinimapIcon(icon,1,0,0)
	else
		if Scan then
			MyAddon.UpdateMinimapIcon(icon,1,0,1)
		else
			MyAddon.UpdateMinimapIcon(icon,1,1,1)
		end
	end
else
	MyAddon.UpdateMinimapIcon(icon,0.25,0.78,0.92)
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.ShowMob(id,data,hideInstance)

if not data then
	return
end

print("ID:",id,"Name:",data.name)

for a,v in pairs(data) do
	local show = true
	if a == "name" or (a =="instanceID" and hideInstance) then
		show = false
	end	
	if show then
		local buffer = ""
		if a == "marks" then
			for c in string.gmatch(v,"%d") do
			local n = tonumber(c)
				buffer = buffer .. Marks[n].icon
			end
		end
		if buffer ~= "" then buffer = "(" .. buffer .. ")" end
		print("  ",a,"=",v,buffer)
	end
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.LoadMob(id,data)

if not data then
	Mobs[id] = nil
	return
end

if data.instanceID ~= nil and data.instanceID ~= 0 and data.instanceID ~= InstanceID then return end

Mobs[id] = {}

for a,v in pairs(data) do
		Mobs[id][a] = v
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.LoadMobs()

if not Active then return end

Mobs = {}

for id,data in pairs(MyAddon.Mobs) do
	MyAddon.LoadMob(id,data)
end

for id,data in pairs(AutoMark_Mobs) do
	MyAddon.LoadMob(id,data)
end

local n = 0
local c = 0

for id,data in pairs(Mobs) do
	n = n + 1
	if data.custom then
		c = c + 1
	end
end

if c > 0 then
	MyAddon.Message("小怪：",n,"(" .. c .. ")")
else
	MyAddon.Message("小怪：",n)
end

MobsLoaded = n

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.PlaySound(key)

if not AutoMark_DB.sounds or not key or not SoundFiles[key] then return end

local data = SoundFiles[key]

if not data.timer then data.timer = 0 end

if GetTime() - data.timer > data.t then
	PlaySoundFile(data.id,"Master")
	data.timer = GetTime()
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.CreateStatusFrame()

local frame = CreateFrame("Frame",addonName .. "StatusFrame",UIParent)

frame.texture = frame:CreateTexture()
frame.texture:SetAllPoints(frame)
frame.texture:SetColorTexture(0,0.5,0,1)
frame.texture:Hide()

frame:SetFrameStrata("DIALOG")
frame:SetWidth(130)
frame:SetHeight(35)
frame:SetPoint("TOP",UIParent)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton","RightButton")

frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

frame.head = frame:CreateFontString(nil, nil, "GameFontNormal")
frame.head:SetPoint("BOTTOM",frame,"TOP")
frame.head:SetText(addonName .. " 狀態")
frame.head:Hide()

frame.text = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
frame.text:SetPoint("BOTTOM",frame,"BOTTOM")

frame.icons = CreateFrame("Frame",nil,frame)
frame.icons:SetWidth(130)
frame.icons:SetHeight(18)
frame.icons:SetPoint("TOP")

frame.icons.t = frame.icons:CreateTexture(nil,"BACKGROUND")
frame.icons.t:SetAllPoints(frame.icons)
frame.icons.t:SetColorTexture(0,0,0,0.5)

frame.icon = {}

for i = 1,8 do
	frame.icon[i] = frame.icons:CreateTexture(nil,"ARTWORK")
	frame.icon[i]:SetSize(16,16)
	frame.icon[i]:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i)
	if i == 1 then
		frame.icon[i]:SetPoint("TOPLEFT",frame.icons,"TOPLEFT")
	else
		frame.icon[i]:SetPoint("LEFT",frame.icon[i-1],"RIGHT")
	end
	frame.icon[i]:SetAlpha(0.2)
end

if not StatusIcons then
	frame.icons:Hide()
	frame:SetHeight(15)
end

return frame

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.CreateInfoFrame()

local frame = CreateFrame("Frame",addonName .. "InfoFrame",UIParent,BackdropTemplateMixin and "BackdropTemplate")

frame:Hide()

frame:SetFrameStrata("DIALOG")
frame:SetWidth(400)
frame:SetHeight(150)
frame:SetPoint("LEFT",UIParent)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton","RightButton")
frame:EnableMouse(true)

frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
				edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 4, right = 4, top = 4, bottom = 4 }})

frame:SetBackdropColor(0,0,0,1)

frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frame:SetScript("OnShow", function(self) self.TimeSinceLastUpdate = self.UpdateInterval end)

frame:SetScript("OnUpdate",
	function(self,elapsed)
		self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed
		if self.TimeSinceLastUpdate < self.UpdateInterval then return end
		self.TimeSinceLastUpdate = 0
		local buffer = ""
		for _, i in ipairs({1,2,3,4,5,6,7,8}) do
			local t = ""
			local n = 0
			if Marks[i].time then
				n = Marks[i].time - GetTime()
				if n < 0 then n = 0 end
				t = string.format("%.0f",n)
			end
			if not Marks[i].active and Marks[i].guid == nil and Marks[i].time == nil then
				buffer = buffer .. Marks[i].icon .. "\n"
			else
				local c
				if n > 0 then
					c = GREEN_FONT_COLOR_CODE
				else
					c = RED_FONT_COLOR_CODE
				end
				local npcId = select(6, strsplit("-", Marks[i].guid))
				local spawnId = select(7, strsplit("-", Marks[i].guid))
				buffer = buffer .. Marks[i].icon .. " " .. c .. tostring(npcId) .. " " .. tostring(spawnId) .. " " .. tostring(Marks[i].name) .. " " .. tostring(t) ..
					FONT_COLOR_CODE_CLOSE .. "\n"
			end
		end
		if ShowGUIDs then
			for k,v in pairs(GUIDs) do
				buffer = buffer .. "\n" .. k .. " = " .. v
			end
		end
		self.text:SetText(buffer)
	end)

frame.Close = CreateFrame("Button",nil,frame)
frame.Close:SetHeight(32)
frame.Close:SetWidth(32)
frame.Close:SetPoint("TOPRIGHT",-5,-5)
frame.Close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
frame.Close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
frame.Close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight","ADD")
frame.Close:SetScript("OnClick", function(self) self:GetParent():Hide() end)

frame.head = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
frame.head:SetWidth(500)
frame.head:SetPoint("TOPLEFT",frame,10,-15)
frame.head:SetJustifyH("LEFT")
frame.head:SetText(addonName)
	
frame.text = frame:CreateFontString(nil, nil, "GameFontNormal")
frame.text:SetWidth(1000)
frame.text:SetPoint("TOPLEFT",frame.head,"BOTTOMLEFT",0,-10)
frame.text:SetJustifyH("LEFT")

frame.UpdateInterval = 0.1

return frame

end
--------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SetActive(v)

if v then
	Active = true
	MyAddon.LoadMobs()
	MyAddon.SetHold(false)
	StatusFrame:Show()
	MyAddon.ActiveEvents(true)
else
	Active = false
	MyAddon.SetHold(false)
	StatusFrame:Hide()
	MyAddon.ActiveEvents(false)
end

MyAddon.UpdateIcon()

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SetHold(v,announce)

Hold = v

if Hold then
	StatusFrame.text:SetText(RED_FONT_COLOR_CODE .. "** ON HOLD **" .. FONT_COLOR_CODE_CLOSE)
else
	StatusFrame.text:SetText("")
end

MyAddon.UpdateIcon()

if announce then
	local text
	if Hold then
		text = "HOLD"
		MyAddon.Message("HOLD")
	else
		text = "Resume"
		MyAddon.Message("RESUME")
	end
	if AutoMark_DB.sounds then
		C_VoiceChat.SpeakText(0, text, Enum.VoiceTtsDestination.LocalPlayback, 0, 100)
	end
end
	
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.Initialize()

-- Called on PLAYER_ENTERING_WORLD.

local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()

if IsInInstance() then
	InstanceName = name
	InstanceType = instanceType
	InstanceID = instanceID
	if InstanceName == nil then
		InstanceName = "UNKNOWN"
	end
	if InstanceID == nil then
		InstanceID = 0
	end
		if AutoMark_DB.enabled and instanceType == "party" then
			MyAddon.SetActive(true)
		end
else
	InstanceName = nil
	InstanceID = nil
	MyAddon.SetActive(false)
end

MyAddon.ResetMarks()

MyAddon.UpdatePartyFrames()

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.GetChatType()

if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
	return "INSTANCE_CHAT"
else
	if IsInRaid() then
		return "RAID"
	else
		return "PARTY"
	end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SendAddonMessage(subEvent,msg,name,guid)

if msg == nil then msg = "" end

local namex = PlayerName
local guidx = PlayerGUID

if name ~= nil then namex = name end
if guid ~= nil then guidx = guid end

local buffer = subEvent .. "^" .. namex .. "^" .. guidx .. "^" .. msg

if IsInGroup() then
	local success = C_ChatInfo.SendAddonMessage(addonName,buffer,MyAddon.GetChatType())
	if not success then
		msgErrors = msgErrors + 1
		MyAddon.Debug("FAILED TO SEND ADDON MESSAGE")
	end
else
	if AutoMark_DB.enabled then
		MyAddon.ChatMessageAddon(addonName,buffer,MyAddon.GetChatType(),namex)
	end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.RequestPlayerInfo()

MyAddon.SendAddonMessage("REQUEST_INFO")

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SendPlayerInfo()

local status = "1"

if AutoMark_DB.vip then
	status = "2"
end

if not AutoMark_DB.enabled then status = "0" end

MyAddon.SendAddonMessage("PLAYER_INFO",status)

MyAddon.SendWAInfo()

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SendTestPlayerInfo()

for k,v in pairs(GroupDetails) do
	if k ~= PlayerGUID then
		MyAddon.Message("TEST",k,v.name)
		v.online = true
		MyAddon.SendAddonMessage("PLAYER_INFO","1",v.name,k)
	end
end
	
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.UpdatePlayerMarks()

if IsInRaid() then return end

local tank
local healer

for i = 0, 4 do

	local unit
	
	if i == 0 then unit = "player" else unit = "party" .. i end
	
	if UnitExists(unit) then
		local role = UnitGroupRolesAssigned(unit)
--		MyAddon.Debug(i,"UNIT",unit,UnitName(unit),role)
		if role == "TANK" then
			if not tank then tank = unit end
		elseif role == "HEALER" then
			if not healer then healer = unit end
		else
			SetRaidTarget(unit,0)
		end
	end
end

if tank then
--	MyAddon.Debug("TANK:",tank)
	if PlayerMarks["TANK"] > 0 then
		SetRaidTarget(tank,PlayerMarks["TANK"])
	end
end

if healer then
--	MyAddon.Debug("HEALER:",healer)
	if PlayerMarks["HEALER"] > 0 then
		SetRaidTarget(healer,PlayerMarks["HEALER"])
	end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.IsNameplateVisble(guid)

for i = 1, MaxNameplates, 1 do 
	if guid == UnitGUID("nameplate"..i) then
		return true
	end
end

end
-------------------------------------------------------------------------------
		
-------------------------------------------------------------------------------
function MyAddon.GetNpcIdFromGUID(guid)

if not guid then return end

local npcId = select(6, strsplit("-", guid))

return tonumber(npcId)

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.ResetMark(i)

if Marks[i].active then
	-- MyAddon.Debug(Marks[i].icon,"RESET") end
end

if Marks[i].guid then
	GUIDs[Marks[i].guid] = nil
end

Marks[i].active = false
Marks[i].guid = nil
Marks[i].time = nil
Marks[i].force = nil
Marks[i].name = nil
Marks[i].duration = nil
Marks[i].timeSet = nil

StatusFrame.icon[i]:SetAlpha(0.2)
	
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.ResetMarks()

for i = 1,8 do
	MyAddon.ResetMark(i)
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.GetMark(data)

-- Ignores Tank and Healer marks.
-- Ignores Active marks unless they've expired.

local m

local force = false
local x = false

if data.marks then
	if string.find(data.marks,"^\+") then
		force = true
	end
	if string.find(data.marks,"^\!") then
		force = true
		x = true
	end
	for c in string.gmatch(data.marks,"%d") do
		local i = tonumber(c)
		if PlayerMarks["TANK"] ~= i and PlayerMarks["HEALER"] ~= i then
			if force then
				if x or not Marks[i].force then
					m = i
					break
				end
			end
			if not Marks[i].active or GetTime() > Marks[i].time then
				m = i
				break
			end
		end
	end
end

if m then return m end

-- Only use supplied marks if * found.
if data.marks and string.find(data.marks,"^\*") then
	return
end

for _,i in ipairs(Icons) do

	if PlayerMarks["TANK"] ~= i and PlayerMarks["HEALER"] ~= i and (not Marks[i].active or GetTime() > Marks[i].time) then
		m = i
		break
	end

end

return m

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.UnitMark(unit)

return GetRaidTargetIndex(unit)

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.MobMark(guid)

return GUIDs[guid]

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.UnitDied(guid,name)

-- MyAddon.Debug("UNIT_DIED",name,InCombatLockdown())

if GUIDs[guid] then
	-- MyAddon.Debug(Marks[i].icon,"UNIT_DIED",Marks[i].name)
	MyAddon.ResetMark(GUIDs[guid])
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SetMark(m,guid,name,time,force,tag)

if Marks[m].guid then
	GUIDs[Marks[m].guid] = nil
end

local e = time or ExpiryTime

Marks[m].timeSet = GetTime()
Marks[m].active = true
Marks[m].guid = guid
Marks[m].time = GetTime() + e
Marks[m].force = force
Marks[m].name = name
Marks[m].duration = e

GUIDs[guid] = m

StatusFrame.icon[m]:SetAlpha(1)

if tag == "update" then
	MyAddon.Message(Marks[m].icon,"UPDATE",Marks[m].name)
end

MyAddon.PlaySound(tag)

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SetRaidTarget(unit,iconId,tag)

SetRaidTarget(unit,iconId)

if tag == "remark" then
	Marks[iconId].timeSet = GetTime()
	MyAddon.Message(Marks[iconId].icon,"RE-MARKED",Marks[iconId].name)
-- elseif tag == "mark" then
	-- MyAddon.Debug(Marks[iconId].icon,"MARKED",Marks[iconId].name)
end

MyAddon.PlaySound(tag)

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.MarkUnit(unit,guid,data)

local currentMark = MyAddon.UnitMark(unit)

local mobMark = MyAddon.MobMark(guid)

local name = UnitName(unit)

local force = false

if data.marks and (string.find(data.marks,"^\+") or string.find(data.marks,"^\!")) then
	force = true
end

if currentMark then
-- Unit is already marked.
	if AutoMark_DB.updateMarked and (data.time == nil or data.time >= 0) then
		if mobMark then
			if mobMark ~= currentMark then
				MyAddon.ResetMark(mobMark)
				MyAddon.SetMark(currentMark,guid,name,data.time,force,"update")
			end
		else
			MyAddon.SetMark(currentMark,guid,name,data.time,force,"update")
		end
	end
	return
end

if mobMark then
-- Mob is flagged as marked but hasn't got a mark.
	if AutoMark_DB.reMark then
		local n = GetTime() - Marks[mobMark].timeSet
		if n >= 1 then	
			MyAddon.SetRaidTarget(unit,mobMark,"remark")
		end
	end
	return
end

local m = MyAddon.GetMark(data,guid)

if m == nil then
-- No free mark.
	MyAddon.PlaySound("nofree")
	return
end

--MyAddon.Debug("USE MARK",m)

if data.time == nil or data.time >= 0 then
	MyAddon.SetMark(m,guid,name,data.time,force,"set")
end

MyAddon.SetRaidTarget(unit,m,"mark")

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.UnmarkUnit(unit,guid)

if GUIDs[guid] then
	MyAddon.ResetMark(GUIDs[guid])
end

SetRaidTarget(unit,0)
		
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.RemoveAllMarks()

local role = UnitGroupRolesAssigned("player") or "NONE"

for i = 1,8 do
	SetRaidTarget("player", i)
end

if not Active or PlayerMarks[role] == nil or PlayerMarks[role] == 0 or IsInRaid() then
	if IsInGroup() then
		C_Timer.After(1, function() SetRaidTarget("player", 0) end)
	else
		SetRaidTarget("player", 0)
	end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SendWAInfo()

if not IsInGroup() then return end

local role = UnitGroupRolesAssigned("player") == "NONE" and select(5, GetSpecializationInfo(GetSpecialization())) or UnitGroupRolesAssigned("player")
local isLeader = UnitIsGroupLeader("player")
local seasonScore = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player").currentSeasonScore
local shouldMarkMobs = true
local shouldMarkPlayers = true

local message = string.format("%s:%s:%s:%s:%s",role,tostring(shouldMarkMobs),tostring(shouldMarkPlayers),tostring(isLeader),tostring(seasonScore))

local success = C_ChatInfo.SendAddonMessage(WAPrefix,"DECIDE_MARKER^"..message,MyAddon.GetChatType())

if not success then
	msgErrors = msgErrors + 1
	MyAddon.Debug("FAILED TO SEND WA ADDON MESSAGE")
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.ChatMessageAddon(prefix,text,channel,sender)

-- Send reply to WA!
if prefix == WAPrefix then
	if sender ~= PlayerName then
		MyAddon.Debug("MSG",prefix,text,channel,sender)
	end
	local subEvent, msg = strsplit("^", text)
	if subEvent == "UPDATE_PLAYER" then
		MyAddon.SendWAInfo()
	end
	return
end

if prefix ~= addonName then
	return
end

local subEvent, name, guid, msg = strsplit("^", text)

-- MyAddon.Debug("++",name,guid,subEvent,msg,sender)

if subEvent == "REQUEST_INFO" then
	MyAddon.SendPlayerInfo()
	if TestMode then
		MyAddon.SendTestPlayerInfo()
	end
	return
end

--	Only update an existing entry in group.
if subEvent == "PLAYER_INFO" then
	if GroupDetails[guid] then
		GroupDetails[guid].auto = msg
		MyAddon.GetMarker()
		return
	end
end

end

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SetMarker(guid,name)

--MyAddon.Debug("Set Marker:",name,guid)

if MarkerGUID == guid then
	-- MyAddon.Debug("Marker is still", MarkerName)
	if Active and Marker then
		MyAddon.UpdatePlayerMarks()
	end
	return
end

MarkerGUID = guid
MarkerName = name

if MarkerGUID == nil then
	MyAddon.Debug("No Marker")
else
	if PlayerGUID == guid then
		MyAddon.Debug("You're Marker")
	else
		MyAddon.Debug("Marker is",MarkerName)
	end
end

if PlayerGUID == guid then
	Marker = true
else
	Marker = false
end

MyAddon.UpdateIcon()

MyAddon.UpdatePartyFrames()

if Active and Marker then
	MyAddon.UpdatePlayerMarks()
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.ShowTooltip(frame)

local verbose = true

if not AutoMark_DB.verbose then
	if frame then
		local name = frame:GetName()
		if name and string.find(name,"^LibDBIcon") then
			verbose = false
		end
	end
end

local c
local b

GameTooltip:SetOwner(frame,"ANCHOR_LEFT")

GameTooltip:SetText("自動標記")

local version = C_AddOns.GetAddOnMetadata(addonName,"Version")
GameTooltip:AddLine(version,1,1,1)

if AutoMark_DB.enabled then
	GameTooltip:AddLine("啟用",0,1,0)
else
	GameTooltip:AddLine("禁用",1,0,0)
end

GameTooltip:AddLine(" ",1,1,1)

if verbose then
	GameTooltip:AddLine("玩家名字：" .. tostring(PlayerName),1,1,1)
	GameTooltip:AddLine("玩家GUID：" .. tostring(PlayerGUID),1,1,1)
end

if Active then
	c = GREEN_FONT_COLOR_CODE
else
	c = ORANGE_FONT_COLOR_CODE
end

b = InstanceName or "無"

if InstanceID then
	b = b .. " (" .. InstanceID .. ")"
	if InstanceType then
		b = b .. " (" .. InstanceType .. ")"
	end
end

GameTooltip:AddLine("副本：" .. c .. b .. FONT_COLOR_CODE_CLOSE,1,1,1)

if Marker then
	c = GREEN_FONT_COLOR_CODE
else
	c = ORANGE_FONT_COLOR_CODE
end

GameTooltip:AddLine("標記者：" .. c .. tostring(MarkerName) .. FONT_COLOR_CODE_CLOSE,1,1,1)

if Active then
	GameTooltip:AddLine("啟用：" .. tostring(Active) .. " (" .. tostring(MobsLoaded) .. ")",1,1,1)
else
	GameTooltip:AddLine("啟用：" .. tostring(Active),1,1,1)
end

if AutoMark_DB.vip then
	GameTooltip:AddLine("VIP: " .. tostring(AutoMark_DB.vip),1,1,1)
end

if AutoMark_DB.modify then
	GameTooltip:AddLine("Modify: " .. tostring(AutoMark_DB.modify),1,1,1)
end

if verbose then

	if AutoMark_DB.enabled then
		GameTooltip:AddLine(" ",1,1,1)
		for _,role in ipairs({"TANK","HEALER"}) do
			if PlayerMarks[role] and PlayerMarks[role] ~= 0 then
				GameTooltip:AddLine(Marks[PlayerMarks[role]].icon .. " " .. role,1,1,1)
			end
		end
		GameTooltip:AddLine(" ",1,1,1)
		for _, i in ipairs(Icons) do
			local t
			if Marks[i].time then
				local n = Marks[i].time - GetTime()
				if n < 0 then n = 0 end
				t = string.format("%.0f",n)
			end
			local buffer = Marks[i].icon .. " " .. tostring(Marks[i].name) .. " " .. tostring(t)
			if not Marks[i].active and Marks[i].guid == nil and Marks[i].time == nil then
				buffer = Marks[i].icon
			end
			GameTooltip:AddLine(buffer,1,1,1)
		end
	end

end

if verbose then

	GameTooltip:AddLine(" ",1,1,1)

	for k,v in pairs(GroupDetails) do
		local r,g,b = 1,1,1
		local status = "Online"
		if not v.online then
			status = "Offline"
			r,g,b = 0.5,0.5,0.5
		end
		local lead = "  "
		if v.leader then lead = "*" end
		if k == MarkerGUID then r,g,b = 0,1,0 end
		GameTooltip:AddLine(lead .." " .. k .. " " .. tostring(v.unit) .. " " .. tostring(v.name) .. " " ..status .. " " ..
			tostring(v.role) .. " " .. tostring(v.auto),r,g,b)
	end

end

if Hold then
	GameTooltip:AddLine(" ",1,1,1)
	GameTooltip:AddLine("** ON HOLD **",1,0,0)
end

GameTooltip:AddLine(" ",1,1,1)

if Active and Marker then
	GameTooltip:AddLine("左鍵-點擊 來清除標記",0.25,0.78,0.92)
	if AutoMark_DB.advancedMode then
		GameTooltip:AddLine("Ctrl-左鍵-點擊 來顯示資訊",0.25,0.78,0.92)
		if Hold then
			GameTooltip:AddLine("Alt-左鍵-點擊 來恢復",0.25,0.78,0.92)
		else
			GameTooltip:AddLine("Alt-左鍵-點擊 來保留",0.25,0.78,0.92)
		end
	end
end

if Active then
	GameTooltip:AddLine("中鍵-點擊 來重載小怪",0.25,0.78,0.92)
end

if AutoMark_DB.enabled then
	GameTooltip:AddLine("右鍵-點擊 來禁用",0.25,0.78,0.92)
else
	GameTooltip:AddLine("右鍵-點擊 來啟用",0.25,0.78,0.92)
end

GameTooltip:Show()

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.GetMarker()

local guid
local name

--MyAddon.Debug("Looking for marker.")

if not IsInGroup() then
	guid = PlayerGUID
	name = PlayerName
	MyAddon.SetMarker(guid,name)
	return
end

local keys = {}

for k,v in pairs(GroupDetails) do
	if v.unit and v.online then
		table.insert(keys,k)
	end
end

table.sort(keys)

local priority = {}

for _, k in ipairs(keys) do
	if GroupDetails[k].auto == "1" or GroupDetails[k].auto == "2" then
		if GroupDetails[k].role == "TANK" then
			if GroupDetails[k].leader == true then
-- TANK LEADER
				priority[k] = 5
			else
-- TANK
				priority[k] = 6
			end
		elseif GroupDetails[k].leader == true then
-- LEADER
			priority[k] = 7
		else
-- OTHER
			priority[k] = 8
		end
	end
	if GroupDetails[k].auto == "2" then	-- VIP
		priority[k] = priority[k] - 4
	end
end

local p
local key

for k, v in pairs(priority) do
	if p == nil or v < p then
		p = v
		key = k
	end
end

if key then
	guid = key
	name = GroupDetails[key].name
end

MyAddon.SetMarker(guid,name)

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.GetGroupDetails()

if not IsInGroup() then
	GroupDetails = {}
else
	for k,v in pairs(GroupDetails) do
		GroupDetails[k].unit = nil
	end
end

local maxMembers = 5

if IsInRaid() then maxMembers = 40 end

for i = 1,maxMembers do

	local unit

	if IsInRaid() then
		unit = "raid" .. i
	else
		if i == 1 then
			unit = "player"
		else
			unit = "party" .. i-1
		end
	end

	local guid = UnitGUID(unit)
	
	if guid then
		local name, realm = UnitName(unit)
		if name ~= nil then
			if realm == nil or realm == "" then
				name = name .. "-" .. RealmName
			else
				name = name .. "-" .. realm
			end
		end
		local leader = UnitIsGroupLeader(unit)
		local role = UnitGroupRolesAssigned(unit)
		local isOnline = UnitIsConnected(unit)
		if TestMode then isOnline = true end
		if not GroupDetails[guid] then GroupDetails[guid] = {} end
		GroupDetails[guid].unit = unit
		GroupDetails[guid].name = name
		GroupDetails[guid].online = isOnline
		GroupDetails[guid].role = role
		GroupDetails[guid].leader = leader
	end
	
end

if IsInGroup() then
	if not IsInRaid() and TestParty then
		for k,v in pairs(TestPartyData) do
			if not GroupDetails[k] then GroupDetails[k] = {} end
			GroupDetails[k].unit = v.unit
			GroupDetails[k].name = v.name
			GroupDetails[k].online = v.online
			GroupDetails[k].role = v.role
			GroupDetails[k].leader = v.leader
		end
	end
end

-- Clean up
for k,v in pairs(GroupDetails) do
	if GroupDetails[k].unit == nil then
		GroupDetails[k] = nil
	end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.MainEvents(register)

for _,event in ipairs(MainEvents) do
	if register then
		Frame:RegisterEvent(event)
	else
		Frame:UnregisterEvent(event)
	end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.ActiveEvents(register)

for _,event in ipairs(ActiveEvents) do
	if register then
		Frame:RegisterEvent(event)
	else
		Frame:UnregisterEvent(event)
	end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.Enable(enable)

if enable then
	if AutoMark_DB.enabled then
		MyAddon.Message("已經啟用")
		return
	end
	MyAddon.MainEvents(true)
	AutoMark_DB.enabled = true
	MyAddon.UpdateIcon()
	MyAddon.Message("啟用")
	MyAddon.Initialize()
	MyAddon.GetGroupDetails()
	MyAddon.RequestPlayerInfo()
else
	if not AutoMark_DB.enabled then
		MyAddon.Message("已經啟用")
		return
	end
	MyAddon.SetActive(false)
	MyAddon.MainEvents(false)
	AutoMark_DB.enabled = false
	MyAddon.UpdateIcon()
	MarkerGUID = "-"
	MarkerName = "-"
	Marker = false
	GroupDetails = {}
	MyAddon.UpdatePartyFrames()
	MyAddon.SendPlayerInfo()
	MyAddon.ResetMarks()
	MyAddon.Message("已禁用")
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.SetAutoMarkIcon(name)

local frame = _G[name]

if not frame then return end

if not frame.AutoMarkIcon then
	frame.AutoMarkIcon = frame:CreateTexture()
	frame.AutoMarkIcon:SetTexture([[Interface\COMMON\FavoritesIcon.blp]])
	frame.AutoMarkIcon:SetSize(20,20)
	if name == "PlayerFrame" then
		frame.AutoMarkIcon:SetPoint("TOP",PlayerFrame.PlayerFrameContainer.PlayerPortrait,"BOTTOM",0,0)
	else
		frame.AutoMarkIcon:SetPoint("RIGHT",frame,"LEFT",0,0)
	end
end

if AutoMark_DB.markerIndicator and frame.unit and UnitGUID(frame.unit) == MarkerGUID then
	if name == "PlayerFrame" and IsInGroup() then
		frame.AutoMarkIcon:Hide()
	else
		frame.AutoMarkIcon:Show()
	end
	if Active then
		frame.AutoMarkIcon:SetVertexColor(0,1,0)	-- Green
	else
		frame.AutoMarkIcon:SetVertexColor(1,0.5,0)	-- Orange
	end
else
	frame.AutoMarkIcon:Hide()
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.UpdatePartyFrames()

for i = 1, 5 do
	MyAddon.SetAutoMarkIcon("CompactPartyFrameMember" .. i)
end

MyAddon.SetAutoMarkIcon("PlayerFrame")
	
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.AddCustomMob(unit)

local iid = InstanceID or 0
local name = UnitName(unit)
local guid = UnitGUID(unit)
local hostile = UnitIsEnemy("player",unit)
local attackable = UnitCanAttack("player",unit)
local level  = UnitLevel(unit)
local classification  = UnitClassification(unit)
local creatureType = UnitCreatureType(unit)
local powerType, powerTypeString = UnitPowerType(unit)

if not guid then
	return
end

local npcId = MyAddon.GetNpcIdFromGUID(guid)

-- Ignore Mystic Birdhat and Cousin Slowhands.
if npcId == 62821 or npcId == 62822 then
	return
end

-- Ignore Party
for i = 1,4 do
	if UnitIsUnit(unit,"party"..i) then
		return
	end
	if UnitIsUnit(unit,"party"..i.."pet") then
		return
	end
end

-- Ignore Nyx (Austin Huxworth's Pet)
if npcId == 209069 then
	return
end

local action = "ADD"

if AutoMark_Mobs[npcId] then
	action = "UPDATE"
end

-- MyAddon.Message(action,name)

if action == "UPDATE" then
	if attackable and not AutoMark_Mobs[npcId].attackable then
		MyAddon.Message("ATTACKABLE",name,npcId)
		PlaySound(130,"Master")
	end
	if not attackable and AutoMark_Mobs[npcId].attackable then
		attackable = true
	end
	if hostile and not AutoMark_Mobs[npcId].hostile then
		MyAddon.Message("HOSTILE",name,npcId)
		PlaySound(180,"Master")
	end
	if not hostile and AutoMark_Mobs[npcId].hostile then
		hostile = true
	end
end

AutoMark_Mobs[npcId] = {
	name = name,
	instanceID = InstanceID,
	custom = true,
	level = level,
	power = powerTypeString,
	classification = classification,
	creatureType = creatureType,
	attackable = attackable,
	hostile = hostile,
}

if action == "ADD" then
	MyAddon.Message(action,name,npcId)
	PlaySound(999,"Master")
	MyAddon.LoadMobs()
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.RemoveCustomMob(unit)

local guid = UnitGUID(unit)

if not guid then
	MyAddon.Message("單位無效。")
	return
end

local npcId = MyAddon.GetNpcIdFromGUID(guid)

if not AutoMark_Mobs[npcId] then
	MyAddon.Message("沒找到NPC。")
	return
end

local name = AutoMark_Mobs[npcId].name

MyAddon.Message("REMOVE",npcId,name)

AutoMark_Mobs[npcId] = nil

MyAddon.LoadMobs()

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function SlashCmdList.AUTOMARK(msg,editbox)

local words = {}

local cmd = ""

for word in msg:gmatch("%S+") do table.insert(words, word) end

if #words > 0 then
	cmd = words[1]
end

if cmd == nil then return end

if cmd == "minimap" then
	MyAddon.ToggleMinimapIcon()
	return
end

if cmd == "minimaplock" then
	MyAddon.ToggleLockMinimapIcon()
	return
end

if cmd == "enable" then
	MyAddon.Enable(true)
	return
end

if cmd == "disable" then
	MyAddon.Enable(false)
	return
end

if cmd == "toggle" then
	MyAddon.Enable(not AutoMark_DB.enabled)
	return
end

if cmd == "reset" then
	if not Active then
		return
	end
	if not Marker then
		MyAddon.Message("非標記者。")
		return
	end
	MyAddon.Message("重設標記")
	MyAddon.ResetMarks()
	return
end

if cmd == "clear" then
	if not Active then
		return
	end
	if not Marker then
		MyAddon.Message("非標記者。")
		return
	end
	MyAddon.Message("清除標記")
	MyAddon.RemoveAllMarks()
	MyAddon.ResetMarks()
	MyAddon.UpdatePlayerMarks()
	return
end

if cmd == "remove" then
	if not Active then
		return
	end
	if not Marker then
		MyAddon.Message("非標記者。")
		return
	end
	MyAddon.Message("移除標記")
	MyAddon.RemoveAllMarks()
	MyAddon.UpdatePlayerMarks()
	return
end

if cmd == "player" then
	MyAddon.Message("更新玩家標記")
	MyAddon.UpdatePlayerMarks()
	return
end

if cmd == "update" then
	MyAddon.Message("請求更新")
	MyAddon.RequestPlayerInfo()
	return
end

-- Toggle state of TestParty.
if cmd == "testparty" then
	TestParty = not TestParty
	MyAddon.Message("TestParty:",TestParty)
	MyAddon.GetGroupDetails()
	return
end

if cmd == "testmode" then
	TestMode = not TestMode
	MyAddon.Message("Test Mode:",TestMode)
	MyAddon.RequestPlayerInfo()
	return
end

if cmd == "errors" then
	MyAddon.Message("Errors:",msgErrors)
	return
end

-- Set all group members inactive.
if cmd == "testinactive" then
	for k,v in pairs(GroupDetails) do
		v.auto = "0"
	end
	MyAddon.GetGroupDetails()
	for k,v in pairs(GroupDetails) do
		MyAddon.SendAddonMessage("PLAYER_INFO",v.auto,v.name,k)
	end
	return
end

if cmd == "debug" then
	Debug = not Debug
	MyAddon.Message("Debug:",Debug)
	return
end

if cmd == "indicator" then
	AutoMark_DB.markerIndicator = not AutoMark_DB.markerIndicator
	MyAddon.Message("標記圖示：",AutoMark_DB.markerIndicator)
	MyAddon.UpdatePartyFrames()
	return
end

if cmd == "vip" then
	AutoMark_DB.vip = not AutoMark_DB.vip
	MyAddon.Message("VIP:",AutoMark_DB.vip)
	MyAddon.SendPlayerInfo()
	return
end

if cmd == "verbose" then
	AutoMark_DB.verbose = not AutoMark_DB.verbose
	MyAddon.Message("Verbose:",AutoMark_DB.verbose)
	return
end

if cmd == "advanced" then
	AutoMark_DB.advancedMode = not AutoMark_DB.advancedMode
	MyAddon.Message("進階模式：",AutoMark_DB.advancedMode)
	return
end

if cmd == "sounds" then
	AutoMark_DB.sounds = not AutoMark_DB.sounds
	MyAddon.Message("聲音：",AutoMark_DB.sounds)
	return
end

if cmd == "info" then
	if not InfoFrame then
		InfoFrame = MyAddon.CreateInfoFrame()
	end
	InfoFrame:Show()
	return
end

if cmd == "status" then
	StatusIcons = not StatusIcons
	if StatusIcons then
		StatusFrame:SetHeight(35)
		StatusFrame.icons:Show()
	else
		StatusFrame:SetHeight(15)
		StatusFrame.icons:Hide()
	end
	return
end

if cmd == "tank" or cmd == "healer" then
	local k = string.upper(cmd)
	if not words[2] then
		AutoMark_DB.playerMarks[k] = nil
		PlayerMarks[k] = MyAddon.PlayerMarks[k]
		local x
		if Marks[PlayerMarks[k]] then
			x = Marks[PlayerMarks[k]].icon
		else
			x = "NONE"
		end
		MyAddon.Message(k .. " 標記重置回預設 (" .. x .. ").")
	else
		local n = -1
		if words[2] then n = tonumber(words[2]) end
		if n >= 0 and n <= 8 then
			AutoMark_DB.playerMarks[k] = n
			PlayerMarks[k] = AutoMark_DB.playerMarks[k]
			MyAddon.Message(k .. " Mark:",Marks[PlayerMarks[k]].icon)
		else
			MyAddon.Message("無效值。")
		end
	end
	if Active and Marker then
		MyAddon.ResetMarks()
		MyAddon.UpdatePlayerMarks()
	end
	return
end

if cmd == "hold" then
	if Active and Marker then
		MyAddon.SetHold(not Hold,true)
	end
	return
end

if cmd == "extend" then
	if Active then
		for i = 1,8 do
			if Marks[i].active then
				Marks[i].time = GetTime() + Marks[i].duration
			end
		end
		MyAddon.Message("標記時間延展")
	end
	return
end

if cmd == "lock" then
	StatusFrame.texture:Hide()
	StatusFrame.head:Hide()
	StatusFrame:EnableMouse(false)
	MyAddon.Message("狀態框架鎖定")
	return
end

if cmd == "unlock" then
	StatusFrame.texture:Show()
	StatusFrame.head:Show()
	StatusFrame:EnableMouse(true)
	MyAddon.Message("狀態框架未鎖定")
	return
end

if cmd == "resetpos" then
	StatusFrame:ClearAllPoints()
	StatusFrame:SetPoint("TOP")
	MyAddon.Message("狀態框架位置重設")
	return
end

if cmd == "updatemarked" then
	AutoMark_DB.updateMarked = not AutoMark_DB.updateMarked
	MyAddon.Message("更新標記：",AutoMark_DB.updateMarked)
	return
end

if cmd == "remark" then
	AutoMark_DB.reMark = not AutoMark_DB.reMark
	MyAddon.Message("重新標記：",AutoMark_DB.reMark)
	return
end

if cmd == "modify" then
	AutoMark_DB.modify = not AutoMark_DB.modify
	MyAddon.Message("更改：",AutoMark_DB.modify)
	return
end

if cmd == "icons" then
	local data = words[2] or "0"
	local m = false
	local list = {false,false,false,false,false,false,false,false}
	local icons = {}
	for c in string.gmatch(data,"%d") do
		c = tonumber(c)
		if c and c >= 1 and c<= 8 then
			m = true
			if not list[c] then
				list[c] = true
				table.insert(icons,c)
			end
		end
	end
	if m then
		AutoMark_DB.icons = {}
		for _,v in ipairs(icons) do
			table.insert(AutoMark_DB.icons,v)
		end
		Icons =  AutoMark_DB.icons
	else
		AutoMark_DB.icons = nil
		Icons =  MyAddon.Icons
	end
	if AutoMark_DB.icons then
		local buffer = ""
		local icons = ""
		for i,n in ipairs(AutoMark_DB.icons) do
			icons = icons .. Marks[n].icon
			if i == 1 then
				buffer = buffer .. n
			else
				buffer = buffer .. "," .. n
			end
		end
		MyAddon.Message("圖示：",buffer,icons)
	else
		MyAddon.Message("預設圖示")
	end
	return
end

if cmd == "instance" then
	local n = tonumber(words[2])
	if not n then
		MyAddon.Message("Instance ID Invalid")
		return
	end
	MobInstance = n
	MyAddon.Message("Mob Instance:",MobInstance)
	return
end

if cmd == "mobs" then
	MyAddon.Message("Mobs")
	local n = 0
	for id, data in pairs(Mobs) do
		if data.instanceID == InstanceID then
			MyAddon.ShowMob(id,data,true)
			n = n + 1
		end
	end
	if n == 0 then print("NONE") end
	return
end

if cmd == "npc" then
	if words[2] == "find" then
		local pattern
		if words[3] then
			pattern = string.gsub(msg,"^%w+%s%w+%s","")
		else
			pattern = ""
		end
		MyAddon.Message("Custom Mobs Matching Pattern",pattern)
		local n = 0
		for id,v in pairs(AutoMark_Mobs) do
			if string.find(string.lower(v.name),string.lower(pattern),1,true) then
				n = n + 1
				print(id,v.name,v.instanceID)
			end
		end
		if n == 0 then print("NONE") end
		return
	end
	if words[2] == "list" then
		MyAddon.Message("Custom Mobs")
		local n = 0
		for id,v in pairs(AutoMark_Mobs) do
			n = n + 1
			print(id,v.name,v.instanceID)
		end
		if n == 0 then print("NONE") end
		return	
	end
	if words[2] == "removeall" then
		AutoMark_Mobs = {}
		MyAddon.Message("All NPC IDs Reset")
		MyAddon.LoadMobs()
		return		
	end
	local id
	local data
	if words[2] == "target" then
		local guid = UnitGUID("target")
		local name = UnitName("target")
		local npcId = MyAddon.GetNpcIdFromGUID(guid)
		id = npcId
		if action == "add" then
			data = name
		end
	else
		id = tonumber(words[2])
	end
	if id == nil then
		MyAddon.Message("NPC ID Missing")
		return
	end
	local action = words[3]
	local w4 = words[4]
	if w4 then
		data = string.gsub(msg,"^%w+%s+%w+%s+%w+%s+","")
	end
	if action == "add" or action == "name" then
		if not data and MyAddon.Mobs[id] then
			data = MyAddon.Mobs[id].name
		end
	end
	if action ~= "view" and action ~= "remove" then
		if not data then
			MyAddon.Message("Value Missing")
			return
		end
	end
	if action == "add" then
		if AutoMark_Mobs[id] then
			MyAddon.Message("NPC ID",id,"Already Exists")
			return
		end
		if not Active and not MobInstance then
			MyAddon.Message("Mob Instance Not Set")
			return		
		end
	else
		if not AutoMark_Mobs[id] then
			MyAddon.Message("NPC ID",id,"Not Found")
			return
		end
	end
	if action == "view" then
		MyAddon.ShowMob(id,AutoMark_Mobs[id])
		return
	elseif action == "add" then
		local iid = MobInstance or InstanceID
		if iid == 0 then iid = nil end
		AutoMark_Mobs[id] = {name = data, instanceID = iid, custom = true}
		if MyAddon.Mobs[id] then
			MyAddon.Message("NPC ID",id,"Override Added")
		else
			MyAddon.Message("NPC ID",id,"Added")
		end
	elseif action == "name" then
		AutoMark_Mobs[id].name = data
	elseif action == "instance" then
		local iid = tonumber(data)
		if iid == 0 then iid = nil end
		AutoMark_Mobs[id].instanceID = iid
	elseif action == "auto" then
		if data ~= "default" and data ~= "*mouseover" and data ~= "nameplate" and data ~= "never" and data ~= "nameplate" and data ~= "combat" then
			MyAddon.Message("Action Invalid")
			return
		end
		if data == "default" then data = nil end
		AutoMark_Mobs[id].auto = data
	elseif action == "time" then
		local n = tonumber(data)
		if n then
			AutoMark_Mobs[id].time = n
		else
			AutoMark_Mobs[id].time = nil
		end
	elseif action == "marks" then
		local m = false
		local list = {false,false,false,false,false,false,false,false}
		local icons = ""
		for c in string.gmatch(data,"%d") do
			c = tonumber(c)
			if c and c >= 1 and c<= 8 then
				m = true
				if not list[c] then
					list[c] = true
					icons = icons .. c
				end
			end
		end
		if string.find(data,"^\*") then
			icons = "*" .. icons
		end
		if string.find(data,"^\+") then
			icons = "+" .. icons
		end
		if string.find(data,"^\!") then
			icons = "!" .. icons
		end
		if m then
			AutoMark_Mobs[id].marks = icons
		else
			AutoMark_Mobs[id].marks = nil
		end
	elseif action == "remove" then
		AutoMark_Mobs[id] = nil
	else
		MyAddon.Message("Action Invalid")
		return
	end
	if action == "remove" then
		if MyAddon.Mobs[id] then
			MyAddon.Message("NPC ID",id,"Override Removed")
		else
			MyAddon.Message("NPC ID",id,"Removed")
		end
	else
		MyAddon.ShowMob(id,AutoMark_Mobs[id])
	end
	MyAddon.LoadMobs()
	return
end

if cmd == "addcustom" then
	if InstanceID == nil then
		MyAddon.Message("Instance ID not set.")
		return
	end
	MyAddon.AddCustomMob("target")
	return
end

if cmd == "removecustom" then
	MyAddon.RemoveCustomMob("target")
	return
end

if cmd == "removeallcustom" then
	if InstanceID == nil then
		MyAddon.Message("Instance ID not set.")
		return
	end
	for k, v in pairs(AutoMark_Mobs) do
		if v.instanceID == InstanceID then
			MyAddon.Message("REMOVE",k,v.name)
			AutoMark_Mobs[k] = nil
		end
	end
	MyAddon.LoadMobs()
	return
end

if cmd == "initcustom" then
	for k, v in pairs(AutoMark_Mobs) do
		MyAddon.Message("REMOVE",k,v.name)
		AutoMark_Mobs[k] = nil
	end
	MyAddon.LoadMobs()
	return
end

if cmd == "scan" then
	Scan = not Scan
	MyAddon.UpdateIcon()
	MyAddon.Message("Scan:",Scan)
	return
end

MyAddon.Message(
	"Usage:\n" .. 
	"/am minimap - 切換小地圖按鈕\n" ..
	"/am minimaplock - 切換小地圖按鈕鎖定\n" ..
	"/am indicator - 切換標記指示\n" ..
	"/am mobs - 顯示將被標記的小怪 (在地下城中)\n" ..
	"/am tank n - 更改坦克標記\n" ..
	"/am healer n - 更改治療者標記\n" ..
	"/am remark - 切換重新標記缺少功能\n" ..
	"/am updatemarked - 切換更新標記功能\n"
	)

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function AutoMark_OnAddonCompartmentClick(addonName,buttonName,menuButtonFrame)

if buttonName == "RightButton" then
	MyAddon.Enable(not AutoMark_DB.enabled)
	if GameTooltip:IsShown() then
		local f = GameTooltip:GetOwner()
		MyAddon.ShowTooltip(f)
	end
elseif buttonName == "MiddleButton" then
	MyAddon.Initialize()
	if AutoMark_DB.enabled then
		MyAddon.GetGroupDetails()
		MyAddon.RequestPlayerInfo()
	end
else
	if Active and Marker then
		if IsAltKeyDown() and AutoMark_DB.advancedMode then
			MyAddon.SetHold(not Hold,true)
		elseif IsControlKeyDown() and AutoMark_DB.advancedMode then
			if not InfoFrame then
				InfoFrame = MyAddon.CreateInfoFrame()
			end
			InfoFrame:Show()
		else
			MyAddon.Message("Clearing Marks")
			MyAddon.RemoveAllMarks()
			MyAddon.ResetMarks()
			MyAddon.UpdatePlayerMarks()
		end
	end
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function AutoMark_OnAddonCompartmentEnter(addonName,menuButtonFrame)

MyAddon.ShowTooltip(menuButtonFrame)

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function AutoMark_OnAddonCompartmentLeave(addonName,menuButtonFrame)

GameTooltip:Hide()

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.EventHandler(self, event, ...)

if event == "ADDON_LOADED" then
	local arg1 = ...
	if arg1 == addonName then
		MyAddon.Init()
		Frame:UnregisterEvent("ADDON_LOADED")
	end
	return
end

if event == "PLAYER_LOGIN" then
	local name, realm = UnitName("player")
	PlayerGUID = UnitGUID("player")
	RealmName = GetRealmName()
	if name ~= nil then
		if realm == nil or realm == "" then
			name = name .. "-" .. RealmName
		else
			name = name .. "-" .. realm
		end
	end
	PlayerName = name
	local success
	success = C_ChatInfo.RegisterAddonMessagePrefix(addonName)
	if not success then
		MyAddon.Message("FAILED TO REGISTER ADDON MESSAGE PREFIX")
	end
	success = C_ChatInfo.RegisterAddonMessagePrefix(WAPrefix)
	if not success then
		MyAddon.Message("FAILED TO REGISTER WA ADDON MESSAGE PREFIX")
	end
	if AutoMark_DB.enabled then
		MyAddon.MainEvents(true)
	end
	return
end

if event == "PLAYER_ENTERING_WORLD" then
	-- MyAddon.Debug(event)
	MyAddon.Initialize()
	if AutoMark_DB.enabled then
		MyAddon.GetGroupDetails()
		MyAddon.RequestPlayerInfo()
	end
end

-- Event only triggers if enabled.
if event == "GROUP_ROSTER_UPDATE" then
	-- MyAddon.Debug(event,IsInGroup())
	MyAddon.UpdatePartyFrames()
	MyAddon.GetGroupDetails()
	MyAddon.SendPlayerInfo()
	return
end

-- Event only triggers if enabled.
if event == "CHAT_MSG_ADDON" then
	MyAddon.ChatMessageAddon(...)
	return
end

-- Events only triggers if enabled.
if event == "READY_CHECK" or event == "PARTY_MEMBER_ENABLE" then
	MyAddon.SendPlayerInfo()
	return
end

-- Event only triggers if enabled.
if event == "CHALLENGE_MODE_START" then
	MyAddon.SendPlayerInfo()
	if Active and Marker then
		MyAddon.ResetMarks()
		MyAddon.UpdatePlayerMarks()
	end
end

-- Events only triggers if enabled.
-- When these events fire the marks on mobs are removed.
-- Note that GROUP_ROSTER_UPDATE is also fired after these.
if event == "GROUP_JOINED" or event == "GROUP_LEFT" then
	if Active and Marker then
		MyAddon.ResetMarks()
	end
end

if not Active or not Marker then return end

-- > FOLLOWING EVENTS ONLY CHECKED IF ACTIVE AND MARKER <--

if event == "UPDATE_MOUSEOVER_UNIT" or (event == "MODIFIER_STATE_CHANGED" and UnitExists("mouseover") and IsAltKeyDown()) then
	local unit = "mouseover"
	if UnitIsDead(unit) or UnitIsPlayer(unit) then return end
    local guid = UnitGUID(unit)
	if guid == nil then return end
	if IsAltKeyDown() then
		if IsControlKeyDown() and AutoMark_DB.modify then
			MyAddon.AddCustomMob(unit)
		elseif IsShiftKeyDown() and AutoMark_DB.modify then
			MyAddon.RemoveCustomMob(unit)
		else
			MyAddon.UnmarkUnit(unit,guid)
			return
		end
	end
	local npcId = MyAddon.GetNpcIdFromGUID(guid)
	if npcId == nil then return end
	if Scan then
		MyAddon.AddCustomMob(unit)
	end
	if Mobs[npcId] and Mobs[npcId].auto ~= "never" and Mobs[npcId].auto ~= "combat" then
		if MyAddon.IsNameplateVisble(guid) or Mobs[npcId].auto == "*mouseover" then
			MyAddon.MarkUnit(unit,guid,Mobs[npcId])
		end
	else
		local unitMark = MyAddon.UnitMark(unit)
		local mobMark = MyAddon.MobMark(guid)
		if UpdateTableForAllMarked and unitMark and (not mobMark or mobMark ~= unitMark) then
			MyAddon.MarkUnit(unit,guid,{})
			return
		end
		if AutoMark_DB.reMark and ReMarkAll and MyAddon.MobMark(guid) and not MyAddon.UnitMark(unit)then
			MyAddon.MarkUnit(unit,guid,{})
			return
		end
	end
	return
end

if event == "PLAYER_REGEN_ENABLED" then
	if Hold then
		return
	end
	MyAddon.ResetMarks()
	MyAddon.UpdatePlayerMarks()
	return
end

if event == "COMBAT_LOG_EVENT_UNFILTERED" then
	local _, subEvent, _, _, _, _, _, guid, name = CombatLogGetCurrentEventInfo()
	if guid == nil then return end
	if subEvent == "UNIT_DIED" then
		MyAddon.UnitDied(guid,name)
	end
	return
end

if event == "NAME_PLATE_UNIT_ADDED" then
	local unit = ...
	if unit == nil or UnitIsDead(unit) or UnitIsPlayer(unit) then return end
	if string.sub(unit,1,9) ~= "nameplate" then return end
    local guid = UnitGUID(unit)
	if guid == nil then return end
	local npcId = MyAddon.GetNpcIdFromGUID(guid)
	if npcId == nil then return end
	if Mobs[npcId] and Mobs[npcId].auto == "nameplate" then
		MyAddon.MarkUnit(unit,guid,Mobs[npcId])
	end
	return
end

if event == "UNIT_THREAT_LIST_UPDATE" then
	local unit = ...
	if unit == nil or UnitIsDead(unit) or UnitIsPlayer(unit) then return end
	if string.sub(unit,1,9) ~= "nameplate" then return end
    local guid = UnitGUID(unit)
	if guid == nill then return end
	local npcId = MyAddon.GetNpcIdFromGUID(guid)
	if npcId == nil then return end
	if Scan then
		MyAddon.AddCustomMob(unit)
	end
	if Mobs[npcId] and Mobs[npcId].auto ~= "never" then
		MyAddon.MarkUnit(unit,guid,Mobs[npcId])
	else
		if UpdateTableForAllMarked and MyAddon.UnitMark(unit) and not MyAddon.MobMark(guid) then
			MyAddon.MarkUnit(unit,guid,{})
			return
		end
		if AutoMark_DB.reMark and ReMarkAll and MyAddon.MobMark(guid) and not MyAddon.UnitMark(unit)then
			MyAddon.MarkUnit(unit,guid,{})
			return
		end
	end
	return
end

end
-------------------------------------------------------------------------------

Frame:RegisterEvent("ADDON_LOADED")
Frame:RegisterEvent("PLAYER_LOGIN")
Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

Frame:SetScript("OnEvent", MyAddon.EventHandler)
