-------------------------------------------------------------------------------
-- AutoMark v1.2.4
-- ===============
--
--	Auto Mark
--
--------------------------------------------------------------------------------

local addonName, MyAddon = ...

SLASH_AUTOMARK1 = "/automark"
SLASH_AUTOMARK2 = "/am"

local Frame = CreateFrame("Frame")

-- Use namespace if available.
local GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
local GetSpecialization = C_SpecializationInfo.GetSpecialization or GetSpecialization

local Mobs = {}
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

local MarkingDisabled = false

MyAddon.Icons = {}

MyAddon.Instances = {}

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
local ReMarkAll = false

-- In a group with other players and no tank role assigned (e.g. scenario) mark the group leader instead.
local MarkLeader = true

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

MyAddon.Marks = Marks

MyAddon.PlayerMarks = PlayerMarks

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

-- Convert MDT Dungeon Name to Instance Name.
local DungeonConvert = {
	{"^Mechagon", "Operation: Mechagon"},
	{"^Ara%-Kara", "Ara-Kara, City of Echoes"},
}

MyAddon.InstanceTypeList = {
	{"Dungeon","party"},
	{"Scenario","scenario"},
	{"Raid","raid"},
	{"Battleground","pvp"},
	{"Arena","arena"},
	{"Other","other"},
}

StaticPopupDialogs["AUTOMARK_NEW_CUSTOM_NPC"] = {
	text = "NPC ID",
	button1 = "OK",
	button2 = "Cancel",
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	hasEditBox = true,
	enterClicksFirstButton = true,
	OnShow = function (self, data)
		local button1 = self.button1 or self:GetButton1()
		local editBox = self.editBox or self.EditBox
		editBox:SetText("")
		if IsInInstance() then
			local guid = UnitGUID("target")
			local npcId = MyAddon.GetNpcIdFromGUID(guid)
			if npcId then
				editBox:SetText(npcId)
			end
		end
		button1:Disable()
	end,
	OnAccept = function (self, data, data2)
		local editBox = self.editBox or self.EditBox
		local npcId = editBox:GetText()
		npcId = tonumber(npcId)
		if MyAddon.Mobs[npcId] then
			AutoMark_Mobs[npcId] = {
				instanceID = MyAddon.Mobs[npcId].instanceID,
				name = MyAddon.Mobs[npcId].name,
				marks = MyAddon.Mobs[npcId].marks,
				auto = MyAddon.Mobs[npcId].auto,
			}
		else
-- Check MDT.
			local data
			if MDT and MDT.dungeonEnemies and MDT.dungeonList then
				data = MyAddon.MDTGetNPCDetails(npcId)
			end
			if data then	-- Use name and instanceID from MDT
				AutoMark_Mobs[npcId] = {name = data.name, instanceID = data.instanceID}
			else	-- Mob not found in MDT. Use current instance (if any) or 0.
				local iid = 0
				local name = ""
				if IsInInstance() then
					local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
					if instanceID and MyAddon.Instances[instanceID] then
						iid = instanceID
					end
					local guid = UnitGUID("target")
					local id = MyAddon.GetNpcIdFromGUID(guid)
					if npcId == id then
						if UnitName("target") then
							name = UnitName("target")
						end
					end				
				end
				AutoMark_Mobs[npcId] = {name = name, instanceID = iid}
			end
		end
		MyAddon.LoadMobs()
		if MyAddon.NPCsFrame then
			MyAddon.NPCsFrame.data.id.selectedValue = npcId
			MyAddon.NPCsFrame:UpdateEdit()
		end
	end,
	EditBoxOnTextChanged = function (self, data)
		local button1 = self:GetParent().button1 or self:GetParent():GetButton1()
		button1:Disable()
		local npcId = self:GetText()
		if string.match(npcId,"^%d+$") then
			npcId = tonumber(npcId)
			if npcId > 0 and not AutoMark_Mobs[npcId] then
				button1:Enable()
			end
		end
	end
}

StaticPopupDialogs["AUTOMARK_DELETE_CUSTOM_NPC"] = {
	text = "%s",
	button1 = "OK",
	button2 = "Cancel",
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
	OnAccept = function (self, data, data2)
		MyAddon.DeleteCustomNPC(data)
	end,
}

StaticPopupDialogs["AUTOMARK_DELETE_ALL_CUSTOM"] = {
	text = "Remove ALL Custom NPCs and Instances?",
	button1 = "OK",
	button2 = "Cancel",
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
	OnAccept = function (self, data, data2)
		MyAddon.DeleteAllCustom()
	end,
}

StaticPopupDialogs["AUTOMARK_NEW_INSTANCE"] = {
	text = "Instance ID",
	button1 = "OK",
	button2 = "Cancel",
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	hasEditBox = true,
	enterClicksFirstButton = true,
	OnShow = function (self, data)
		local button1 = self.button1 or self:GetButton1()
		local editBox = self.editBox or self.EditBox
		editBox:SetText("")
		if IsInInstance() then
			local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
			if instanceID then
				editBox:SetText(instanceID)
			end
		end
		button1:Disable()
	end,
	OnAccept = function (self, data, data2)
		local editBox = self.editBox or self.EditBox
		local instanceId = editBox:GetText()
		instanceId = tonumber(instanceId)
		MyAddon.AutoMark_Instances[instanceId] = {name = ""}
		if IsInInstance() then
			local name, instanceType, _, _, _, _, _, iid = GetInstanceInfo()
			if iid and iid == instanceId then
				MyAddon.AutoMark_Instances[instanceId].name = name
				MyAddon.AutoMark_Instances[instanceId].instanceType = "other"
				for i = 1,#MyAddon.InstanceTypeList do
					if MyAddon.InstanceTypeList[i][2] == instanceType then
						MyAddon.AutoMark_Instances[instanceId].instanceType = instanceType
						break
					end
				end
			end
		end
		MyAddon.LoadInstances()
		MyAddon.Initialize()
		if MyAddon.InstancesFrame then
			MyAddon.InstancesFrame.data.id.selectedValue = instanceId
			MyAddon.InstancesFrame:UpdateEdit()
		end
	end,
	EditBoxOnTextChanged = function (self, data)
		local button1 = self:GetParent().button1 or self:GetParent():GetButton1()
		button1:Disable()
		local InstanceId = self:GetText()
		if string.match(InstanceId,"^%d+$") then
			InstanceId = tonumber(InstanceId)
			if InstanceId > 0 and not MyAddon.DefaultInstances[InstanceId] and not MyAddon.AutoMark_Instances[InstanceId] then
				button1:Enable()
			end
		end
	end
}


StaticPopupDialogs["AUTOMARK_DELETE_INSTANCE"] = {
	text = "%s",
	button1 = "OK",
	button2 = "Cancel",
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
	OnAccept = function (self, data, data2)
		MyAddon.DeleteInstance(data)
	end,
}

--------------------------------------------------------------------------------
function MyAddon.Init()

if AutoMark_DB == nil then AutoMark_DB = {} end

if AutoMark_Mobs == nil then AutoMark_Mobs = {} end
if AutoMark_Instances == nil then AutoMark_Instances = {} end
if AutoMark_DB.enabled == nil then AutoMark_DB.enabled = true end
if AutoMark_DB.markerIndicator == nil then AutoMark_DB.markerIndicator = true end
if AutoMark_DB.vip == nil then AutoMark_DB.vip = false end
if AutoMark_DB.sounds == nil then AutoMark_DB.sounds = false end
if AutoMark_DB.reMark == nil then AutoMark_DB.reMark = true end
if AutoMark_DB.updateMarked == nil then AutoMark_DB.updateMarked = true end
if AutoMark_DB.verbose == nil then AutoMark_DB.verbose = false end
if AutoMark_DB.playerMarks == nil then AutoMark_DB.playerMarks = {} end
if AutoMark_DB.forceMouseover == nil then AutoMark_DB.forceMouseover = false end
if AutoMark_DB.ignoreDefaultNPCs == nil then AutoMark_DB.ignoreDefaultNPCs = false end
if AutoMark_DB.ignoreCustomNPCs == nil then AutoMark_DB.ignoreCustomNPCs = false end
 if AutoMark_DB.leaderOnly == nil then AutoMark_DB.leaderOnly = false end

MyAddon.AutoMark_Mobs = AutoMark_Mobs
MyAddon.AutoMark_DB = AutoMark_DB
MyAddon.AutoMark_Instances = AutoMark_Instances

for _,k in ipairs({"TANK","HEALER"}) do
	PlayerMarks[k] = AutoMark_DB.playerMarks[k] or MyAddon.DefaultPlayerMarks[k]
end

MyAddon.InitMinimapIcon(AutoMark_DB)

MyAddon.UpdateIcon()

if AutoMark_DB.icons then
	MyAddon.Icons =  AutoMark_DB.icons
else
	MyAddon.Icons = MyAddon.DefaultIcons
end

MyAddon.LoadInstances()

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
function MyAddon.LoadMob(id,data,custom)

if not data then
	Mobs[id] = nil
	return
end

if data.instanceID < 0 then return end

if data.instanceID ~= nil and data.instanceID ~= 0 and data.instanceID ~= InstanceID then return end

Mobs[id] = {}

for a,v in pairs(data) do
		Mobs[id][a] = v
end

if custom then
	Mobs[id].custom = true
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.LoadMobs()

if not Active then return end

Mobs = {}

if not AutoMark_DB.ignoreDefaultNPCs then
	for id,data in pairs(MyAddon.Mobs) do
		MyAddon.LoadMob(id,data)
	end
end

if not AutoMark_DB.ignoreCustomNPCs then
	for id,data in pairs(AutoMark_Mobs) do
		MyAddon.LoadMob(id,data,true)
	end
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
	MyAddon.Message("Mobs:",n,"(" .. c .. ")")
else
	MyAddon.Message("Mobs:",n)
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
frame.head:SetText(addonName .. " Status")
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

-- Called on PLAYER_ENTERING_WORLD and after PLAYER_MAP_CHANGED.

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
		if AutoMark_DB.enabled then
			if MyAddon.Instances[InstanceID] then
				MyAddon.SetActive(true)
			else
				MyAddon.SetActive(false)
			end
		end
else
	InstanceName = nil
	InstanceID = nil
	MyAddon.SetActive(false)
end

MyAddon.ResetMarks()

MyAddon.UpdatePartyFrames()

if AutoMark_DB.enabled then
	MyAddon.GetGroupDetails()
	MyAddon.RequestPlayerInfo()
end
		
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
--		MyAddon.Debug("FAILED TO SEND ADDON MESSAGE")
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

if MarkingDisabled then status = "0" end

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
local leader
local players = false

for i = 0, 4 do

	local unit
	
	if i == 0 then unit = "player" else unit = "party" .. i end
	
	if UnitExists(unit) then
		local role = UnitGroupRolesAssigned(unit)
		if unit ~= "player" and UnitIsPlayer(unit) then players = true end
		if UnitIsGroupLeader(unit) then
			if not leader then leader = unit end
		end
--		MyAddon.Debug(i,"UNIT",unit,UnitName(unit),role)
		if role == "TANK" then
			if not tank then tank = unit end
		elseif role == "HEALER" then
			if not healer then healer = unit end
		elseif role == "DAMAGER" then
			SetRaidTarget(unit,0)
		end
	end
end

if tank then
--	MyAddon.Debug("TANK:",tank)
	if PlayerMarks["TANK"] > 0 then
		SetRaidTarget(tank,PlayerMarks["TANK"])
	end
else
	if MarkLeader and players and leader then
		if PlayerMarks["TANK"] > 0 then
			SetRaidTarget(leader,PlayerMarks["TANK"])
		end
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

for _,i in ipairs(MyAddon.Icons) do

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

MyAddon.Debug("SET MARK",m,guid,name,time,force,tag)

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
--	MyAddon.Debug("FAILED TO SEND WA ADDON MESSAGE")
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.ChatMessageAddon(prefix,text,channel,sender)

-- Send reply to WA!
if prefix == WAPrefix then
	-- if sender ~= PlayerName then
		-- MyAddon.Debug("MSG",prefix,text,channel,sender)
	-- end
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

-- if MarkerGUID == nil then
	-- MyAddon.Debug("No Marker")
-- else
	-- if PlayerGUID == guid then
		-- MyAddon.Debug("You're Marker")
	-- else
		-- MyAddon.Debug("Marker is",MarkerName)
	-- end
-- end

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

GameTooltip:SetText("AutoMark")

local version = C_AddOns.GetAddOnMetadata(addonName,"Version")
GameTooltip:AddLine(version,1,1,1)

if AutoMark_DB.enabled then
	GameTooltip:AddLine("Enabled",0,1,0)
	if Marker then
		local buffer = ""
		for _,i in ipairs(MyAddon.Icons) do
			buffer = buffer .. MyAddon.Marks[i].icon
		end
		GameTooltip:AddLine(buffer,1,1,1)
	end
else
	GameTooltip:AddLine("Disabled",1,0,0)
end

GameTooltip:AddLine(" ",1,1,1)

if verbose then
	GameTooltip:AddLine("Player Name: " .. tostring(PlayerName),1,1,1)
	GameTooltip:AddLine("Player GUID: " .. tostring(PlayerGUID),1,1,1)
end

if Active then
	c = GREEN_FONT_COLOR_CODE
else
	c = ORANGE_FONT_COLOR_CODE
end

b = InstanceName or "NONE"

if InstanceID then
	b = b .. " (" .. InstanceID .. ")"
	if InstanceType then
		b = b .. " (" .. InstanceType .. ")"
	end
end

GameTooltip:AddLine("Instance: " .. c .. b .. FONT_COLOR_CODE_CLOSE,1,1,1)

if Marker then
	c = GREEN_FONT_COLOR_CODE
else
	c = ORANGE_FONT_COLOR_CODE
end

local m = MarkerName or "NONE"

GameTooltip:AddLine("Marker: " .. c .. m .. FONT_COLOR_CODE_CLOSE,1,1,1)

if Active then
	GameTooltip:AddLine("Active: " .. tostring(Active) .. " (" .. tostring(MobsLoaded) .. ")",1,1,1)
else
	GameTooltip:AddLine("Active: " .. tostring(Active),1,1,1)
end

if AutoMark_DB.enabled and AutoMark_DB.leaderOnly then
	if MarkingDisabled then
		GameTooltip:AddLine("Group Leader Only: " .. tostring(AutoMark_DB.leaderOnly),1,0,0)
	else
		GameTooltip:AddLine("Group Leader Only: " .. tostring(AutoMark_DB.leaderOnly),1,1,1)
	end
end

if AutoMark_DB.vip then
	GameTooltip:AddLine("VIP: " .. tostring(AutoMark_DB.vip),1,1,1)
end

if AutoMark_DB.modify then
	GameTooltip:AddLine("Modify: " .. tostring(AutoMark_DB.modify),1,1,1)
end

if AutoMark_DB.forceMouseover then
	GameTooltip:AddLine("Force Mouseover: " .. tostring(AutoMark_DB.forceMouseover),1,1,1)
end

if AutoMark_DB.ignoreDefaultNPCs then
	GameTooltip:AddLine("Ignore Default NPCs: " .. tostring(AutoMark_DB.ignoreDefaultNPCs),1,1,1)
end

if AutoMark_DB.ignoreCustomNPCs then
	GameTooltip:AddLine("Ignore Custom NPCs: " .. tostring(AutoMark_DB.ignoreCustomNPCs),1,1,1)
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
		for _, i in ipairs(MyAddon.Icons) do
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
	GameTooltip:AddLine("Left-click to Clear Marks",0.25,0.78,0.92)
	if AutoMark_DB.advancedMode then
		GameTooltip:AddLine("Ctrl-Left-click to show Info",0.25,0.78,0.92)
		if Hold then
			GameTooltip:AddLine("Alt-Left-click to Resume",0.25,0.78,0.92)
		else
			GameTooltip:AddLine("Alt-Left-click to Hold",0.25,0.78,0.92)
		end
	end
end

if Active then
	GameTooltip:AddLine("Middle-click to Reload Mobs",0.25,0.78,0.92)
end

if AutoMark_DB.enabled then
	GameTooltip:AddLine("Right-click to Disable",0.25,0.78,0.92)
else
	GameTooltip:AddLine("Right-click to Enable",0.25,0.78,0.92)
end

GameTooltip:AddLine("Shift-click to Configure",0.25,0.78,0.92)

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

-- MyAddon.Message("GETGROUPDETAILS",IsInGroup(),UnitIsGroupLeader("player"))

MarkingDisabled = false

if AutoMark_DB.leaderOnly then
	if IsInGroup() and not UnitIsGroupLeader("player") then
		MarkingDisabled = true
	end
end

-- MyAddon.Message("No Marker",MarkingDisabled)

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
		MyAddon.Message("Already Enabled")
		return
	end
	MyAddon.MainEvents(true)
	AutoMark_DB.enabled = true
	MyAddon.UpdateIcon()
	MyAddon.Message("Enabled")
	MyAddon.Initialize()
else
	if not AutoMark_DB.enabled then
		MyAddon.Message("Already Disabled")
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
	MyAddon.Message("Disabled")
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
		frame.AutoMarkIcon:SetPoint("RIGHT",frame,"LEFT",0,0)	-- 8,0
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
function MyAddon.AddCustomMob(unit,manual)

local iid = InstanceID or 0
local name = UnitName(unit)
local guid = UnitGUID(unit)
local hostile = UnitIsEnemy("player",unit)
local attackable = UnitCanAttack("player",unit)
local level  = UnitLevel(unit)
local classification  = UnitClassification(unit)
local creatureType = UnitCreatureType(unit)
local powerType, powerTypeString = UnitPowerType(unit)
local auto = "never"

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
		MyAddon.Message("ATTACKABLE",npcId,AutoMark_Mobs[npcId].name)
		PlaySound(130,"Master")
	end
	if not attackable and AutoMark_Mobs[npcId].attackable then
		attackable = true
	end
	if hostile and not AutoMark_Mobs[npcId].hostile then
		MyAddon.Message("HOSTILE",npcId,AutoMark_Mobs[npcId].name)
		PlaySound(180,"Master")
	end
	if not hostile and AutoMark_Mobs[npcId].hostile then
		hostile = true
	end
	if name ~= AutoMark_Mobs[npcId].name then
		MyAddon.Message("NAME",npcId,AutoMark_Mobs[npcId].name,name)
		PlaySound(25,"Master")
	end
	if iid ~= AutoMark_Mobs[npcId].instanceID then
		MyAddon.Message("INSTANCE",npcId,AutoMark_Mobs[npcId].name,AutoMark_Mobs[npcId].instanceID,iid)
		PlaySound(25,"Master")
	end
end

if action == "ADD" then
	AutoMark_Mobs[npcId] = {}
	if MyAddon.Mobs[npcId] then
		AutoMark_Mobs[npcId].marks = MyAddon.Mobs[npcId].marks
		AutoMark_Mobs[npcId].auto = MyAddon.Mobs[npcId].auto
	else
		if not manual then
			AutoMark_Mobs[npcId].auto = "never"
		end
	end
end

AutoMark_Mobs[npcId].name = name
AutoMark_Mobs[npcId].instanceID = iid
AutoMark_Mobs[npcId].level = level
AutoMark_Mobs[npcId].power = powerTypeString
AutoMark_Mobs[npcId].classification = classification
AutoMark_Mobs[npcId].creatureType = creatureType
AutoMark_Mobs[npcId].attackable = attackable
AutoMark_Mobs[npcId].hostile = hostile

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
	MyAddon.Message("Unit invalid.")
	return
end

local npcId = MyAddon.GetNpcIdFromGUID(guid)

if not AutoMark_Mobs[npcId] then
	MyAddon.Message("NPC not found.")
	return
end

local name = AutoMark_Mobs[npcId].name

MyAddon.Message("REMOVE",npcId,name)

AutoMark_Mobs[npcId] = nil

PlaySound(700,"Master")

MyAddon.LoadMobs()

if MyAddon.NPCsFrame then
	MyAddon.NPCsFrame.data.id.selectedValue = nil
	MyAddon.NPCsFrame.data.id:Update()
	MyAddon.NPCsFrame:ClearEdit()
end

end
-------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.DeleteCustomNPC(npcId)

if npcId == nil then return end

if MyAddon.AutoMark_Mobs[npcId] then
	local name = AutoMark_Mobs[npcId].name
	MyAddon.AutoMark_Mobs[npcId] = nil
	if MyAddon.Mobs[npcId] then
		MyAddon.Message("NPC Override Removed",npcId,name)
	else
		MyAddon.Message("Custom NPC Removed",npcId,name)
	end
	MyAddon.LoadMobs()
	if MyAddon.NPCsFrame then
		if MyAddon.Mobs[npcId] and MyAddon.Filters["DefaultNPCs"] then
			MyAddon.NPCsFrame.data.id.selectedValue = npcId
			MyAddon.NPCsFrame:UpdateEdit()
		else
			MyAddon.NPCsFrame.data.id.selectedValue = nil
			MyAddon.NPCsFrame.data.id:Update()
			MyAddon.NPCsFrame:ClearEdit()
		end
	end
end
			
end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.DeleteAllCustom()

local n = 0

for id,data in pairs(MyAddon.AutoMark_Mobs) do
	n = n + 1
	MyAddon.AutoMark_Mobs[id] = nil
end

if n == 0 then
	MyAddon.Message("No Custom NPCs found.")
else
	MyAddon.Message("All (" .. n .. ") Custom NPCs Removed.")
end

n = 0

for id,data in pairs(MyAddon.AutoMark_Instances) do
	n = n + 1
	MyAddon.AutoMark_Instances[id] = nil
end

if n == 0 then
	MyAddon.Message("No Custom Instances found.")
else
	MyAddon.Message("All (" .. n .. ") Custom Instances Removed.")
end

if MyAddon.NPCsFrame then
	MyAddon.NPCsFrame.data.id.selectedValue = nil
	MyAddon.NPCsFrame.data.id:Update()
	MyAddon.NPCsFrame:ClearEdit()
end

if MyAddon.InstancesFrame then
	MyAddon.InstancesFrame.data.id.selectedValue = nil
	MyAddon.InstancesFrame.data.id:Update()
	MyAddon.InstancesFrame:ClearEdit()
end

MyAddon.LoadInstances()

MyAddon.Initialize()

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.DeleteInstance(instanceId)

if instanceId == nil then
	return
end

if not MyAddon.AutoMark_Instances[instanceId] then
	return
end

local name = AutoMark_Instances[instanceId].name

MyAddon.AutoMark_Instances[instanceId] = nil

MyAddon.Message("Instance Removed",instanceId,name)

if MyAddon.InstancesFrame then
	MyAddon.InstancesFrame.data.id.selectedValue = nil
	MyAddon.InstancesFrame.data.id:Update()
	MyAddon.InstancesFrame:ClearEdit()
end

MyAddon.LoadInstances()

MyAddon.Initialize()

end
--------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MyAddon.QuickAdd(unit)

if UnitIsPlayer(unit) then
	MyAddon.Message("Unit is a player.")
	return
end

local iid = InstanceID or 0
local name = UnitName(unit)
local guid = UnitGUID(unit)

if not guid then
	return
end

local npcId = MyAddon.GetNpcIdFromGUID(guid)

if npcId == nil then
	MyAddon.Message("Invalid NPC ID.")
	return
end

if MyAddon.Mobs[npcId] then
	MyAddon.Message("Default NPC Already Exists.")
	return
end

if AutoMark_Mobs[npcId] then
	MyAddon.Message("Custom NPC Already Exists.")
	return
end

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

AutoMark_Mobs[npcId] = {name = name, instanceID = iid}

MyAddon.Message("NPC " .. npcId .. " (" ..name .. ") added.")

MyAddon.LoadMobs()

end
-------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.MDTGetNPCDetails(npcId)

for index, enemies in pairs(MDT.dungeonEnemies) do
	
	-- print(index,MDT.dungeonList[index])
	
	for _,enemy in pairs(enemies) do
		-- print("  ",enemy.id, enemy.name, enemy.isBoss)
		if enemy.id == npcId and enemy.name ~= nil then
			local  enemyName = enemy.name
			if enemy.isBoss then
				enemyName = "[BOSS] " .. enemyName
			end
			local dungeonName = MDT.dungeonList[index]
			for _,v in ipairs(DungeonConvert) do
				if string.match(dungeonName,v[1]) then
					dungeonName = v[2]
					break
				end
			end
			-- print("FOUND",enemyName,index,dungeonName)
			local instanceID
			for id,v in pairs(MyAddon.Instances) do
				if v.name == dungeonName then
					instanceID = id
				end
			end
			if instanceID then
				return {name = enemyName, instanceID = instanceID}
			end
		end
	end

end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.AuditNPC(npcId,v,fix)

local msg = {}

local data = MyAddon.MDTGetNPCDetails(npcId)

local err = false

if data then
	local instance = MyAddon.Instances[data.instanceID].name or "UNKNOWN"
	if v.name == "" and v.name ~= data.name then
		err = true
		if fix then
			v.name = data.name
			msg[1] = string.format("++ Name changed to %s.",data.name)
		else
			msg[1] = string.format(">> Name should be %s.",data.name)
		end
	end
	if v.instanceID ~= data.instanceID then
		err = true
		if fix and instance then
			v.instanceID = data.instanceID
			msg[2] = string.format("++ Instance ID changed to %d (%s).",data.instanceID,instance)
		else
			msg[2] = string.format(">> Instance should be %s.",instance)
		end
	end
	if err then
		local instanceName = MyAddon.Instances[v.instanceID].name or "UNKNOWN"
		print(string.format("** ID: %d  Name: %s  Instance ID: %d (%s)",npcId,v.name,v.instanceID,instanceName))
		for i = 1,2 do
			if msg[i] then
				print(msg[i])
			end
		end
	end
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.Audit(fix)

if fix then
	MyAddon.Message("AUDITING WITH FIXES")
else
	MyAddon.Message("AUDITING")
end

if not MDT or not MDT.dungeonEnemies or not MDT.dungeonList then
	MyAddon.Message("MDT not found.")
	return
end

for npcId,v in pairs(AutoMark_Mobs) do
	MyAddon.AuditNPC(npcId,v,fix)
end

if fix and MyAddon.NPCsFrame then
	MyAddon.NPCsFrame.data.id.selectedValue = nil
	MyAddon.NPCsFrame.data.id:Update()
	MyAddon.NPCsFrame:ClearEdit()
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.TidyInstance()

-- Remove non-attackable mobs from current Instance.

MyAddon.Message("TIDYING")

for npcId,v in pairs(AutoMark_Mobs) do
	if v.instanceID == InstanceID then
		if v.attackable == false and v.auto == "never" then
			print(npcId,v.name,"REMOVED")
			AutoMark_Mobs[npcId] = nil
		end
	end
end

if MyAddon.NPCsFrame then
	MyAddon.NPCsFrame.data.id.selectedValue = nil
	MyAddon.NPCsFrame.data.id:Update()
	MyAddon.NPCsFrame:ClearEdit()
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.MDTImport(instanceID,all)

local index

for i,dungeonName in pairs(MDT.dungeonList) do
	local instName = dungeonName
	for _,v in ipairs(DungeonConvert) do
		if string.match(instName,v[1]) then
			instName = v[2]
			break
		end
	end
	local iid
	for id,v in pairs(MyAddon.Instances) do
		if v.name == instName then
			iid = id
			break
		end
	end

	if iid == instanceID then
		index = i
		break
	end
	
end

if index == nil then
	MyAddon.Message("Dungeon not found in MDT.")
	return
end

MyAddon.Message("MDT Dungeon index:",index)

for _,npc in pairs(MDT.dungeonEnemies[index]) do
	local npcId = npc.id
	local npcName = npc.name
	if npc.isBoss then
		npcName = "[BOSS] " .. npcName
	end
	-- print(npcId,npcName)
	local interrupt = false
	if npc.spells then
		for spellId, spellData in pairs(npc.spells) do
			if spellData.interruptible then
				interrupt = true
				local info = C_Spell.GetSpellInfo(spellId)
				-- print("  ",spellId,info.name)
			end					
		end
	end
	if npc.isBoss or interrupt or all then
		if AutoMark_Mobs[npcId] then
			print(npcId,npcName,"ALREADY EXISTS")
		else
			local marks
			local auto
			if npc.isBoss then
				marks = "8"
			else
				if not interrupt then
					auto = "never"
				end
			end
			AutoMark_Mobs[npcId] = {name = npcName, instanceID = instanceID, marks = marks, auto = auto}
			print(npcId,npcName,"IMPORTED")
		end
	end
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.SetRoleMark(role,mark,verbose)

if not mark or mark == MyAddon.DefaultPlayerMarks[role] then
	AutoMark_DB.playerMarks[role] = nil
	PlayerMarks[role] = MyAddon.DefaultPlayerMarks[role]
	local x
	if Marks[PlayerMarks[role]] then
		x = Marks[PlayerMarks[role]].icon
	else
		x = "NONE"
	end
	if verbose then
		MyAddon.Message(role .. " Mark reset to default (" .. x .. ").")
	end
else
	AutoMark_DB.playerMarks[role] = mark
	PlayerMarks[role] = AutoMark_DB.playerMarks[role]
	if verbose then
		if mark > 0 then
			MyAddon.Message(role .. " Mark:",Marks[PlayerMarks[role]].icon)
		else
			MyAddon.Message(role .. " Mark: NONE")
		end
	end
end

if Active and Marker then
	MyAddon.ResetMarks()
	MyAddon.UpdatePlayerMarks()
end

end
-------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.SetIcons(data,verbose)

if data == nil then
	AutoMark_DB.icons = nil
	MyAddon.Icons =  MyAddon.DefaultIcons
	if verbose then
		MyAddon.Message("Default Icons")
	end
	return
end

local m = false

local list = {false,false,false,false,false,false,false,false}

local icons = {}

for c in string.gmatch(data,"%d") do
	c = tonumber(c)
	if c and c >= 1 and c <= 8 then
		m = true
		if not list[c] then
			list[c] = true
			table.insert(icons,c)
		end
	end
end


AutoMark_DB.icons = {}

for _,v in ipairs(icons) do
	table.insert(AutoMark_DB.icons,v)
end

MyAddon.Icons =  AutoMark_DB.icons

local buffer = ""
local icons = ""

for i,n in ipairs(MyAddon.Icons) do
	icons = icons .. Marks[n].icon
	if i == 1 then
		buffer = buffer .. n
	else
		buffer = buffer .. "," .. n
	end
end

if verbose then
	MyAddon.Message("Icons:",buffer,icons)
end
	
end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.LoadInstances()

MyAddon.Instances = {}

for id, v in pairs(MyAddon.DefaultInstances) do
	local instanceType = v.instanceType or "party"
	local seasonal
	if v.seasonal then seasonal = true end
	MyAddon.Instances[id] = {name = v.name, instanceType = instanceType, seasonal = seasonal}
end

for id, v in pairs(AutoMark_Instances) do

	if not MyAddon.DefaultInstances[id] then
		MyAddon.Instances[id] = {name = v.name, instanceType = v.instanceType}
	else
		if v.name ~= MyAddon.Instances[id].name then
			MyAddon.Message("Custom Instance " .. id .. " is a default instance (" .. MyAddon.Instances[id].name .. ").")
		else
			MyAddon.Message("Custom Instance " .. id .. " is a default instance.")
		end
	end

end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.CheckInstance()

-- Called after PLAYER_MAP_CHANGED.

if IsInInstance() then
	local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
	if InstanceName ~= name then
		-- MyAddon.Message("Entered Instance")
		MyAddon.Initialize()
	-- else
		-- MyAddon.Message("Already In Instance")
	end
else
	if InstanceName ~= nil then
		-- MyAddon.Message("Left Instance")
		MyAddon.Initialize()
	-- else
		-- MyAddon.Message("Not In Instance")
	end
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.ShowConfig()

if MyAddon.ConfigFrame == nil then
	MyAddon.ConfigFrame = MyAddon.CreateConfigFrame()
	MyAddon.NPCsFrame = MyAddon.CreateNPCsFrame(MyAddon.ConfigFrame)
	MyAddon.MarksFrame = MyAddon.CreateMarksFrame(MyAddon.ConfigFrame)
	MyAddon.OptionsFrame = MyAddon.CreateOptionsFrame(MyAddon.ConfigFrame)
	MyAddon.InstancesFrame = MyAddon.CreateInstancesFrame(MyAddon.ConfigFrame)
end

if InCombatLockdown() then
	MyAddon.Message("Configuration will open after combat ends.")
	MyAddon.ConfigFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	return
end

MyAddon.NPCsFrame:UpdateEdit()

MyAddon.ConfigFrame:Show()

end
--------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function SlashCmdList.AUTOMARK(msg,editbox)

local words = {}

local cmd = ""

for word in msg:gmatch("%S+") do table.insert(words, word) end

if #words > 0 then
	cmd = words[1]
end

if cmd == nil then return end

if cmd == "" then
	MyAddon.ShowConfig()
	return
end

if cmd == "removeallcustom" then
	local dialog = StaticPopup_Show("AUTOMARK_DELETE_ALL_CUSTOM")
	return
end

if cmd == "addnpc" then
	local unit = words[2]
	if unit == "" or unit == nil then unit = "target" end
	if unit == "target" or unit == "mouseover" or unit == "focus" then
		MyAddon.QuickAdd(unit)
	else
		MyAddon.Message("Unit invalid.")
	end
	return
end

if cmd == "mdtimport" then
	local iid = words[2]
	if not iid then
		MyAddon.Message("Instance ID not specified.")
		return
	end
	local option = words[3]
	iid = tonumber(iid)
	if not MyAddon.Instances[iid] then
		MyAddon.Message("Invalid Instance ID.")
		return
	end
	local all = false
	if option and option ~= "all" then
		return
	end
	if option == "all" then
		all = true
	end
	if not MDT or not MDT.dungeonEnemies or not MDT.dungeonList then
		MyAddon.Message("MDT not found.")
		return
	end
	MyAddon.MDTImport(iid,all)
	return
end

if cmd == "audit" then
	local fix = false
	if words[2] == "fix" then
		fix = true
	end
	MyAddon.Audit(fix)
	return
end

if cmd == "tidy" then
	MyAddon.TidyInstance()
	return
end

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
		MyAddon.Message("Not Marker.")
		return
	end
	MyAddon.Message("Resetting Marks")
	MyAddon.ResetMarks()
	return
end

if cmd == "clear" then
	if not Active then
		return
	end
	if not Marker then
		MyAddon.Message("Not Marker.")
		return
	end
	MyAddon.Message("Clearing Marks")
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
		MyAddon.Message("Not Marker.")
		return
	end
	MyAddon.Message("Removing Marks")
	MyAddon.RemoveAllMarks()
	MyAddon.UpdatePlayerMarks()
	return
end

if cmd == "player" then
	MyAddon.Message("Updating Player Marks")
	MyAddon.UpdatePlayerMarks()
	return
end

if cmd == "update" then
	MyAddon.Message("Requesting Update")
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
	MyAddon.Message("Advanced Mode:",AutoMark_DB.advancedMode)
	return
end

if cmd == "sounds" then
	AutoMark_DB.sounds = not AutoMark_DB.sounds
	MyAddon.Message("Sounds:",AutoMark_DB.sounds)
	return
end

if cmd == "forcemouseover" then
	AutoMark_DB.forceMouseover = not AutoMark_DB.forceMouseover
	MyAddon.Message("Force Mouseover:",AutoMark_DB.forceMouseover)
	if MyAddon.OptionsFrame:IsShown() then
		MyAddon.OptionsFrame:Hide()
		MyAddon.OptionsFrame:Show()
	end
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
		MyAddon.Message("Mark Times Extended")
	end
	return
end

if cmd == "lock" then
	StatusFrame.texture:Hide()
	StatusFrame.head:Hide()
	StatusFrame:EnableMouse(false)
	MyAddon.Message("Status Frame Locked")
	return
end

if cmd == "unlock" then
	StatusFrame.texture:Show()
	StatusFrame.head:Show()
	StatusFrame:EnableMouse(true)
	MyAddon.Message("Status Frame Unlocked")
	return
end

if cmd == "resetpos" then
	StatusFrame:ClearAllPoints()
	StatusFrame:SetPoint("TOP")
	MyAddon.Message("Status Frame Position Reset")
	return
end

if cmd == "modify" then
	AutoMark_DB.modify = not AutoMark_DB.modify
	MyAddon.Message("Modify:",AutoMark_DB.modify)
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

if cmd == "scan" then
	Scan = not Scan
	MyAddon.UpdateIcon()
	MyAddon.Message("Scan:",Scan)
	return
end

MyAddon.Message(
	"Usage:\n" .. 
	"/am - Configure\n" ..
	"/am minimap - Toggle the minimap icon\n" ..
	"/am minimaplock - Toggle lock minimap icon\n" ..
	"/am mobs - Show mobs that will be marked (in a dungeon)\n" ..
	""
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
else
	if IsShiftKeyDown() then
		MyAddon.ShowConfig()
	elseif Active and Marker then
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
	return
end

if event == "PLAYER_MAP_CHANGED" then
-- oldZone = -1 indicates a loading screen which is dealt with by PLAYER_ENTERING_WORLD.
	local oldZone, newZone = ...
	-- MyAddon.Message(event,oldZone,newZone)
	if oldZone == -1 then
		return
	end
	C_Timer.After(5,function() MyAddon.CheckInstance() end)
	return
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
	return
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
	MyAddon.Debug("GUID:",guid)
	if guid == nil then return end
	if IsAltKeyDown() then
		if IsControlKeyDown() and AutoMark_DB.modify then
			MyAddon.AddCustomMob(unit,true)
		elseif IsShiftKeyDown() and AutoMark_DB.modify then
			MyAddon.UnmarkUnit(unit,guid)
			MyAddon.RemoveCustomMob(unit)
		else
			MyAddon.UnmarkUnit(unit,guid)
			return
		end
	end
	local npcId = MyAddon.GetNpcIdFromGUID(guid)
	MyAddon.Debug("NPCID:",npcId)
	if npcId == nil then return end
	if Scan then
		MyAddon.AddCustomMob(unit)
	end
	if Debug and Mobs[npcId] then
		MyAddon.Debug("NAME:",Mobs[npcId].name)
		if MyAddon.IsNameplateVisble(guid) then
			MyAddon.Debug("NAMEPLATE VISIBLE: TRUE")
		else
			MyAddon.Debug("NAMEPLATE VISIBLE: FALSE")
		end
		if Mobs[npcId].auto == nil then
			MyAddon.Debug("AUTO: DEFAULT")
		else
			MyAddon.Debug("AUTO:",Mobs[npcId].auto)
		end
	end
	if Mobs[npcId] and Mobs[npcId].auto ~= "never" and Mobs[npcId].auto ~= "combat" then
		if MyAddon.IsNameplateVisble(guid) or Mobs[npcId].auto == "*mouseover" or AutoMark_DB.forceMouseover then
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
Frame:RegisterEvent("PLAYER_MAP_CHANGED")

Frame:SetScript("OnEvent", MyAddon.EventHandler)
