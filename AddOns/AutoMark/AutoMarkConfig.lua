local addonName, MyAddon = ...

local MarksOptionList = {
	[1] = {
		"Standard",
		"Any marks listed that are free will be applied before the default marks are used.",
		"",
	},
	[2] = {
		"Specific",
		"Only the marks listed that are free will be applied." ..
			"\n\nNo other marks will be used.",
		"*",
	},
	[3] = {
		"Force",
		"The specified marks are applied even if they're in use by another mob, unless that mob also has a Force mark.",
		"+",
	},
	[4] = {
		"Always",
		"The specified mark is applied even if it's in use by another mob." ..
			"\n\nOnly one mark can be specified." ..
			"\n\n(Useful for boss adds that don't generate a UNIT_DIED event.)",
		"!",
	},
}
		
local AutoList = {
	[1] = {
		"Default",
		"Mouseover if nameplate visible (or combat).",
		"default",
	},
	[2] = {
		"Mouseover",
		"Mouseover even if nameplate not visible (or combat).",
		"*mouseover",
	},
	[3] = {
		"Combat",
		"Only mark mob if it's in combat, not on mouseover.",
		"combat",
	},
	[4] = {
		"Nameplate",
		"Mark when nameplate added (or mouseover or combat)." ..
			"\n\n(Useful for mobs that spawn during a fight that don't have threat e.g. Totems.)",
		"nameplate",
	},
	[5] = {
		"Never",
		"Don't automatically mark.",
		"never",
	},
}

local DropdownTemplate = "WowStyle2DropdownTemplate"

local CheckButtonTemplate = "InterfaceOptionsCheckButtonTemplate"	-- ChatConfigCheckButtonTemplate, UICheckButtonTemplate

local EnforceAutoNever = true

MyAddon.Filters = {}

local FiltersList = {
	{text = "Default NPCs", name = "DefaultNPCs", default = true, tooltip = "Include Default NPCs.\nDeselect to only show Overrides and Custom NPCs."},
	{text = "Default Instances", name = "DefaultInstances", default = true, tooltip = "Include Default Instances."},
	{text = "Custom Instances", name = "CustomInstances", default = true, tooltip = "Include Custom Instances."},
	{text = "Current Season Only", name = "CurrentOnly", default = false, tooltip = "Only Current Season Dungeons will be shown."},
	{text = "Instance Types", heading = true},
	{text = "Dungeon", name = "Dungeon", default = true},
	{text = "Scenario", name = "Scenario", default = true},
	{text = "Raid", name = "Raid", default = false},
	{text = "Battleground", name = "Battleground", default = false},
	{text = "Arena", name = "Arena", default = false},
	{text = "Other", name = "Other", default = false},
}

local NPCColors = {
	["Default"]			= "AAD372",	-- Pistachio (Default)
	["Override"]		= "0070DD",	-- Blue (Override with marks)
	["OverrideNever"]	= "3FC7EB",	-- Light Blue (Override to not mark)
	["OverrideSame"]	= "8788EE",	-- Purple (Override with same marks as Default)
	["OverrideWarn"]	= "FF7C0A",	-- Orange (Override with difference Instance ID from Default)
	["Custom"]			= "FFFFFF",	-- White (Custom)
	["CustomNever"]		= "9D9D9D",	-- Gray (Custom Never Mark)
}

local Roles = {"TANK","HEALER"}

local ConfigData = {
	["markerIndicator"] = {
		text = "Show Marker Indicator",
		tooltip = {"Show marker indicator on unit frames."},
		default = true,
		onChange = function() MyAddon.UpdatePartyFrames() end,
	},
	["reMark"] = {
		text = "Re-Mark",
		tooltip = {"Restore missing mark if table says mob has a mark."},
		default = true,
		critical = true,
	},
	["updateMarked"] = {
		text = "Update Marked",
		tooltip = {"Update table with details from mob that already has an actual mark."},
		default = true,
		critical = true,
	},
	["forceMouseover"] = {
		text = "Force Mouseover",
		tooltip = {
			"Mouseover marking will work without nameplates showing.",
			"Only use this option if you are not using nameplates.",
		},
		default = false,
		critical = true,
	},
	["ignoreCustomNPCs"] = {
		text = "Ignore All Custom NPCs",
		tooltip = {"No Custom NPCs or Overrides will be loaded."},
		default = false,
		onChange = function() MyAddon.LoadMobs() end,
	},
	["ignoreDefaultNPCs"] = {
		text = "Ignore All Default NPCs",
		tooltip = {
			"No Default NPCs will be loaded.",
			"Only use this option if you don't want to use any of the default NPCs.",
		},
		default = false,
		onChange = function() MyAddon.LoadMobs() end,
		critical = true,
	},
	["leaderOnly"] = {
		text = "Group Leader Only",
		tooltip = {
			"When in a group you will only be eligible to become the marker if you are the group leader.",
		},
		default = false,
		onChange = function() MyAddon.GetGroupDetails() MyAddon.RequestPlayerInfo() end,
	},
}

local ConfigNames = {
	"markerIndicator",
	"reMark",
	"updateMarked",
	"forceMouseover",
	"ignoreCustomNPCs",
	"ignoreDefaultNPCs",
	"leaderOnly",
}

local changeMarker = CreateAtlasMarkup("UI-HUD-MicroMenu-Communities-Icon-Notification")

--------------------------------------------------------------------------------
local function On_Input_Enter(input)

if not input.tooltip then
	return
end

GameTooltip:Hide()
GameTooltip:ClearLines()
GameTooltip:SetOwner(input,"ANCHOR_TOPLEFT")

GameTooltip:SetText(input.title)

for _, v in ipairs(input.tooltip) do
	GameTooltip:AddLine(v)
end

GameTooltip:Show()

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
local function Option_Change(name,checked)

local data = ConfigData[name]

MyAddon.AutoMark_DB[name] = checked

if data.onChange then
	data.onChange()
end

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
local function Create_Checkbox(name,data,parent)

local checkbox = CreateFrame("CheckButton", nil, parent, CheckButtonTemplate)

checkbox:SetScript("OnClick", function(cb) Option_Change(cb.checkbox_name, cb:GetChecked()) parent:CheckDefaults() end)

checkbox.checkbox_name = name

local text = data.text

checkbox.title = text

local tooltip = data.tooltip

local warning = ""

if data.critical then
	local warning
	if data.default == true then
		warning = "|cFF00FF98(Recommended.)|r"
	else
		warning = "|cFFFF7C0A(Not recommended.)|r"
	end
	text = text .. " " .. warning
	table.insert(tooltip,warning)
end

checkbox.Text:SetText(text)
  
checkbox.Text:SetWidth(checkbox.Text:GetStringWidth() + 20)

if tooltip then
	checkbox.tooltip = data.tooltip
end

checkbox:SetScript("OnEnter", On_Input_Enter)
checkbox:SetScript("OnLeave", GameTooltip_Hide)

return checkbox

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
local function Create_Dropdown(tag,titleText,frame,l,width,GeneratorFunction,onSet)

local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
title:SetPoint("TOPLEFT",frame,10,l)
title:SetTextColor(1,0.8,0,1)
title:SetText(titleText..":")

local RadioDropdown = CreateFrame("DropdownButton", nil, frame, DropdownTemplate)

RadioDropdown:SetupMenu(GeneratorFunction)

if tag == "id" then
	RadioDropdown:SetSelectionTranslator(
		function(selection)
		return selection.data
		end)
end
	
if width then
	RadioDropdown:SetWidth(width)
end

RadioDropdown:SetDefaultText("No selection")
RadioDropdown:SetPoint("LEFT",title,90-4,0)

RadioDropdown.selectedValue = nil

function RadioDropdown.IsSelected(value)
	return value == RadioDropdown.selectedValue
end

if tag == "id" then
	function RadioDropdown.SetSelected(value)
		RadioDropdown.selectedValue = value
		RadioDropdown:GetParent():UpdateEdit(value)
	end
else
	function RadioDropdown.SetSelected(value)
		RadioDropdown.selectedValue = value
		RadioDropdown:GetParent():CheckChanges(tag)
	end
end

RadioDropdown.indicator = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
RadioDropdown.indicator:SetPoint("RIGHT",RadioDropdown,"LEFT",-6,0)
	
return RadioDropdown

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.CreateConfigFrame()

MyAddon.ConfigTabPage = {}

local tabNames = {"NPCs","Instances","Marks","Options"}

local name = addonName .. "Config"

local frame = CreateFrame("Frame",name,UIParent,BackdropTemplateMixin and "BackdropTemplate")

frame:Hide()

frame:SetFrameStrata("DIALOG")
frame:SetWidth(500)
frame:SetHeight(420)
frame:SetPoint("CENTER")
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

frame.Close = CreateFrame("Button",nil,frame)
frame.Close:SetHeight(32)
frame.Close:SetWidth(32)
frame.Close:SetPoint("TOPRIGHT",-5,-5)
frame.Close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
frame.Close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
frame.Close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight","ADD")
frame.Close:SetScript("OnClick", function(self) self:GetParent():Hide() end)

for i = 1,getn(tabNames) do

	local f = CreateFrame("Button",name.."Tab"..i,frame,"CharacterFrameTabTemplate")
	f:SetID(i)
	f:SetText(tabNames[i])
	if i == 1 then
		f:SetPoint("CENTER",name,"BOTTOMLEFT",60,-14)	-- Was -12 -16 works well -14 is ok
	else
		f:SetPoint("LEFT",name.."Tab"..i-1,"RIGHT",3,0)
	end

	f:SetScript("OnClick",function(self)
		local id = self:GetID()
		PanelTemplates_SetTab(self:GetParent(),id)
		for i = 1,getn(tabNames) do
			if i == id then
				MyAddon.ConfigTabPage[i]:Show()
			else
				MyAddon.ConfigTabPage[i]:Hide()
			end
		end
	end)

end

PanelTemplates_SetNumTabs(frame,getn(tabNames))
PanelTemplates_SetTab(frame,1)

frame:SetScript("OnShow", function(self)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	PanelTemplates_SetTab(self,1)
	for i = 1,getn(tabNames) do
		if i == 1 then
			MyAddon.ConfigTabPage[i]:Show()
		else
			MyAddon.ConfigTabPage[i]:Hide()
		end
	end
end)

frame:SetScript("OnHide", function(self)
	frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
end)

frame:SetScript("OnEvent", function(self,event)
	if event == "PLAYER_REGEN_DISABLED" then
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:Hide()
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
		self:Show()
		return
	end
end)

tinsert(UISpecialFrames,frame:GetName())

return frame

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.GetInstances(selInst,separate)

-- Returns sorted list of filtered Instances.
-- "ALL" entry at end.
-- If separate=true then Current Instance (if any) and Selected Instance (if any) at the start.

-- Also returns list of Instance IDs in the list (keyList).

local function compare(a,b)
	return a[1] < b[1]
end
		
local currentInstanceID
local _, _, _, _, _, _, _, iid = GetInstanceInfo()
if iid and MyAddon.Instances[iid] then
	currentInstanceID = iid
end

local keys = {}

local keyList = {}

for k,v in pairs(MyAddon.Instances) do
	local show = false
	if v.instanceType == "party" and MyAddon.Filters["Dungeon"] then show = true end
	if v.instanceType == "raid" and MyAddon.Filters["Raid"] then show = true end
	if v.instanceType == "scenario" and MyAddon.Filters["Scenario"] then show = true end
	if v.instanceType == "pvp" and MyAddon.Filters["Battleground"] then show = true end
	if v.instanceType == "arena" and MyAddon.Filters["Arena"] then show = true end
	if v.instanceType == "other" and MyAddon.Filters["Other"] then show = true end
	if not MyAddon.Instances[k].seasonal and MyAddon.Filters["CurrentOnly"] then show = false end
	if MyAddon.DefaultInstances[k] and not MyAddon.Filters["DefaultInstances"] then show = false end
	if not MyAddon.DefaultInstances[k] and not MyAddon.Filters["CustomInstances"] then show = false end
	if separate then
		if k == selInst or k == currentInstanceID then show = false end
	end
	if show then
		table.insert(keys,{v.name,k})
		keyList[k] = true
	end
end

table.sort(keys,compare)

table.insert(keys,{"ALL",0})

if separate then
	if selInst and MyAddon.Instances[selInst] then
		table.insert(keys,1,{MyAddon.Instances[selInst].name,selInst})
	end
	if currentInstanceID and currentInstanceID ~= selInst and MyAddon.Instances[currentInstanceID] then
		table.insert(keys,1,{MyAddon.Instances[currentInstanceID].name,currentInstanceID})
	end
end

return keys, keyList

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.SetDefaultFilters()

for i,v in ipairs(FiltersList) do
	if not v.heading then
		MyAddon.Filters[v.name] = v.default
	end
end

end
--------------------------------------------------------------------------------
		
--------------------------------------------------------------------------------
function MyAddon.CreateNPCsFrame(parent)

local frame = CreateFrame("Frame",addonName.."NPCsFrame",parent)

frame:Hide()

frame:SetPoint("TOPLEFT")
frame:SetPoint("BOTTOMRIGHT")

frame.head = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
frame.head:SetWidth(500)
frame.head:SetPoint("TOPLEFT",frame,10,-15)
frame.head:SetJustifyH("LEFT")
frame.head:SetText(addonName.." NPCs")

frame.data = {}

MyAddon.SetDefaultFilters()

do

--	MSG
--	===

	local f = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
	f:SetWidth(1000)
	f:SetPoint("BOTTOMLEFT",frame,10,40)
	f:SetJustifyH("LEFT")
	f:SetTextColor(0.77,0.12,0.23)

	frame.data.msg = f

end

do

--	STATUS TEXT
--	===========

	local f = frame:CreateFontString(nil, nil, "GameFontNormal")
	f:SetWidth(200)
	f:SetPoint("TOPLEFT",frame.head,"BOTTOMLEFT",0,-30)
	f:SetJustifyH("LEFT")

	f:SetScript("OnEnter",
		function(self)
			local data = self:GetParent().data
			if not data.id.selectedValue then return end
			local npcId = data.id.selectedValue
			GameTooltip:SetOwner(self,"ANCHOR_LEFT")
			local text = self:GetText()
			GameTooltip:SetText(text)
			if data.override then
				local marks = MyAddon.GetMarksString(npcId,true,true)
				GameTooltip:AddLine("Default Marks:")
				GameTooltip:AddLine(marks,1,1,1)
			elseif data.default then
				local marks = MyAddon.GetMarksString(npcId,true,true)
				GameTooltip:AddLine("This NPC is marked by default.")
				GameTooltip:AddLine("Default Marks:")
				GameTooltip:AddLine(marks,1,1,1)			
				GameTooltip:AddLine("To override the default marking, change the settings and Update.")
			else
				GameTooltip:AddLine("This NPC is not marked by default.")
			end
			if data.pending then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("UPDATE PENDING",1,0.49,0.04)
				GameTooltip:AddLine("Save or Cancel changes before continuing.",1,0.49,0.04)
			end
			GameTooltip:Show()
		end
	)
	f:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

	frame.data.status = f
	
end

local l = -100
local n = 40

do

--	FILTER BUTTON
--	=============

local function GeneratorFunction(dropdown, rootDescription)
	rootDescription:CreateTitle("Show")
	for k,v in ipairs(FiltersList) do
		local text = v.text
		if v.heading then
			rootDescription:CreateTitle(text)
		else
			local radio = rootDescription:CreateCheckbox(text,dropdown.IsSelected,dropdown.SetSelected,v.name)
			if v.tooltip then
				radio:SetTooltip(function(tooltip, elementDescription)
					GameTooltip_SetTitle(tooltip,text)
					GameTooltip_AddNormalLine(tooltip,v.tooltip)
				end)
			end
		end
	end
	local arrow = CreateAtlasMarkup("common-icon-forwardarrow")
	dropdown:OverrideText("   Filter  " .. arrow)
end

local RadioDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle2DropdownTemplate")
RadioDropdown:SetupMenu(GeneratorFunction)
RadioDropdown:SetWidth(90)
RadioDropdown:SetPoint("TOPRIGHT",frame.head,"BOTTOMRIGHT",-23,-30)

function RadioDropdown.IsSelected(value)
	return MyAddon.Filters[value] == true
end

function RadioDropdown.SetSelected(value)
	local parent = RadioDropdown:GetParent()
	MyAddon.Filters[value] = not MyAddon.Filters[value]
	parent.data.instance:GenerateMenu()
-- If a default is shown and the option to show defaults has been turned off then clear entry.
	if frame.data.default and not MyAddon.Filters["DefaultNPCs"] then
		parent:ClearEdit()
		parent:EditEnable(false)
		parent:AllowUpdate(false)
	end
	for i,v in ipairs(FiltersList) do
		if not v.heading then
			if MyAddon.Filters[v.name] ~= v.default then
				frame.data.filterReset:Show()
				return
			end
		end
		frame.data.filterReset:Hide()
	end
end

local f = CreateFrame("Button",nil,RadioDropdown)
f:SetSize(23,23)
f:Hide()
f:SetPoint("CENTER",RadioDropdown,"TOPRIGHT",-3,-3)
f:SetNormalAtlas("auctionhouse-ui-filter-redx")
f:SetHighlightAtlas("auctionhouse-ui-filter-redx")
f:SetScript("OnClick",
	function(self)
		MyAddon.SetDefaultFilters()
		self:Hide()
		end
)

frame.data.filterReset = f

frame.data.filter = RadioDropdown

end

do

--	ID
--	==

	local function GeneratorFunction(dropdown, rootDescription)
	
		local selInst
		if dropdown.selectedValue then
			local x = MyAddon.AutoMark_Mobs[dropdown.selectedValue] or MyAddon.Mobs[dropdown.selectedValue] or {}
			if x.instanceID > 0 then
				selInst = x.instanceID
			end
		end
		
		local extent = 40
		local maxCharacters = 8
		local maxScrollExtent = extent * maxCharacters
		rootDescription:SetScrollMode(maxScrollExtent)

		local plus = CreateAtlasMarkup("bags-icon-addslots")
		rootDescription:CreateButton(plus.." |cFF00FF00New NPC|r", function(data) StaticPopup_Show("AUTOMARK_NEW_CUSTOM_NPC") end)
				
	local keys, keyList = MyAddon.GetInstances(selInst,true)

	local function compare(a,b)
		return a[1] < b[1]
	end

		for i,vv in ipairs(keys) do
		
			local npcTable = {}

			local n = 0

-- Default Mobs
			if MyAddon.Filters["DefaultNPCs"] then
				for k,v in pairs(MyAddon.Mobs) do
					if MyAddon.AutoMark_Mobs[k] == nil then	-- No Override
						if v.instanceID == vv[2] or (v.instanceID == nil and vv[2] == 0) then
							table.insert(npcTable,{k,v.name})
							n = n + 1
						end
					end
				end
			end

-- Custom/Override Mobs
			for k,v in pairs(MyAddon.AutoMark_Mobs) do
				if v.instanceID == vv[2] or (v.instanceID == nil and vv[2] == 0 )then
					table.insert(npcTable,{k,v.name})
					n = n + 1
				end
			end

			if n > 0 then
				table.sort(npcTable,compare)

				local title = vv[1] .. " (" .. vv[2] .. ")"
				
				if vv[2] < 1 then title = vv[1] end
				
				rootDescription:CreateTitle(title)

				for k,v in ipairs(npcTable) do
					local c = MyAddon.GetNPCColor(v[1])
					local marks = MyAddon.GetMarksString(v[1],false,false)
					local radio = rootDescription:CreateRadio("|cFF" .. c .. v[1] .. " " .. v[2] .. "|r" .. " " .. marks,
						dropdown.IsSelected,dropdown.SetSelected,v[1])
					radio:SetTooltip(function(tooltip, elementDescription)
						local id = radio:GetData()
						GameTooltip_SetTitle(tooltip,id)
						local x = MyAddon.AutoMark_Mobs[id]
						if x == nil then
							x = MyAddon.Mobs[id]
						end
						if x.instanceID == 0 then
							GameTooltip_AddNormalLine(tooltip,"Instance: ALL")
						elseif x.instanceID == -1 then
							GameTooltip_AddNormalLine(tooltip,"Instance: NONE")
						else
							GameTooltip_AddNormalLine(tooltip,"Instance: " .. MyAddon.Instances[x.instanceID].name)
						end
						if x.name then
							GameTooltip_AddNormalLine(tooltip,"Name: " .. x.name)
						end
						
						local marks = MyAddon.GetMarksString(id,false,true)
						GameTooltip_AddNormalLine(tooltip,"Marks: " .. marks)
						
						if MyAddon.Mobs[v[1]] and x.instanceID ~= MyAddon.Mobs[v[1]].instanceID then
							local iid = MyAddon.Mobs[v[1]].instanceID
							local instance = MyAddon.Instances[iid].name
							GameTooltip_AddErrorLine(tooltip,"Default is in " .. instance)
						end
						for _,key in ipairs({"creatureType","classification","level","power","hostile","attackable"}) do
							if x[key] ~= nil then
								GameTooltip_AddInstructionLine(tooltip,key .. ": " ..tostring(x[key]))
							end
						end
						
					end)
				end
				
				if vv[2] == selInst then
					rootDescription:CreateDivider()
				end
			end
		
		end
	end

	frame.data.id = Create_Dropdown("id","ID",frame,l,nil,GeneratorFunction)

	l = l - n
		
end


do

--	INSTANCE
--	========

	local function GeneratorFunction(dropdown, rootDescription)
	
		local extent = 40
		local maxCharacters = 8
		local maxScrollExtent = extent * maxCharacters
		rootDescription:SetScrollMode(maxScrollExtent)
		
		local instanceTable, keyList = MyAddon.GetInstances(dropdown.selectedValue,false)

		local selAdded = false
		
-- Create an entry for current selection if not already in list.
		if dropdown.selectedValue then
			local id = dropdown.selectedValue
			if MyAddon.Instances[id] and not keyList[id] then
				-- local c = MyAddon.GetInstanceColor(id)
				-- local text = "|cFF" ..c .. MyAddon.Instances[id].name .. "|r"
				local text = MyAddon.Instances[id].name
				if not MyAddon.DefaultInstances[id] then
					-- text = "|cFF" ..c .. MyAddon.Instances[id].name .. " (" .. id .. ")|r"
					text = MyAddon.Instances[id].name .. " (" .. id .. ")"
				end
				local radio = rootDescription:CreateRadio(text,
					dropdown.IsSelected,dropdown.SetSelected,id)		
				selAdded = true
			end
		end

		local r = 0
		
		for _,instanceTypeData in ipairs(MyAddon.InstanceTypeList) do
			local n = 0
			for k,v in ipairs(instanceTable) do
				if MyAddon.Instances[v[2]] and MyAddon.Instances[v[2]].instanceType == instanceTypeData[2] then
					r = r + 1
					if r == 1 and selAdded then
						rootDescription:CreateDivider()
					end
					n = n + 1
					if n == 1 then
						rootDescription:CreateTitle(instanceTypeData[1])
					end
					-- local c = MyAddon.GetInstanceColor(v[2])
					-- local text = "|cFF" ..c .. v[1] .. "|r"
					local text = v[1]
					if not MyAddon.DefaultInstances[v[2]] then
						-- text = "|cFF" ..c .. v[1] .. " (" .. v[2] .. ")|r"
						text = v[1] .. " (" .. v[2] .. ")"
					end
					local radio = rootDescription:CreateRadio(text,dropdown.IsSelected,dropdown.SetSelected,v[2])
				end
			end
		end

-- Create entry for "ALL".
		do
			rootDescription:CreateDivider()
			local radio = rootDescription:CreateRadio("ALL",dropdown.IsSelected,dropdown.SetSelected,0)
			radio:SetTooltip(function(tooltip, elementDescription)
				GameTooltip_SetTitle(tooltip,"ALL")
				GameTooltip_AddNormalLine(tooltip,"Used in all instances.")
			end)
		end

	end

	frame.data.instance = Create_Dropdown("instance","Instance",frame,l,295,GeneratorFunction)

	l = l - n
		
end

do

--	NAME
--	====

	local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
	title:SetPoint("TOPLEFT",frame,10,l)
	title:SetTextColor(1,0.8,0,1)
	title:SetText("Name:")
	local f = CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
	f:SetSize(290,32)
	f:SetAutoFocus(false)
	f:SetMaxLetters(80)
	f:SetNumeric(false)
	f:SetPoint("LEFT",title,90,0)
	f:HookScript("OnTextChanged", function(self) self:GetParent():CheckChanges("name") end)
	frame.data.name = f
	
	f.indicator = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
	f.indicator:SetPoint("RIGHT",f,"LEFT",-10,0)
	
	l = l - n

end

do

--	MARKS
--	=====

	local function GeneratorFunction(dropdown, rootDescription)

		for i, v in ipairs(MarksOptionList) do
			local radio = rootDescription:CreateRadio(v[1],
				dropdown.IsSelected,dropdown.SetSelected,i)
			radio:SetTooltip(function(tooltip, elementDescription)
				GameTooltip_SetTitle(tooltip,v[1])
				GameTooltip_AddNormalLine(tooltip,v[2])
			end)
		end
	
	end

	frame.data.marksOption = Create_Dropdown("marksOption","Marks",frame,l,nil,GeneratorFunction)
	
	l = l - n
		
end



do

--	NPC ICONS
--	=========

local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
title:SetPoint("TOPLEFT",frame,10,l)
title:SetTextColor(1,0.8,0,1)
title:SetText("")

local function onMarkChange(data)
	frame:CheckChanges("icons")
end

frame.data.icons = MyAddon.CreateIconGroup(8,frame,title,86,0,onMarkChange)

l = l - n
	
end

do

--	AUTO
--	====

	local function GeneratorFunction(dropdown, rootDescription)

		for i, v in ipairs(AutoList) do
			local radio = rootDescription:CreateRadio(v[1],
				dropdown.IsSelected,dropdown.SetSelected,i)
			radio:SetTooltip(function(tooltip, elementDescription)
				GameTooltip_SetTitle(tooltip,v[1])
				GameTooltip_AddNormalLine(tooltip,v[2])
			end)
		end
	
	end
	
	frame.data.auto = Create_Dropdown("auto","Auto",frame,l,nil,GeneratorFunction)
		
	l = l - n
		
end

do

--	SAVE BUTTON
--	===========

	local f = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
	f:SetText("Save")
	f:SetWidth(90)
	f:SetPoint("BOTTOMLEFT",frame,10,10)
	f:SetScript("OnClick",
		function(self)
			self:GetParent().data.msg:SetText("")
			local data = self:GetParent().data
			local x = {}
			local npcId = data.id.selectedValue
			npcId = tonumber(npcId)
			x.instanceID = data.instance.selectedValue
			x.marksOption = data.marksOption.selectedValue
			local iconGroupData = data.icons:GetValue()
			local marks = iconGroupData.string
			x.marks = MarksOptionList[data.marksOption.selectedValue][3] .. marks
			x.name = data.name:GetText()
			x.auto = AutoList[data.auto.selectedValue][3]
			if EnforceAutoNever then
				if x.auto == "never" then
					if marks ~= "" then
						self:GetParent().data.msg:SetText("Marks can't be set when Auto is Never.")
						return
					end
					if x.marksOption ~= 1 then
						self:GetParent().data.msg:SetText("Marks must be 'Standard' when Auto is Never.")
						return
					end
				end
			end
			local msg = MyAddon.MarksValid(x.marks)
			if msg then
				self:GetParent().data.msg:SetText(msg)
				return
			end
			msg = ""
			if x.marks == "" then x.marks = nil end
			if x.auto == "default" then x.auto = nil end
			if not MyAddon.AutoMark_Mobs[npcId] then
				MyAddon.AutoMark_Mobs[npcId] = {}
			end
			MyAddon.AutoMark_Mobs[npcId].instanceID = x.instanceID
			MyAddon.AutoMark_Mobs[npcId].name = x.name
			MyAddon.AutoMark_Mobs[npcId].marks = x.marks
			MyAddon.AutoMark_Mobs[npcId].auto = x.auto
			self:GetParent():UpdateEdit()
			self:GetParent().data.msg:SetText(msg)
			MyAddon.LoadMobs()
		end)
	frame.data.Save = f
end

do

--	CANCEL BUTTON
--	=============

	local f = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
	f:SetText("Cancel")
	f:SetWidth(90)
	f:SetPoint("BOTTOMLEFT",frame,110,10)
	f:SetScript("OnClick",
		function(self)
			self:GetParent():UpdateEdit()
			self:GetParent().data.msg:SetText("")
		end)
	frame.data.Cancel = f
end

do

--	REMOVE BUTTON
--	=============

	local f = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
	f:SetText("Remove")
	f:SetWidth(90)
	f:SetPoint("BOTTOMLEFT",frame,210,10)
	f:SetScript("OnClick",
		function(self)
			self:GetParent().data.msg:SetText("")
			local data = self:GetParent().data
			local npcId = data.id.selectedValue
			if npcId == nil then return end
			npcId = tonumber(npcId)
			local name = MyAddon.AutoMark_Mobs[npcId].name
			local text = "Remove NPC"
			if data.override then
				text = "Remove Override for NPC"
			end
			text = text .. "\nID: " .. npcId
			if name and name ~= "" then
				text = text .. "\nName: " .. name
			end
			text = text .. "?"
			local dialog = StaticPopup_Show("AUTOMARK_DELETE_CUSTOM_NPC",text)
			if dialog then
				dialog.data = npcId
			end
		end)
	frame.data.Delete = f
end

frame.EditEnable =
	function(self,enable)
		if enable then
			if not self.data.default and not self.data.override then
				self.data.instance:Enable()
				self.data.name:Enable()
				self.data.name:SetTextColor(1,1,1)
			end
			self.data.marksOption:Enable()
			self.data.icons:Enable()
			self.data.auto:Enable()
			if not self.data.default then
				self.data.Delete:Enable()
			end
		else
			self.data.instance:Disable()
			self.data.name:Disable()
			self.data.name:SetTextColor(0.62,0.62,0.62)
			self.data.marksOption:Disable()
			self.data.icons:Disable()
			self.data.auto:Disable()
			self.data.Delete:Disable()
		end
	end

frame.AllowUpdate =
	function(self,allow)
		if allow then
			self.data.id:Disable()
			self.data.Save:Enable()
			self.data.pending = true
			self:SetMessage()
			self.data.Cancel:Enable()
		else
			self.data.id:Enable()
			self.data.Save:Disable()
			self.data.pending = false
			self:SetMessage()
			self.data.Cancel:Disable()
		end
	end

frame.CheckChanges =
	function(self,tag)
		local data = self.data
		local change = false
		self.data.msg:SetText("")
		self:ClearChangeIndicators()
		local iconGroupData = self.data.icons:GetValue()
		local marks = iconGroupData.string
		if self.data.id.selectedValue == nil then
			self:AllowUpdate(false)
			return
		end
		if data.instance.selectedValue ~= data.instance.value then
			change = true
			self:SetChangeIndicator(data.instance,true)
		end
		if data.name:GetText() ~= data.name.value then
			change = true
			self:SetChangeIndicator(data.name,true)
		end
		if data.marksOption.selectedValue ~= data.marksOption.value then
			change = true
			self:SetChangeIndicator(data.marksOption,true)
		end
		if marks ~= data.icons.value then
			change = true
			self:SetChangeIndicator(data.icons,true)
		end
		if data.auto.selectedValue ~= data.auto.value then
			change = true
			self:SetChangeIndicator(data.auto,true)
		end
		if change then
			self:AllowUpdate(true)
		else
			self:AllowUpdate(false)
		end
	end
	
frame.ClearEdit =
	function(self)
		self:ClearChangeIndicators()
		self.data.msg:SetText("")
		self.data.id.selectedValue = nil
		self.data.id:Update()
		self.data.instance.selectedValue = nil
		self.data.instance:Update()
		self.data.marksOption.selectedValue = nil
		self.data.marksOption:Update()
		self.data.icons:SetValue("")
		self.data.name:SetText("")
		self.data.auto.selectedValue = nil
		self.data.auto:Update()
		self.data.status:SetText("")
		self:EditEnable(false)
		self:AllowUpdate(false)
	end

frame.UpdateEdit =
	function(self,id)
		local npcId = id
		self.data.msg:SetText("")
		if npcId == nil then
			npcId = self.data.id.selectedValue
			npcId = tonumber(npcId)
		end
		self:EditEnable(false)
		self:AllowUpdate(false)
		if npcId then
			local data
			self.data.default = false
			self.data.override = false
			if MyAddon.AutoMark_Mobs[npcId] then
				data = MyAddon.AutoMark_Mobs[npcId]
				if MyAddon.Mobs[npcId] then
					self.data.override = true
				end
			else
				self.data.default = true
				data = MyAddon.Mobs[npcId] or {}
			end
			self:EditEnable(true)	
			local instanceID = data.instanceID or 0
			local marks = data.marks or ""
			local m = string.sub(marks,1,1)
			local marksOption = 1
			if m ~= "" then
				for i = 1, #MarksOptionList do
					if MarksOptionList[i][3] == m then
						marksOption = i
						marks = string.sub(marks,2)
						break
					end
				end
			end
			local name = data.name or ""
			local auto = data.auto or "default"

			self.data.instance.value = instanceID
			self.data.instance.selectedValue = instanceID
			self.data.instance:Update()
			self.data.instance:GenerateMenu()

			self.data.marksOption.value = marksOption
			self.data.marksOption.selectedValue = marksOption
			self.data.marksOption:Update()

			self.data.id:Update()
			self.data.id:GenerateMenu()
			
			self.data.icons.value = marks
			self.data.icons:SetValue(marks)
			
			self.data.name.value = name
			self.data.name:SetText(name)
			for i = 1,#AutoList do
				if AutoList[i][3] == auto then
					self.data.auto.value = i
					self.data.auto.selectedValue = i
					self.data.auto:Update()
					break
				end
			end
			self:SetMessage()
			self:ClearChangeIndicators()
		end
	end

frame.SetMessage =
	function(self)
		local npcId = self.data.id.selectedValue
		if not npcId then return end
		local message
		local c = MyAddon.GetNPCColor(npcId)
		local npcType
		if self.data.default then
			npcType = "DEFAULT"
		else
			if MyAddon.Mobs[npcId] then
				npcType = "OVERRIDE"
			else
				npcType = "CUSTOM"
			end
		end
		if self.data.pending then
			npcType = npcType .. "*"
		end
		message = "|cFF" .. c .. npcType .. "|r"
		self.data.status:SetText(message)
	end

frame.ClearChangeIndicators =
	function(self)
		local data = self.data
		self:SetChangeIndicator(data.instance,false)
		self:SetChangeIndicator(data.name,false)
		self:SetChangeIndicator(data.marksOption,false)
		self:SetChangeIndicator(data.icons,false)
		self:SetChangeIndicator(data.auto,false)
	end

frame.SetChangeIndicator =
	function(self,object,set)
		local useIndicator = true
		local useColor = false
		local c,r,g,b = "",1,1,1
		if set then
			c,r,g,b = changeMarker,0,1,0
		end
		if useIndicator then
			if object.indicator then
				object.indicator:SetText(c)
			end
		end
		if useColor then
			local objectType = object:GetObjectType()
			if objectType == "EditBox" then
				object.Left:SetVertexColor(r,g,b)
				object.Middle:SetVertexColor(r,g,b)
				object.Right:SetVertexColor(r,g,b)
			elseif objectType == "Button" then
				object.Background:SetVertexColor(r,g,b)
			elseif objectType == "IconGroup" then
				object:SetVertexColor(r,g,b)
			end
		end
	end
	
frame:EditEnable(false)
frame:AllowUpdate(false)

MyAddon.ConfigTabPage[1] = frame

return frame

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.MarksValid(marks)

local m = {0,0,0,0,0,0,0,0}

local prefix
	
for i = 1, string.len(marks) do

	local x = string.sub(marks,i,i)
	
	if i == 1 and (x == "*" or x == "+" or x == "!") then
		prefix = x
	else
		if not string.match(x,"%d") then
			return "Marks must be digits 1-8."
		end
		local n = tonumber(x)
		if n < 1 or n > 8 then
			return "Marks must be digits 1-8."
		end
		if m[n] ~= 0 then
			return "Marks must not contain duplicates."
		end
		m[n] = 1
	end
	
end

if prefix and string.len(marks) < 2 then
	return "Must be at least one mark for this option."
end

if prefix == "!" and string.len(marks) > 2 then
	return "Must only be one mark for this option."
end

return nil

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.GetNPCColor(npcId)

local c = NPCColors["Default"]

if MyAddon.AutoMark_Mobs[npcId] then
	if not MyAddon.Mobs[npcId] then
		if MyAddon.AutoMark_Mobs[npcId].auto == "never" then
			c = NPCColors["CustomNever"]
		else
			c = NPCColors["Custom"]
		end
	else
		if MyAddon.AutoMark_Mobs[npcId].instanceID ~= MyAddon.Mobs[npcId].instanceID then
			c = NPCColors["OverrideWarn"]
		elseif MyAddon.AutoMark_Mobs[npcId].auto == "never" then
			c = NPCColors["OverrideNever"]
		else
			if MyAddon.AutoMark_Mobs[npcId].auto == MyAddon.Mobs[npcId].auto and
				MyAddon.AutoMark_Mobs[npcId].marks == MyAddon.Mobs[npcId].marks then
				c = NPCColors["OverrideSame"]
			else
				c = NPCColors["Override"]
			end
		end
	end
end

return c

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.GetInstanceColor(instanceID)

local c = NPCColors["Default"]

if not MyAddon.DefaultInstances[instanceID] then c = NPCColors["Custom"] end

return c

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.GetMarksString(npcId,default,verbose)

local data

if default or MyAddon.AutoMark_Mobs[npcId] == nil then
	data = MyAddon.Mobs[npcId]
else
	data = MyAddon.AutoMark_Mobs[npcId]
end

if data == nil then return "" end

if data.auto == "never" then
	return "<NONE>"
end

-- if data.marks == nil and data.auto == nil then
	-- return "<STANDARD>"
-- end

local marks = data.marks or ""

local auto = data.auto or "default"

local x = string.sub(marks,1,1)

local prefix = ""

if x == "*" or x == "+" or x == "!" then
	prefix = x
	marks = string.sub(marks,2)
end

local buffer = ""

local icons = ""

for c in string.gmatch(marks,"%d") do
	local n = tonumber(c)
	icons = icons .. MyAddon.Marks[n].icon
end

buffer = buffer .. icons

if verbose then
	local marksOption
	for i = 1, #MarksOptionList do
		if MarksOptionList[i][3] == prefix then
			marksOption = MarksOptionList[i][1]
			break
		end
	end
	if marksOption then
		if buffer == "" then
			buffer = marksOption
		else
			buffer = marksOption .. " " .. buffer
		end
	end
	local autoOption
	if auto ~= "default" then
		for i = 1, #AutoList do
			if AutoList[i][3] == auto then
				autoOption = AutoList[i][1]
				break
			end
		end
	end
	if autoOption then
		buffer = buffer .. " " .. autoOption
	end
end

return buffer


end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.CreateMarksFrame(parent)

local frame = CreateFrame("Frame",addonName.."MarksFrame",parent)

frame:Hide()

frame:SetPoint("TOPLEFT")
frame:SetPoint("BOTTOMRIGHT")

frame.head = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
frame.head:SetWidth(500)
frame.head:SetPoint("TOPLEFT",frame,10,-15)
frame.head:SetJustifyH("LEFT")
frame.head:SetText(addonName.." Marks")

frame:SetScript("OnShow",
	function(self)
		local marks = {}
		for i, role in ipairs(Roles) do
			local mark = MyAddon.PlayerMarks[role]
			table.insert(marks,mark)
		end
		frame.data.mark:SetValue(marks)
		frame.data.npcMark:SetValue(MyAddon.Icons)
		self:CheckDefaults()
	end)

frame.CheckDefaults =
	function(self)
		local change = false
		for _,role in ipairs(Roles) do
			if MyAddon.PlayerMarks[role] ~= MyAddon.DefaultPlayerMarks[role] then
				change = true
			end
		end
		if MyAddon.Icons ~= MyAddon.DefaultIcons then
			change = true
		end
		if change then
			frame.data.reset:Enable()
		else
			frame.data.reset:Disable()
		end
	end
	
local l = -100
local n = 40

frame.data = {}

do

--	ROLE MARKS
--	==========

local roleTitles = {}

for i,role in ipairs(Roles) do

	local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
	title:SetPoint("TOPLEFT",frame,10,l)
	title:SetTextColor(1,0.8,0,1)
	local r = string.sub(role,1,1) .. string.lower(string.sub(role,2))
	title:SetText(r .. ":")
	roleTitles[i] = title
	l = l - n
	
end

	local function markChanged(data)
		for i = 1,2 do
			local role = Roles[i]
			if data.values[i] ~= MyAddon.PlayerMarks[role] then
				MyAddon.SetRoleMark(role,data.values[i])
			end
		end
		frame:CheckDefaults()
	end
	
	frame.data.mark = MyAddon.CreateIconGroup(2,frame,roleTitles,86,0,markChanged)
	
end


do

--	NPC MARKS
--	=========

local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
title:SetPoint("TOPLEFT",frame,10,l)
title:SetTextColor(1,0.8,0,1)
title:SetText("NPCs:")

frame.data.npcMark = MyAddon.CreateIconGroup(8,frame,title,86,0,function(data) MyAddon.SetIcons(data.string) frame:CheckDefaults() end)

l = l - n

end

do

--	RESET TO DEFAULTS BUTTON
--	========================

	local f = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
	f:SetText("Reset to defaults")
	f:SetWidth(120)
	f:SetPoint("BOTTOMLEFT",frame,10,10)
	f:SetScript("OnClick", function(self)
	-- Set Defaults
		local marks = {}
		for i, role in ipairs(Roles) do
			local mark = MyAddon.DefaultPlayerMarks[role]
			table.insert(marks,mark)
			MyAddon.SetRoleMark(role)
		end
		frame.data.mark:SetValue(marks)
		frame.data.npcMark:SetValue(MyAddon.DefaultIcons)
		MyAddon.SetIcons()
		frame:CheckDefaults()
	end)

	frame.data.reset = f
	
end	

MyAddon.ConfigTabPage[3] = frame

return frame

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.CreateIconGroup(nMarks,frame,relativeFrame,ofsx,ofsy,onChange)

-- Create an IconGroup.

local disableDuplicates = false

local marks = {}

for k = 1,nMarks do

	local function GeneratorFunction(dropdown, rootDescription)

		rootDescription:CreateRadio("",dropdown.IsSelected,dropdown.SetSelected,0)
		for i, v in ipairs(MyAddon.Marks) do
			local radio = rootDescription:CreateRadio(v.icon,dropdown.IsSelected,dropdown.SetSelected,i)
			if disableDuplicates then
				for n = 1,nMarks do
					if n ~= k and marks[n] and marks[k] then
						if marks[n].selectedValue == i then
							radio:SetEnabled(false)
						end
					end
				end
			end
		end


		if nMarks > 2 then
			rootDescription:CreateDivider()
			rootDescription:CreateButton(
				"|cFF00FF00Insert|r",
				function()
					for i = nMarks-1, k, -1 do
						marks[i+1].selectedValue = marks[i].selectedValue
						marks[i+1]:GenerateMenu()
						marks[i]:GenerateMenu()
					end
					marks[k].selectedValue = 0
					marks[k]:GenerateMenu()
					marks[k].SetSelected(0)
				end)
		rootDescription:CreateButton(
				"|cFF00FF00Delete|r",
				function()
					for i = k, nMarks do
						if i < nMarks then
							marks[i].selectedValue = marks[i+1].selectedValue
							marks[i]:GenerateMenu()
							marks[i+1]:GenerateMenu()
						else
							marks[i].selectedValue = 0
							marks[i]:GenerateMenu()
						end
					end
					marks[1].SetSelected(marks[1].selectedValue)
				end)
		rootDescription:CreateButton(
				"|cFF00FF00Clear|r",
				function()
					for i = 1, nMarks do
						marks[i].selectedValue = 0
						marks[i]:GenerateMenu()
					end
					marks[1].SetSelected(marks[1].selectedValue)
				end)
		end


		
	end
	
	local RadioDropdown = CreateFrame("DropdownButton", nil, frame, DropdownTemplate)

	RadioDropdown.id = k
	
	RadioDropdown:SetupMenu(GeneratorFunction)
		
	RadioDropdown:SetWidth(40)
	RadioDropdown:SetDefaultText("")

	if relativeFrame[1] then
		RadioDropdown:SetPoint("LEFT",relativeFrame[k],ofsx,ofsy)
	else
		if k == 1 then
			RadioDropdown:SetPoint("LEFT",relativeFrame,ofsx,ofsy)
		else
			RadioDropdown:SetPoint("LEFT",marks[k-1],"RIGHT",3,0)
		end
	end

	RadioDropdown.selectedValue = nil

	function RadioDropdown.IsSelected(value)
		return value == RadioDropdown.selectedValue
	end

	function RadioDropdown.SetSelected(value)
		RadioDropdown.selectedValue = value
		for i = 1,nMarks do
			if marks[i].id ~= RadioDropdown.id then
				if marks[i].selectedValue == RadioDropdown.selectedValue then
					marks[i].selectedValue = 0
					marks[i]:GenerateMenu()
				end
			end
		end
		local data = {}
		data.id = RadioDropdown.id
		data.values = {}
		data.string = ""
		for i = 1,nMarks do
			data.values[i] = marks[i].selectedValue
			if marks[i].selectedValue > 0 then
				data.string = data.string .. marks[i].selectedValue
			end
		end
		if onChange ~= nil then
			onChange(data)
		end
	end

	marks[k] = RadioDropdown

end

marks.indicator = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
marks.indicator:SetPoint("RIGHT",marks[1],"LEFT",-6,0)
	
marks.GetObjectType = function() return "IconGroup" end

marks.SetValue = function(self,icons)

-- Set IconGroup from a string or an array.

	for i,a in ipairs(self) do
		a.selectedValue = 0
	end

	if type(icons) == "string" then
		for i = 1,string.len(icons) do
			self[i].selectedValue = tonumber(string.sub(icons,i,i))
		end
	else
		for i,icon in ipairs(icons) do
			self[i].selectedValue = icon
		end
	end

	for i,a in ipairs(self) do
		a:GenerateMenu()
	end

end


marks.GetValue = function(self)

-- Get the value of the IconGroup.
-- Returns a table:
--	string = a string containing the icon indexes
--	values = an array containing the icon indexes

	local data = {}

	data.values = {}

	data.string = ""

	for i,a in ipairs(self) do
		data.values[i] = self[i].selectedValue
		if self[i].selectedValue and self[i].selectedValue > 0 then
			data.string = data.string .. self[i].selectedValue
		end
	end

	return data

end

marks.Enable = function(self)
	for i,a in ipairs(self) do
		a:Enable()
	end
end

marks.Disable = function(self)
	for i,a in ipairs(self) do
		a:Disable()
	end
end

marks.SetVertexColor = function(self,...)
	for i,a in ipairs(self) do
		a.Background:SetVertexColor(...)
	end
end

return marks

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.CreateOptionsFrame(parent)

local frame = CreateFrame("Frame",addonName.."OptionsFrame",parent)

frame:Hide()

frame:SetPoint("TOPLEFT")
frame:SetPoint("BOTTOMRIGHT")

frame.head = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
frame.head:SetWidth(500)
frame.head:SetPoint("TOPLEFT",frame,10,-15)
frame.head:SetJustifyH("LEFT")
frame.head:SetText(addonName.." Options")

frame:SetScript("OnShow",
	function(self)
		for _,name in ipairs(ConfigNames) do
			self.data.checkbox[name]:SetChecked(MyAddon.AutoMark_DB[name])
		end
		self:CheckDefaults()
	end)

frame.CheckDefaults =
	function(self)
		local change = false
		for _,name in ipairs(ConfigNames) do
			if MyAddon.AutoMark_DB[name] ~= ConfigData[name].default then
				change = true
			end
		end
		if change then
			frame.data.reset:Enable()
		else
			frame.data.reset:Disable()
		end
	end
	
local l = -100
local n = 40

frame.data = {}
frame.data.checkbox = {}

for _,name in ipairs(ConfigNames) do
	local data = ConfigData[name]
	local f = Create_Checkbox(name,data,frame)
	f:SetPoint("TOPLEFT",frame,10,l)
	frame.data.checkbox[name] = f
	l = l - n
end


do

	local f = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
	f:SetText("Reset to defaults")
	f:SetWidth(120)
	f:SetPoint("BOTTOMLEFT",frame,10,10)
	f:SetScript("OnClick", function(self)
		for _,name in ipairs(ConfigNames) do
			local data = ConfigData[name]
			MyAddon.AutoMark_DB[name] = data.default
			if data.onChange then
				data.onChange()
			end
			self:GetParent().data.checkbox[name]:SetChecked(MyAddon.AutoMark_DB[name])
		end
		frame:CheckDefaults()
	end)

	frame.data.reset = f
	
end	


MyAddon.ConfigTabPage[4] = frame

return frame

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.CreateInstancesFrame(parent)

local frame = CreateFrame("Frame",addonName.."InstancesFrame",parent)

frame:Hide()

frame:SetPoint("TOPLEFT")
frame:SetPoint("BOTTOMRIGHT")

frame.head = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
frame.head:SetWidth(500)
frame.head:SetPoint("TOPLEFT",frame,10,-15)
frame.head:SetJustifyH("LEFT")
frame.head:SetText(addonName.." Custom Instances")

frame.data = {}

do

--	MSG
--	===

	local f = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
	f:SetWidth(1000)
	f:SetPoint("BOTTOMLEFT",frame,10,40)
	f:SetJustifyH("LEFT")
	f:SetTextColor(0.77,0.12,0.23)

	frame.data.msg = f

end

local l = -80-20
local n = 40

do

--	INSTANCE ID
--	===========

	local function GeneratorFunction(dropdown, rootDescription)
	
		local extent = 40
		local maxCharacters = 8
		local maxScrollExtent = extent * maxCharacters
		rootDescription:SetScrollMode(maxScrollExtent)

		local plus = CreateAtlasMarkup("bags-icon-addslots")
		rootDescription:CreateButton(plus.." |cFF00FF00New Instance|r", function(data) StaticPopup_Show("AUTOMARK_NEW_INSTANCE") end)
				
		local instanceTable = {}
		for k,v in pairs(MyAddon.AutoMark_Instances) do
			table.insert(instanceTable,{k,v.name})
		end
		
		function compare(a,b)
			return a[1] < b[1]
		end

		table.sort(instanceTable,compare)

		for _,v in ipairs(instanceTable) do
			local c = "FFFFFF"
			if MyAddon.DefaultInstances[v[1]] then
				c = "9D9D9D"
			end
			rootDescription:CreateRadio("|cFF" .. c .. v[1] .. " " .. v[2] .. "|r",dropdown.IsSelected,dropdown.SetSelected,v[1])
		end

	end
		
	frame.data.id = Create_Dropdown("id","ID",frame,l,nil,GeneratorFunction)

	l = l - n
		
end


do

--	NAME
--	====

	local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
	title:SetPoint("TOPLEFT",frame,10,l)
	title:SetTextColor(1,0.8,0,1)
	title:SetText("Name:")
	local f = CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
	f:SetSize(290,32)
	f:SetAutoFocus(false)
	f:SetMaxLetters(80)
	f:SetNumeric(false)
	f:SetPoint("LEFT",title,90,0)
	f:HookScript("OnTextChanged", function(self) self:GetParent():CheckChanges("name") end)
	frame.data.name = f
	
	f.indicator = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
	f.indicator:SetPoint("RIGHT",f,"LEFT",-10,0)
	
	l = l - n

end

do

--	INSTANCE TYPE
--	=============

	local function GeneratorFunction(dropdown, rootDescription)

		for i, v in ipairs(MyAddon.InstanceTypeList) do
			local radio = rootDescription:CreateRadio(v[1],
				dropdown.IsSelected,dropdown.SetSelected,i)
		end
	
	end
	
	frame.data.instanceType = Create_Dropdown("instanceType","Type",frame,l,nil,GeneratorFunction)

	l = l - n
		
end

do

--	SAVE BUTTON
--	===========

	local f = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
	f:SetText("Save")
	f:SetWidth(90)
	f:SetPoint("BOTTOMLEFT",frame,10,10)
	f:SetScript("OnClick",
		function(self)
			self:GetParent().data.msg:SetText("")
			local data = self:GetParent().data
			local instanceId = data.id.selectedValue
			instanceId = tonumber(instanceId)
			local name = data.name:GetText()
			local instanceType = MyAddon.InstanceTypeList[data.instanceType.selectedValue][2]
			MyAddon.AutoMark_Instances[instanceId] = {name = name, instanceType = instanceType}
			MyAddon.LoadInstances()
			self:GetParent():UpdateEdit()
		end)
	frame.data.Save = f
end

do

--	CANCEL BUTTON
--	=============

	local f = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
	f:SetText("Cancel")
	f:SetWidth(90)
	f:SetPoint("BOTTOMLEFT",frame,110,10)
	f:SetScript("OnClick",
		function(self)
			self:GetParent():UpdateEdit()
			self:GetParent().data.msg:SetText("")
		end)
	frame.data.Cancel = f
end

do

--	REMOVE BUTTON
--	=============

	local f = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
	f:SetText("Remove")
	f:SetWidth(90)
	f:SetPoint("BOTTOMLEFT",frame,210,10)
	f:SetScript("OnClick",
		function(self)
			self:GetParent().data.msg:SetText("")
			local data = self:GetParent().data
			local instanceId = data.id.selectedValue
			if instanceId == nil then return end
			instanceId = tonumber(instanceId)
			local text = ""
			for k,v in pairs(AutoMark_Mobs) do
				if v.instanceID == instanceId then
					self:GetParent().data.msg:SetText("Instance is in use.")
					return
				end
			end
			local name = MyAddon.AutoMark_Instances[instanceId].name
			text = "Remove Instance"
			text = text .. "\nID: " .. instanceId
			if name and name ~= "" then
				text = text .. "\nName: " .. name
			end
			text = text .. "?"
			local dialog = StaticPopup_Show("AUTOMARK_DELETE_INSTANCE",text)
			if dialog then
				dialog.data = instanceId
			end
		end)
	frame.data.Delete = f
end

frame.EditEnable =
	function(self,enable)
		if enable then
			self.data.name:Enable()
			self.data.name:SetTextColor(1,1,1)
			self.data.instanceType:Enable()
			self.data.Delete:Enable()
		else
			self.data.name:Disable()
			self.data.name:SetTextColor(0.62,0.62,0.62)
			self.data.instanceType:Disable()
			self.data.Delete:Disable()
		end
	end

frame.AllowUpdate =
	function(self,allow)
		if allow then
			self.data.id:Disable()
			self.data.Save:Enable()
			self.data.pending = true
			self:SetMessage()
			self.data.Cancel:Enable()
		else
			self.data.id:Enable()
			self.data.Save:Disable()
			self.data.pending = false
			self:SetMessage()
			self.data.Cancel:Disable()
		end
	end

frame.CheckChanges =
	function(self,tag)
		local data = self.data
		local change = false
		self.data.msg:SetText("")
		self:ClearChangeIndicators()
		if self.data.id.selectedValue == nil then
			self:AllowUpdate(false)
			return
		end
		if data.name:GetText() ~= data.name.value then
			change = true
			self:SetChangeIndicator(data.name,true)
		end
		if data.instanceType.selectedValue ~= data.instanceType.value then
			change = true
			self:SetChangeIndicator(data.instanceType,true)
		end
		if change then
			self:AllowUpdate(true)
		else
			self:AllowUpdate(false)
		end
	end
	
frame.ClearEdit =
	function(self)
		self:ClearChangeIndicators()
		self.data.msg:SetText("")
		self.data.id.selectedValue = nil
		self.data.id:Update()
		self.data.name:SetText("")
		self.data.instanceType.selectedValue = nil
		self.data.instanceType:Update()
		self:EditEnable(false)
		self:AllowUpdate(false)
	end

frame.UpdateEdit =
	function(self,id)
		local instanceId = id
		self.data.msg:SetText("")
		if instanceId == nil then
			instanceId = self.data.id.selectedValue
			instanceId = tonumber(instanceId)
		end
		self:EditEnable(false)
		self:AllowUpdate(false)
		if instanceId then
			local data
			self.data.default = false
			local name = MyAddon.AutoMark_Instances[instanceId].name or ""
			local instanceType = MyAddon.AutoMark_Instances[instanceId].instanceType or "other"
			self:EditEnable(true)

			self.data.id:Update()
			self.data.id:GenerateMenu()
			
			self.data.name.value = name
			self.data.name:SetText(name)
			if MyAddon.DefaultInstances[instanceId] then
				self.data.name:SetTextColor(0.62,0.62,0.62)
			else
				self.data.name:SetTextColor(1,1,1)
			end
			for i = 1,#MyAddon.InstanceTypeList do
				if MyAddon.InstanceTypeList[i][2] == instanceType then
					self.data.instanceType.value = i
					self.data.instanceType.selectedValue = i
					self.data.instanceType:Update()
					break
				end
			end
			self:SetMessage()
			self:ClearChangeIndicators()
		end
	end

frame.SetMessage =
	function(self)
	end

frame.ClearChangeIndicators =
	function(self)
		local data = self.data
		self:SetChangeIndicator(data.name,false)
		self:SetChangeIndicator(data.instanceType,false)
	end

frame.SetChangeIndicator =
	function(self,object,set)
		local useIndicator = true
		local useColor = false
		local c,r,g,b = "",1,1,1
		if set then
			c,r,g,b = changeMarker,0,1,0
		end
		if useIndicator then
			if object.indicator then
				object.indicator:SetText(c)
			end
		end
		if useColor then
			local objectType = object:GetObjectType()
			if objectType == "EditBox" then
				object.Left:SetVertexColor(r,g,b)
				object.Middle:SetVertexColor(r,g,b)
				object.Right:SetVertexColor(r,g,b)
			elseif objectType == "Button" then
				object.Background:SetVertexColor(r,g,b)
			elseif objectType == "IconGroup" then
				object:SetVertexColor(r,g,b)
			end
		end
	end
	
frame:EditEnable(false)
frame:AllowUpdate(false)

MyAddon.ConfigTabPage[2] = frame

return frame

end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function MyAddon.RegisterOptions()

local f = CreateFrame("Frame",nil)

f.name = addonName

if SettingsPanel then
	local category = Settings.RegisterCanvasLayoutCategory(f,addonName)
	Settings.RegisterAddOnCategory(category)
else
	InterfaceOptions_AddCategory(f)
end

f:Hide()

-- f:SetScript("OnShow",function (self)
	-- if SettingsPanel then
		-- if SettingsPanel:IsShown() then
			-- HideUIPanel(SettingsPanel)
		-- end
	-- else
		-- if InterfaceOptionsFrame:IsShown() then
			-- InterfaceOptionsFrame:Hide()
		-- end
	-- end
	-- MyAddon.ShowConfig()
	-- self:SetScript("OnShow",nil)
-- end)

f.button = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
f.button:SetText(addonName)
f.button:SetSize(400,25)
f.button:SetPoint("TOP",0,-100)
f.button:SetScript("OnClick",
function()
	if SettingsPanel then
		if SettingsPanel:IsShown() then
			HideUIPanel(SettingsPanel)
		end
	else
		if InterfaceOptionsFrame:IsShown() then
			InterfaceOptionsFrame:Hide()
		end
	end
	MyAddon.ShowConfig()
end)

end
--------------------------------------------------------------------------------

MyAddon.RegisterOptions()
