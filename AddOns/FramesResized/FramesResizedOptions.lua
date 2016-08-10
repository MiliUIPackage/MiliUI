local panel = CreateFrame("FRAME", nil, InterfaceOptionsFramePanelContainer)
panel.name = "FramesResized"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Elkano's FramesResized")

local subtext = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtext:SetHeight(32)
subtext:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtext:SetPoint("RIGHT", -32, 0)
subtext:SetJustifyH("LEFT")
subtext:SetJustifyV("TOP")
subtext:SetText("These settings control which frames should be increased in size or made moveable by FramesResized.\nMost changes will require you to reload the UI.")

-- -----
-- LootFrame
-- -----
local LootFrame_Box = CreateFrame("FRAME", "FramesResizedPanel_LootFrame_Box", panel, "OptionsBoxTemplate")
LootFrame_Box:SetHeight(36)
LootFrame_Box:SetWidth(186)
LootFrame_Box:SetPoint("TOPLEFT", 16, -96)
LootFrame_Box:SetBackdropBorderColor(0.4, 0.4, 0.4);
LootFrame_Box:SetBackdropColor(0.15, 0.15, 0.15);
_G["FramesResizedPanel_LootFrame_BoxTitle"]:SetText("LootFrame");

local LootFrame_Resize = CreateFrame("CHECKBUTTON", "FramesResizedPanel_LootFrame_Resize", panel, "InterfaceOptionsSmallCheckButtonTemplate")
LootFrame_Resize:SetPoint("TOPLEFT", LootFrame_Box, "TOPLEFT", 8, -6)
_G["FramesResizedPanel_LootFrame_ResizeText"]:SetText("Resize")
LootFrame_Resize.setFunc = function(v) FramesResized_SV.LootFrame_Resize = (v == "1") end

-- -----
-- RaidInfo
-- -----
local RaidInfo_Box = CreateFrame("FRAME", "FramesResizedPanel_RaidInfo_Box", panel, "OptionsBoxTemplate")
RaidInfo_Box:SetHeight(36)
RaidInfo_Box:SetWidth(186)
RaidInfo_Box:SetPoint("TOPLEFT", LootFrame_Box, "TOPRIGHT", 8, 0)
RaidInfo_Box:SetBackdropBorderColor(0.4, 0.4, 0.4);
RaidInfo_Box:SetBackdropColor(0.15, 0.15, 0.15);
_G["FramesResizedPanel_RaidInfo_BoxTitle"]:SetText("RaidInfo");

local RaidInfo_Resize = CreateFrame("CHECKBUTTON", "FramesResizedPanel_RaidInfo_Resize", panel, "InterfaceOptionsSmallCheckButtonTemplate")
RaidInfo_Resize:SetPoint("TOPLEFT", RaidInfo_Box, "TOPLEFT", 8, -6)
_G["FramesResizedPanel_RaidInfo_ResizeText"]:SetText("Resize")
RaidInfo_Resize.setFunc = function(v) FramesResized_SV.RaidInfo_Resize = (v == "1") end

-- -----
-- GuildUI
-- -----
local GuildUI_Box = CreateFrame("FRAME", "FramesResizedPanel_GuildUI_Box", panel, "OptionsBoxTemplate")
GuildUI_Box:SetHeight(60)
GuildUI_Box:SetWidth(186)
GuildUI_Box:SetPoint("TOPLEFT", LootFrame_Box, "BOTTOMLEFT", 0, -16)
GuildUI_Box:SetBackdropBorderColor(0.4, 0.4, 0.4);
GuildUI_Box:SetBackdropColor(0.15, 0.15, 0.15);
_G["FramesResizedPanel_GuildUI_BoxTitle"]:SetText("GuildUI");

local GuildUI_Resize = CreateFrame("CHECKBUTTON", "FramesResizedPanel_GuildUI_Resize", panel, "InterfaceOptionsSmallCheckButtonTemplate")
GuildUI_Resize:SetPoint("TOPLEFT", GuildUI_Box, "TOPLEFT", 8, -6)
_G["FramesResizedPanel_GuildUI_ResizeText"]:SetText("Resize")
GuildUI_Resize.setFunc = function(v) FramesResized_SV.GuildUI_Resize = (v == "1") end

local GuildUI_Moveable = CreateFrame("CHECKBUTTON", "FramesResizedPanel_GuildUI_Moveable", panel, "InterfaceOptionsSmallCheckButtonTemplate")
GuildUI_Moveable:SetPoint("TOPLEFT", GuildUI_Resize, "BOTTOMLEFT", 0, 4)
_G["FramesResizedPanel_GuildUI_MoveableText"]:SetText("Moveable")
GuildUI_Moveable.setFunc = function(v) FramesResized_SV.GuildUI_Moveable = (v == "1") end

-- -----
-- TrainerUI
-- -----
local TrainerUI_Box = CreateFrame("FRAME", "FramesResizedPanel_TrainerUI_Box", panel, "OptionsBoxTemplate")
TrainerUI_Box:SetHeight(60)
TrainerUI_Box:SetWidth(186)
TrainerUI_Box:SetPoint("TOPLEFT", GuildUI_Box, "TOPRIGHT", 8, 0)
TrainerUI_Box:SetBackdropBorderColor(0.4, 0.4, 0.4);
TrainerUI_Box:SetBackdropColor(0.15, 0.15, 0.15);
_G["FramesResizedPanel_TrainerUI_BoxTitle"]:SetText("TrainerUI");

local TrainerUI_Resize = CreateFrame("CHECKBUTTON", "FramesResizedPanel_TrainerUI_Resize", panel, "InterfaceOptionsSmallCheckButtonTemplate")
TrainerUI_Resize:SetPoint("TOPLEFT", TrainerUI_Box, "TOPLEFT", 8, -6)
_G["FramesResizedPanel_TrainerUI_ResizeText"]:SetText("Resize")
TrainerUI_Resize.setFunc = function(v) FramesResized_SV.TrainerUI_Resize = (v == "1") end

local TrainerUI_Moveable = CreateFrame("CHECKBUTTON", "FramesResizedPanel_TrainerUI_Moveable", panel, "InterfaceOptionsSmallCheckButtonTemplate")
TrainerUI_Moveable:SetPoint("TOPLEFT", TrainerUI_Resize, "BOTTOMLEFT", 0, 4)
_G["FramesResizedPanel_TrainerUI_MoveableText"]:SetText("Moveable")
TrainerUI_Moveable.setFunc = function(v) FramesResized_SV.TrainerUI_Moveable = (v == "1") end

-- -----
-- TradeSkillUI
-- -----
local TradeSkillUI_Box = CreateFrame("FRAME", "FramesResizedPanel_TradeSkillUI_Box", panel, "OptionsBoxTemplate")
TradeSkillUI_Box:SetHeight(60)
TradeSkillUI_Box:SetWidth(186)
TradeSkillUI_Box:SetPoint("TOPLEFT", GuildUI_Box, "BOTTOMLEFT", 0, -16)
TradeSkillUI_Box:SetBackdropBorderColor(0.4, 0.4, 0.4);
TradeSkillUI_Box:SetBackdropColor(0.15, 0.15, 0.15);
_G["FramesResizedPanel_TradeSkillUI_BoxTitle"]:SetText("TradeSkillUI");

local TradeSkillUI_Resize = CreateFrame("CHECKBUTTON", "FramesResizedPanel_TradeSkillUI_Resize", panel, "InterfaceOptionsSmallCheckButtonTemplate")
TradeSkillUI_Resize:SetPoint("TOPLEFT", TradeSkillUI_Box, "TOPLEFT", 8, -6)
_G["FramesResizedPanel_TradeSkillUI_ResizeText"]:SetText(GRAY_FONT_COLOR_CODE .. "Resize" .. FONT_COLOR_CODE_CLOSE)
TradeSkillUI_Resize.setFunc = function(v) FramesResized_SV.TradeSkillUI_Resize = (v == "1") end
TradeSkillUI_Resize:Disable()

local TradeSkillUI_Moveable = CreateFrame("CHECKBUTTON", "FramesResizedPanel_TradeSkillUI_Moveable", panel, "InterfaceOptionsSmallCheckButtonTemplate")
TradeSkillUI_Moveable:SetPoint("TOPLEFT", TradeSkillUI_Resize, "BOTTOMLEFT", 0, 4)
_G["FramesResizedPanel_TradeSkillUI_MoveableText"]:SetText("Moveable")
TradeSkillUI_Moveable.setFunc = function(v) FramesResized_SV.TradeSkillUI_Moveable = (v == "1") end

-- -----
-- other stuff
-- -----
panel.refresh = function()
	GuildUI_Resize:SetChecked(FramesResized_SV.GuildUI_Resize)
	GuildUI_Moveable:SetChecked(FramesResized_SV.GuildUI_Moveable)
	LootFrame_Resize:SetChecked(FramesResized_SV.LootFrame_Resize)
	RaidInfo_Resize:SetChecked(FramesResized_SV.RaidInfo_Resize)
--	TradeSkillUI_Resize:SetChecked(FramesResized_SV.TradeSkillUI_Resize)
	TradeSkillUI_Moveable:SetChecked(FramesResized_SV.TradeSkillUI_Moveable)
	TrainerUI_Resize:SetChecked(FramesResized_SV.TrainerUI_Resize)
	TrainerUI_Moveable:SetChecked(FramesResized_SV.TrainerUI_Moveable)
end

InterfaceOptions_AddCategory(panel)

SLASH_FRAMESRESIZED1 = "/fr"
SlashCmdList.FRAMESRESIZED = function() InterfaceOptionsFrame_OpenToCategory(panel) end
