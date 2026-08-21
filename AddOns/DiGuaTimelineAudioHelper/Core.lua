-- Core.lua
-- 副本语音助手核心控制台

local addonName, addonTable = ...
local frame = CreateFrame("Frame")

-- 1. 变量定义
local MEDIA_PATH

-- 核心：路径更新逻辑
local function RefreshMediaPath()
    if DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.enabled == false then
        MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Mute\\"
    else
        if C_AddOns.IsAddOnLoaded("DiGua-Ranran") then
            MEDIA_PATH = "Interface\\AddOns\\DiGua-Ranran\\Media\\"
        elseif C_AddOns.IsAddOnLoaded("DiGua-WYJJ") then
            MEDIA_PATH = "Interface\\AddOns\\DiGua-WYJJ\\Media\\"
        else
            MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
        end
    end
end

-- 2. 统一事件监听框架
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- 初始化数据库 Defaults
            DiGuaTimelineAudioHelper = DiGuaTimelineAudioHelper or {}
            local db = DiGuaTimelineAudioHelper
            if db.enabled == nil then db.enabled = true end
            if db.ringEnabled == nil then db.ringEnabled = true end
            if db.tenSecCountDown == nil then db.tenSecCountDown = false end
            if db.coTankAuraEnabled == nil then db.coTankAuraEnabled = false end
            if db.bossVoiceEnabled == nil then db.bossVoiceEnabled = true end
            if db.forceEncounterWarnings == nil then db.forceEncounterWarnings = true end
            if db.audioChannel == nil then db.audioChannel = "Master" end
            if db.coTankX == nil then db.coTankX = -400 end
            if db.coTankY == nil then db.coTankY = 350 end

            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        RefreshMediaPath()

        -- 初始化首领语音状态：关闭则清空，开启则确保清理后重新注册
        addonTable.ClearTimelineSounds(addonTable.EventSoundData)
        if DiGuaTimelineAudioHelper.bossVoiceEnabled then
            addonTable.registerTable(addonTable.EventSoundData)
        end

        if not C_AddOns.IsAddOnLoaded("BigWigs") then
            C_Timer.After(2, function() SetCVar("encounterWarningsEnabled", 1) end)
        end

        SetCVar("Sound_NumChannels", 128)

        -- 打印欢迎信息
        C_Timer.After(2, function()
            --print("感謝使用|cFF00FF00[神秘地瓜副本語音插件]|r如果覺得好用，請在|cFFFFA6D5「愛發電」|r平台搜索|cFFFFFF00「神秘地瓜」|r支持我的插件，您的支持就是我最大的動力。/digua 可開啟控制台")
        end)

        -- 同步 UI 控件勾选状态
        if DiGuaTimelineMainFrame then
            DiGuaTimelineEnableCheck:SetChecked(DiGuaTimelineAudioHelper.enabled)
            DiGuaTimelineRingCheck:SetChecked(DiGuaTimelineAudioHelper.ringEnabled)
            DiGuaTimelineChannelCheck:SetChecked(DiGuaTimelineAudioHelper.audioChannel == "Ambience")
            DiGuaTimelineTenSecCheck:SetChecked(DiGuaTimelineAudioHelper.tenSecCountDown)
            DiGuaTimelineCoTankCheck:SetChecked(DiGuaTimelineAudioHelper.coTankAuraEnabled)
            DiGuaTimelineBossVoiceCheck:SetChecked(DiGuaTimelineAudioHelper.bossVoiceEnabled)
            DiGuaTimelineForceWarningsCheck:SetChecked(DiGuaTimelineAudioHelper.forceEncounterWarnings) -- 同步勾选状态
        end

        elseif event == "PLAYER_ENTERING_WORLD" then
            if DiGuaTimelineAudioHelper.forceEncounterWarnings then                
                C_Timer.After(3, function() 
                    -- print("encounterWarningsEnabled")
                    SetCVar("encounterWarningsEnabled", 1) 
                end)
            end
    end
end)


-- 4. 控制台 UI 界面构建
local f = CreateFrame("Frame", "DiGuaTimelineMainFrame", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(220, 220) -- 高度调大到 220px，避免新增选项重叠挤压
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -3)
f.title:SetText("DiGua 控制台")

-- 复选框快速生成构建器
local function CreateCheckButton(name, labelText, yOffsetY, onClickFunc)
    local cb = CreateFrame("CheckButton", name, f, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, yOffsetY)
    local cbText = _G[name .. "Text"]
    cbText:SetText(labelText)
    cbText:SetTextColor(1, 0.82, 0)
    cb:SetScript("OnClick", onClickFunc)
    return cb
end

local cb = CreateCheckButton("DiGuaTimelineEnableCheck", "啟用語音", -35, function(self)
    DiGuaTimelineAudioHelper.enabled = self:GetChecked()
    RefreshMediaPath()
    print("|cffffd100[DiGua]|r 整體音效狀態: " .. (DiGuaTimelineAudioHelper.enabled and "|cff00ff00已開啟|r" or "|cffff0000已禁用|r"))
end)

local cbRing = CreateCheckButton("DiGuaTimelineRingCheck", "顯示倒計時光圈", -60, function(self)
    DiGuaTimelineAudioHelper.ringEnabled = self:GetChecked()
    print("|cffffd100[DiGua]|r 倒計時光圈圖標狀態: " .. (DiGuaTimelineAudioHelper.ringEnabled and "|cff00ff00已顯示|r" or "|cffff0000已隱藏|r"))
end)

local cbChannel = CreateCheckButton("DiGuaTimelineChannelCheck", "使用環境音頻道", -85, function(self)
    local isAmbience = self:GetChecked()
    DiGuaTimelineAudioHelper.audioChannel = isAmbience and "Ambience" or "Master"
    print("|cffffd100[DiGua]|r 播放聲道已切換至: " .. (isAmbience and "|cff00ff00環境音 (Ambience)|r" or "|cffffd100主音量 (Master)|r"))
end)

local cbTenSec = CreateCheckButton("DiGuaTimelineTenSecCheck", "開啟 10 秒倒數", -110, function(self)
    DiGuaTimelineAudioHelper.tenSecCountDown = self:GetChecked()
    print("|cffffd100[DiGua]|r 團隊倒計時模式: " .. (DiGuaTimelineAudioHelper.tenSecCountDown and "|cff00ff00已開啟 (10秒)|r" or "|cffff0000未開啟 (默認5秒)|r"))
end)

local cbCoTank = CreateCheckButton("DiGuaTimelineCoTankCheck", "副坦私有光環監控", -135, function(self)
    DiGuaTimelineAudioHelper.coTankAuraEnabled = self:GetChecked()
    print("|cffffd100[DiGua]|r 副坦私有光環監控: " .. (DiGuaTimelineAudioHelper.coTankAuraEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
    
    if addonTable.RefreshAnchorState then addonTable.RefreshAnchorState(f:IsShown()) end
    if addonTable.UpdateRaidTankAuras then addonTable.UpdateRaidTankAuras() end
end)

local cbBossVoice = CreateCheckButton("DiGuaTimelineBossVoiceCheck", "開啟首領語音警報", -160, function(self)
    local isEnabled = self:GetChecked()
    DiGuaTimelineAudioHelper.bossVoiceEnabled = isEnabled
    
    addonTable.ClearTimelineSounds(addonTable.EventSoundData)
    if isEnabled then
        addonTable.registerTable(addonTable.EventSoundData)
    end
    
    print("|cffffd100[DiGua]|r 首領語音警報功能: " .. (isEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbForceWarnings = CreateCheckButton("DiGuaTimelineForceWarningsCheck", "自動開啟暴雪文字預警", -185, function(self)
    local isEnabled = self:GetChecked()
    DiGuaTimelineAudioHelper.forceEncounterWarnings = isEnabled
    if isEnabled then
        SetCVar("encounterWarningsEnabled", 1)
    end
    print("|cffffd100[DiGua]|r 自動開啟暴雪文字預警: " .. (isEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

f:SetScript("OnShow", function() if addonTable.RefreshAnchorState then addonTable.RefreshAnchorState(true) end end)
f:SetScript("OnHide", function() if addonTable.RefreshAnchorState then addonTable.RefreshAnchorState(false) end end)

SLASH_DIGUA1 = "/digua"
SLASH_DIGUA2 = "/dg" -- 新增别名 /dg
SlashCmdList["DIGUA"] = function()
    if f:IsShown() then f:Hide() else f:Show() end
end
-- 5. 跨文件接口提供
addonTable.GetMediaPath = function() return MEDIA_PATH end
addonTable.GetAudioChannel = function() return DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master" end