local _G = getfenv(0)

FramesResized_SV = FramesResized_SV or {}
FramesResized_SV.GuildUI_Resize         = FramesResized_SV.GuildUI_Resize ~= nil         and FramesResized_SV.GuildUI_Resize         or true
FramesResized_SV.GuildUI_Moveable       = FramesResized_SV.GuildUI_Moveable ~= nil       and FramesResized_SV.GuildUI_Moveable       or true
FramesResized_SV.LootFrame_Resize       = FramesResized_SV.LootFrame_Resize ~= nil       and FramesResized_SV.LootFrame_Resize       or true
FramesResized_SV.RaidInfo_Resize        = FramesResized_SV.RaidInfo_Resize ~= nil        and FramesResized_SV.RaidInfo_Resize        or true
FramesResized_SV.TradeSkillUI_Resize    = FramesResized_SV.TradeSkillUI_Resize ~= nil    and FramesResized_SV.TradeSkillUI_Resize    or true
FramesResized_SV.TradeSkillUI_Moveable  = FramesResized_SV.TradeSkillUI_Moveable ~= nil  and FramesResized_SV.TradeSkillUI_Moveable  or true
FramesResized_SV.TrainerUI_Resize       = FramesResized_SV.TrainerUI_Resize ~= nil       and FramesResized_SV.TrainerUI_Resize       or true
FramesResized_SV.TrainerUI_Moveable     = FramesResized_SV.TrainerUI_Moveable ~= nil     and FramesResized_SV.TrainerUI_Moveable     or true


local original_GuildNews_Update
local original_LootFrame_OnShow

local additionalFrameHeight = 128

-- -----
-- Hook Functions
-- -----

local function FR_Hooks_GuildNews_Update()
	original_GuildNews_Update()
	if ( CanReplaceGuildMaster() ) then
		GuildNewsContainer:SetHeight(277 + additionalFrameHeight)
	else
		GuildNewsContainer:SetHeight(287 + additionalFrameHeight)
	end
end

local function FR_Hooks_LootFrame_OnShow(self)
	if GetNumLootItems() > LOOTFRAME_NUMBUTTONS_ORG then
		LootFrame:SetHeight(240 + LOOTFRAME_ADDBUTTONS * 41)
	else
		LootFrame:SetHeight(240)
	end
	original_LootFrame_OnShow(self)
end

-- -----
-- Resize/Moveable Functions
-- -----

local function FR_GuildUI_Resize()
	local GUILD_ROSTER_BUTTON_OFFSET = 2 -- Blizzard_GuildRoster.lua

	GuildFrame:SetHeight(424 + additionalFrameHeight)

	GuildInfoFrameInfoBar2Left:SetPoint("TOP", GuildInfoFrameInfo, "BOTTOM", 0, 128 + additionalFrameHeight * 0.75)
	GuildInfoFrameInfoMOTDScrollFrame:SetHeight(42 + additionalFrameHeight * 0.25)
	GuildInfoMOTD:SetHeight(42 + additionalFrameHeight * 0.25)
	GuildInfoDetailsFrame:SetHeight(85 + additionalFrameHeight * 0.75)

	GuildNewsContainer:SetHeight(305 + additionalFrameHeight)
	HybridScrollFrame_CreateButtons(GuildNewsContainer, "GuildNewsButtonTemplate", 0, 0)

	GuildPerksContainer:SetHeight(326 + additionalFrameHeight)
	HybridScrollFrame_CreateButtons(GuildPerksContainer, "GuildPerksButtonTemplate", 8, 0, "TOPLEFT", "TOPLEFT", 0, 0, "TOP", "BOTTOM")
	GuildPerksContainer.height = 326 + additionalFrameHeight
	GuildPerksContainer.heightNoScroll = 310 + additionalFrameHeight
	
	-- fix background heights; has no name so scan over all textures for the frame
	for _, region in pairs({GuildAllPerksFrame:GetRegions()}) do
		if region:IsObjectType("Texture") and math.floor(region:GetHeight() + 0.5) == 326 then
			region:SetHeight(326 + additionalFrameHeight)
		end
	end

	GuildRewardsContainer:SetHeight(306 + additionalFrameHeight)
	HybridScrollFrame_CreateButtons(GuildRewardsContainer, "GuildRewardsButtonTemplate", 1, 0)
	GuildRewardsFrameBg:SetHeight(308 + additionalFrameHeight)

	GuildRosterContainer:SetHeight(300 + additionalFrameHeight)
	HybridScrollFrame_CreateButtons(GuildRosterContainer, "GuildRosterButtonTemplate", 0, 0, "TOPLEFT", "TOPLEFT", 0, -GUILD_ROSTER_BUTTON_OFFSET, "TOP", "BOTTOM")
	GuildRoster_SetView(GetCVar("guildRosterView"))

	original_GuildNews_Update = GuildNews_Update
	GuildNews_Update = FR_Hooks_GuildNews_Update
	GuildNewsContainer.update = GuildNews_Update
end

local function FR_GuildUI_Moveable()
	GuildFrame:SetMovable(true)
	GuildFrame:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then GuildFrame:StartMoving() end end)
	GuildFrame:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then GuildFrame:StopMovingOrSizing() end end)
	GuildFrame.TitleMouseover:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then GuildFrame:StartMoving() end end)
	GuildFrame.TitleMouseover:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then GuildFrame:StopMovingOrSizing() end end)
end

local function FR_LootFrame_Resize()
	LOOTFRAME_ADDBUTTONS = 4
	LOOTFRAME_NUMBUTTONS_ORG = LOOTFRAME_NUMBUTTONS
	LOOTFRAME_NUMBUTTONS = LOOTFRAME_NUMBUTTONS_ORG + LOOTFRAME_ADDBUTTONS

	-- fix title string position
	for _, region in pairs({LootFrame:GetRegions()}) do
		if region:IsObjectType("FontString") and region:GetText() == _G.ITEMS then
			region:ClearAllPoints()
			region:SetPoint("TOP", 12, -4)
			break
		end
	end

	for index = 2, LOOTFRAME_NUMBUTTONS_ORG do
		_G["LootButton"..(index)]:SetPoint("TOP", _G["LootButton"..(index-1)], "BOTTOM", 0, -4)
	end
	for index = LOOTFRAME_NUMBUTTONS_ORG + 1, LOOTFRAME_NUMBUTTONS do
		local frame = CreateFrame("Button", "LootButton"..index, LootFrame, "LootButtonTemplate")
		frame:SetPoint("TOP", _G["LootButton"..(index-1)], "BOTTOM", 0, -4)
		frame:SetID(index)
	end

	original_LootFrame_OnShow = LootFrame:GetScript("OnShow")
	LootFrame:SetScript("OnShow", FR_Hooks_LootFrame_OnShow)
end

local function FR_RaidInfo_Resize()
	RaidInfoFrame:SetHeight(250 + 158)
	RaidInfoScrollFrame:SetHeight(157 + 158)
	HybridScrollFrame_CreateButtons(RaidInfoScrollFrame, "RaidInfoInstanceTemplate")
end

local function FR_TradeSkillUI_Resize()
	TRADE_SKILL_ADDLINES = floor(additionalFrameHeight / TRADE_SKILL_HEIGHT)
	TRADE_SKILLS_DISPLAYED_ORG = TRADE_SKILLS_DISPLAYED
	TRADE_SKILLS_DISPLAYED = TRADE_SKILLS_DISPLAYED_ORG + TRADE_SKILL_ADDLINES

	TradeSkillFrame:SetHeight(424 + additionalFrameHeight)
	TradeSkillHorizontalBarLeft:SetPoint("TOPLEFT", 2, -(208 + additionalFrameHeight))
	TradeSkillListScrollFrame:SetHeight(130 + additionalFrameHeight)

	local ScrollBarMid = TradeSkillListScrollFrame:CreateTexture(nil, "BACKGROUND")
	ScrollBarMid:SetPoint("TOPLEFT", TradeSkillListScrollFrame, "TOPRIGHT", -3, (2 - 120))
	ScrollBarMid:SetPoint("BOTTOMRIGHT", TradeSkillListScrollFrame, "BOTTOMRIGHT", -3 + 30 + 1, -2 + 123)
	ScrollBarMid:SetTexture([[Interface\ClassTrainerFrame\UI-ClassTrainer-ScrollBar]])
	ScrollBarMid:SetTexCoord(0, 0.484375, 0.25, 0.75)

	for index = TRADE_SKILLS_DISPLAYED_ORG + 1, TRADE_SKILLS_DISPLAYED do
		local frame = CreateFrame("Button", "TradeSkillSkill"..index, TradeSkillFrame, "TradeSkillSkillButtonTemplate")
		frame:SetPoint("TOPLEFT", _G["TradeSkillSkill"..(index-1)], "BOTTOMLEFT")
	end
end

local function FR_TradeSkillUI_Moveable()
	TradeSkillFrame:SetMovable(true)
	TradeSkillFrame:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then TradeSkillFrame:StartMoving() end end)
	TradeSkillFrame:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then TradeSkillFrame:StopMovingOrSizing() end end)
end

local function FR_TrainerUI_Resize()
	CLASS_TRAINER_SCROLL_HEIGHT_ORG = CLASS_TRAINER_SCROLL_HEIGHT
	CLASS_TRAINER_SCROLL_HEIGHT = CLASS_TRAINER_SCROLL_HEIGHT_ORG + additionalFrameHeight
	CLASS_TRAINER_SKILLS_DISPLAYED_ORG = CLASS_TRAINER_SKILLS_DISPLAYED
	CLASS_TRAINER_SKILLS_DISPLAYED = floor(CLASS_TRAINER_SCROLL_HEIGHT / CLASS_TRAINER_SKILL_HEIGHT)

	ClassTrainerFrame:SetHeight(424 + additionalFrameHeight)
	ClassTrainerFrame.scrollFrame:SetHeight(CLASS_TRAINER_SCROLL_HEIGHT)
	HybridScrollFrame_CreateButtons(ClassTrainerFrame.scrollFrame, "ClassTrainerSkillButtonTemplate", 1, -1, "TOPLEFT", "TOPLEFT", 0, 0, "TOP", "BOTTOM")

	-- hack to prevent taint
	setfenv(ClassTrainerFrame_OnShow, setmetatable({ UpdateMicroButtons = function() end }, { __index = _G }))
end

local function FR_TrainerUI_Moveable()
	ClassTrainerFrame:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then ClassTrainerFrame:StartMoving() end end)
	ClassTrainerFrame:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then ClassTrainerFrame:StopMovingOrSizing() end end)
end

-- -----
-- Event Handling
-- -----

local FR_frame = CreateFrame("Frame", "FramesResizedFrame")

FR_frame:RegisterEvent("PLAYER_LOGIN")

FR_frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if		arg1 == "Blizzard_GuildUI" then
			if FramesResized_SV.GuildUI_Resize		then FR_GuildUI_Resize() end
			if FramesResized_SV.GuildUI_Moveable	then FR_GuildUI_Moveable() end
		elseif	arg1 == "Blizzard_TradeSkillUI" then
--			if FramesResized_SV.TradeSkillUI_Resize		then FR_TradeSkillUI_Resize() end
			if FramesResized_SV.TradeSkillUI_Moveable	then FR_TradeSkillUI_Moveable() end
		elseif	arg1 == "Blizzard_TrainerUI" then
			if FramesResized_SV.TrainerUI_Resize		then FR_TrainerUI_Resize() end
			if FramesResized_SV.TrainerUI_Moveable		then FR_TrainerUI_Moveable() end
		end
	elseif event == "PLAYER_LOGIN" then
		if FramesResized_SV.LootFrame_Resize			then FR_LootFrame_Resize() end
		if FramesResized_SV.RaidInfo_Resize				then FR_RaidInfo_Resize() end
		if IsAddOnLoaded("Blizzard_GuildUI") then
			if FramesResized_SV.GuildUI_Resize		then FR_GuildUI_Resize() end
			if FramesResized_SV.GuildUI_Moveable	then FR_GuildUI_Moveable() end
		end
		if IsAddOnLoaded("Blizzard_TradeSkillUI") then
			if FramesResized_SV.TradeSkillUI_Resize		then FR_TradeSkillUI_Resize() end
			if FramesResized_SV.TradeSkillUI_Moveable	then FR_TradeSkillUI_Moveable() end
		end
		if IsAddOnLoaded("Blizzard_TrainerUI") then
			if FramesResized_SV.TrainerUI_Resize		then FR_TrainerUI_Resize() end
			if FramesResized_SV.TrainerUI_Moveable		then FR_TrainerUI_Moveable() end
		end
		FR_frame:RegisterEvent("ADDON_LOADED")
	end
end)
