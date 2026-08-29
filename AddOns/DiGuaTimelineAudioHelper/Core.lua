-- Core.lua
-- 副本语音助手核心控制台

local addonName, addonTable = ...
local frame = CreateFrame("Frame")

-- 1. 变量定义
local MEDIA_PATH

-- 语音资源路径常量（内置路径固定，供全插件统一引用，避免各处硬编码）
local DEFAULT_MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
local MUTE_MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Mute\\"
local currentVoicePackName -- 当前联动的语音包名（nil 表示使用内置语音）

-- 扫描所有已加载插件，返回按字母序最靠前的 "DiGua-" 前缀语音包名（A 优先于 Z）
local function FindVoicePackName()
    local candidates = {}
    local numAddOns = C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()
    if numAddOns then
        for i = 1, numAddOns do
            local name = C_AddOns.GetAddOnInfo(i)
            if name and name:sub(1, 6) == "DiGua-" and C_AddOns.IsAddOnLoaded(name) then
                candidates[#candidates + 1] = name
            end
        end
    end
    table.sort(candidates, function(a, b) return a:lower() < b:lower() end)
    return candidates[1]
end

local function RefreshMediaPath()
    currentVoicePackName = nil
    if DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.enabled == false then
        MEDIA_PATH = MUTE_MEDIA_PATH
    else
        currentVoicePackName = FindVoicePackName()
        MEDIA_PATH = currentVoicePackName
            and ("Interface\\AddOns\\" .. currentVoicePackName .. "\\Media\\")
            or DEFAULT_MEDIA_PATH
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
            if db.bloodlustOpenSound == nil then db.bloodlustOpenSound = false end
            if db.lfgProposalSound == nil then db.lfgProposalSound = false end
            if db.centerCountdownEnabled == nil then db.centerCountdownEnabled = false end -- 屏幕中央倒计时（默认关）
            if db.interruptIgnoreFocus == nil then db.interruptIgnoreFocus = false end -- 有焦点也提醒打断（默认关）
            if db.audioChannel == nil then db.audioChannel = "Master" end
            if db.coTankX == nil then db.coTankX = -400 end
            if db.coTankY == nil then db.coTankY = 350 end

            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        RefreshMediaPath()
        if currentVoicePackName then
            -- print("|cffffd100[DiGua]|r 語音包聯動: |cff00ff00" .. currentVoicePackName .. "|r")
        end

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
            DiGuaTimelineBloodlustSoundCheck:SetChecked(DiGuaTimelineAudioHelper.bloodlustOpenSound) -- 同步嗜血开启提示音
            DiGuaTimelineLfgProposalCheck:SetChecked(DiGuaTimelineAudioHelper.lfgProposalSound) -- 同步副本就绪提示音
            DiGuaTimelineCenterCountdownCheck:SetChecked(DiGuaTimelineAudioHelper.centerCountdownEnabled) -- 同步屏幕中央倒计时
            DiGuaTimelineInterruptFocusCheck:SetChecked(DiGuaTimelineAudioHelper.interruptIgnoreFocus) -- 同步有焦点也提醒打断
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
f:SetSize(220, 330) -- 高度调大到 330px，容纳更多选项
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

local cbBloodlustSound = CreateCheckButton("DiGuaTimelineBloodlustSoundCheck", "嗜血開啟提示音", -210, function(self)
    DiGuaTimelineAudioHelper.bloodlustOpenSound = self:GetChecked()
    print("|cffffd100[DiGua]|r 嗜血開啟提示語音: " .. (DiGuaTimelineAudioHelper.bloodlustOpenSound and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbLfgProposal = CreateCheckButton("DiGuaTimelineLfgProposalCheck", "副本組隊就緒提示語音", -235, function(self)
    DiGuaTimelineAudioHelper.lfgProposalSound = self:GetChecked()
    print("|cffffd100[DiGua]|r 副本組隊就緒提示語音: " .. (DiGuaTimelineAudioHelper.lfgProposalSound and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbCenterCountdown = CreateCheckButton("DiGuaTimelineCenterCountdownCheck", "技能剩餘5秒中央倒計時", -260, function(self)
    local isEnabled = self:GetChecked()
    DiGuaTimelineAudioHelper.centerCountdownEnabled = isEnabled
    if addonTable.SetCenterCountdownEnabled then addonTable.SetCenterCountdownEnabled(isEnabled) end
    -- 取消勾選時同步隱藏拖動框（僅控制台打開且功能開啟時才顯示）
    if addonTable.RefreshAnchorState then addonTable.RefreshAnchorState(f:IsShown()) end
    print("|cffffd100[DiGua]|r 技能剩餘5秒中央倒計時: " .. (isEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbInterruptFocus = CreateCheckButton("DiGuaTimelineInterruptFocusCheck", "有焦點也提醒打斷", -285, function(self)
    DiGuaTimelineAudioHelper.interruptIgnoreFocus = self:GetChecked()
    print("|cffffd100[DiGua]|r 有焦點也提醒打斷: " .. (DiGuaTimelineAudioHelper.interruptIgnoreFocus and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
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
addonTable.GetDefaultMediaPath = function() return DEFAULT_MEDIA_PATH end
addonTable.GetAudioChannel = function() return DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master" end