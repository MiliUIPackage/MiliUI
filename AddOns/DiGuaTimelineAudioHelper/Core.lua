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
            if db.playerDebuffEnabled == nil then db.playerDebuffEnabled = false end -- 玩家减益图标（默认关）
            if db.bossVoiceEnabled == nil then db.bossVoiceEnabled = true end
            if db.forceEncounterWarnings == nil then db.forceEncounterWarnings = true end
            if db.bloodlustOpenSound == nil then db.bloodlustOpenSound = false end
            if db.lfgProposalSound == nil then db.lfgProposalSound = false end
            if db.centerCountdownEnabled == nil then db.centerCountdownEnabled = false end -- 屏幕中央倒计时（默认关）
            if db.centerCountdownSize == nil then db.centerCountdownSize = 0 end -- 中央倒计时大小档位（0~9，默认 0=最小）
            if db.interruptIgnoreFocus == nil then db.interruptIgnoreFocus = false end -- 有焦点也提醒打断（默认关）
            if db.audioChannel == nil then db.audioChannel = "Master" end
            if db.coTankX == nil then db.coTankX = -400 end
            if db.coTankY == nil then db.coTankY = 350 end
            if db.focusCastBarEnabled == nil then db.focusCastBarEnabled = false end -- 焦点施法条（默认关）
            if db.focusCastBarX == nil then db.focusCastBarX = 0 end
            if db.focusCastBarY == nil then db.focusCastBarY = 140 end
            if db.nameplateTotemTextEnabled == nil then db.nameplateTotemTextEnabled = true end -- 姓名板显示"图腾"文字（默认开）
            if db.normalAuraSoundEnabled == nil then db.normalAuraSoundEnabled = true end -- 光环音效总开关（默认开：光环有声）

            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        RefreshMediaPath()
        if currentVoicePackName then
            -- print("|cffffd100[DiGua]|r 语音包联动: |cff00ff00" .. currentVoicePackName .. "|r")
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
            DiGuaTimelinePlayerDebuffCheck:SetChecked(DiGuaTimelineAudioHelper.playerDebuffEnabled) -- 同步玩家减益图标
            DiGuaTimelineFocusCastBarCheck:SetChecked(DiGuaTimelineAudioHelper.focusCastBarEnabled) -- 同步焦点施法条
            DiGuaTimelineTotemTextCheck:SetChecked(DiGuaTimelineAudioHelper.nameplateTotemTextEnabled) -- 同步姓名板"图腾"文字
            DiGuaTimelineAuraSoundCheck:SetChecked(not DiGuaTimelineAudioHelper.normalAuraSoundEnabled) -- 同步“关闭光环音效”（勾选=关）
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
f:SetSize(470, 400) -- 加宽为左右两栏布局：左听觉 / 右视觉
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

-- 左右两栏标题
local function CreateColumnTitle(text, xOffset, yOffset)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", xOffset, yOffset)
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0)
    return label
end

-- 中间竖向分隔线（改用 Frame + WHITE8x8 背景，避免 SetTexture 颜色渲染异常变绿）
local divider = CreateFrame("Frame", nil, f, "BackdropTemplate")
divider:SetPoint("TOP", f, "TOP", 0, -28)
divider:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
divider:SetWidth(1)
divider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
divider:SetBackdropColor(1, 1, 1, 0.5)

CreateColumnTitle("聲音", 110, -30)
CreateColumnTitle("圖形", 340, -30)

-- 复选框快速生成构建器（xOffset 用于区分左右两栏）
local function CreateCheckButton(name, labelText, xOffset, yOffsetY, onClickFunc)
    local cb = CreateFrame("CheckButton", name, f, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", xOffset, yOffsetY)
    local cbText = _G[name .. "Text"]
    cbText:SetText(labelText)
    cbText:SetTextColor(1, 0.82, 0)
    cb:SetScript("OnClick", onClickFunc)
    return cb
end

-- ===== 左栏：听觉 =====
local cb = CreateCheckButton("DiGuaTimelineEnableCheck", "啟用語音", 20, -55, function(self)
    DiGuaTimelineAudioHelper.enabled = self:GetChecked()
    RefreshMediaPath()
    print("|cffffd100[DiGua]|r 整體音效狀態: " .. (DiGuaTimelineAudioHelper.enabled and "|cff00ff00已開啟|r" or "|cffff0000已禁用|r"))
end)

local cbChannel = CreateCheckButton("DiGuaTimelineChannelCheck", "整體音效使用環境音頻道", 20, -80, function(self)
    local isAmbience = self:GetChecked()
    DiGuaTimelineAudioHelper.audioChannel = isAmbience and "Ambience" or "Master"
    -- 声道切换后，重新登记“登记式”声音（首领语音 SetEventSound / 光环声音 AddAuraSound），
    -- 否则登录后改勾选不会生效，会继续沿用旧声道（表现为未勾选却走环境音）。
    if addonTable.ReloadTimelineSounds then addonTable.ReloadTimelineSounds() end
    if addonTable.ReloadNormalAuras then addonTable.ReloadNormalAuras() end
    print("|cffffd100[DiGua]|r 整體音效聲道已切換至: " .. (isAmbience and "|cff00ff00環境音 (Ambience)|r" or "|cffffd100主音量 (Master)|r"))
end)

local cbTenSec = CreateCheckButton("DiGuaTimelineTenSecCheck", "開怪 10 秒語音倒數", 20, -105, function(self)
    DiGuaTimelineAudioHelper.tenSecCountDown = self:GetChecked()
    print("|cffffd100[DiGua]|r 開怪 10 秒語音倒數: " .. (DiGuaTimelineAudioHelper.tenSecCountDown and "|cff00ff00已開啟 (10秒)|r" or "|cffff0000未開啟 (預設5秒)|r"))
end)

local cbBossVoice = CreateCheckButton("DiGuaTimelineBossVoiceCheck", "開啟首領語音警報", 20, -130, function(self)
    local isEnabled = self:GetChecked()
    DiGuaTimelineAudioHelper.bossVoiceEnabled = isEnabled
    
    addonTable.ClearTimelineSounds(addonTable.EventSoundData)
    if isEnabled then
        addonTable.registerTable(addonTable.EventSoundData)
    end
    
    print("|cffffd100[DiGua]|r 首領語音警報功能: " .. (isEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbBloodlustSound = CreateCheckButton("DiGuaTimelineBloodlustSoundCheck", "嗜血開啟提示語音", 20, -155, function(self)
    DiGuaTimelineAudioHelper.bloodlustOpenSound = self:GetChecked()
    print("|cffffd100[DiGua]|r 嗜血開啟提示語音: " .. (DiGuaTimelineAudioHelper.bloodlustOpenSound and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbLfgProposal = CreateCheckButton("DiGuaTimelineLfgProposalCheck", "副本組隊就緒提示語音", 20, -180, function(self)
    DiGuaTimelineAudioHelper.lfgProposalSound = self:GetChecked()
    print("|cffffd100[DiGua]|r 副本組隊就緒提示語音: " .. (DiGuaTimelineAudioHelper.lfgProposalSound and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbInterruptFocus = CreateCheckButton("DiGuaTimelineInterruptFocusCheck", "有焦點也播報周圍怪物打斷", 20, -205, function(self)
    DiGuaTimelineAudioHelper.interruptIgnoreFocus = self:GetChecked()
    print("|cffffd100[DiGua]|r 有焦點也播報周圍怪物打斷: " .. (DiGuaTimelineAudioHelper.interruptIgnoreFocus and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

-- 关闭光环音效（勾选=关闭：注销 NormalAuraSound.lua 注册的所有光环音；默认不勾选=光环有声）
local cbAuraSound = CreateCheckButton("DiGuaTimelineAuraSoundCheck", "關閉光環音效", 20, -230, function(self)
    local disabled = self:GetChecked()
    DiGuaTimelineAudioHelper.normalAuraSoundEnabled = not disabled
    if disabled then
        if addonTable.UnregisterNormalAuras then addonTable.UnregisterNormalAuras() end
    else
        if addonTable.ReloadNormalAuras then addonTable.ReloadNormalAuras() end
    end
    print("|cffffd100[DiGua]|r 關閉光環音效: " .. (disabled and "|cffff0000已關閉（光環靜音）|r" or "|cff00ff00已開啟（光環有聲）|r"))
end)

-- ===== 右栏：视觉 =====
local cbRing = CreateCheckButton("DiGuaTimelineRingCheck", "顯示倒計時圓環", 250, -55, function(self)
    DiGuaTimelineAudioHelper.ringEnabled = self:GetChecked()
    print("|cffffd100[DiGua]|r 倒計時圓環圖示狀態: " .. (DiGuaTimelineAudioHelper.ringEnabled and "|cff00ff00已顯示|r" or "|cffff0000已隱藏|r"))
end)

local cbCoTank = CreateCheckButton("DiGuaTimelineCoTankCheck", "副坦私有光環監控(暫時無法使用)", 250, -80, function(self)
    DiGuaTimelineAudioHelper.coTankAuraEnabled = self:GetChecked()
    print("|cffffd100[DiGua]|r 副坦私有光環監控(暫時無法使用): " .. (DiGuaTimelineAudioHelper.coTankAuraEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
    
    if addonTable.RefreshAnchorState then addonTable.RefreshAnchorState(f:IsShown()) end
    if addonTable.UpdateRaidTankAuras then addonTable.UpdateRaidTankAuras() end
end)

local cbForceWarnings = CreateCheckButton("DiGuaTimelineForceWarningsCheck", "自動開啟暴雪文字預警", 250, -105, function(self)
    local isEnabled = self:GetChecked()
    DiGuaTimelineAudioHelper.forceEncounterWarnings = isEnabled
    if isEnabled then
        SetCVar("encounterWarningsEnabled", 1)
    end
    print("|cffffd100[DiGua]|r 自動開啟暴雪文字預警: " .. (isEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbCenterCountdown = CreateCheckButton("DiGuaTimelineCenterCountdownCheck", "技能剩餘5秒中央倒計時", 250, -130, function(self)
    local isEnabled = self:GetChecked()
    DiGuaTimelineAudioHelper.centerCountdownEnabled = isEnabled
    if addonTable.SetCenterCountdownEnabled then addonTable.SetCenterCountdownEnabled(isEnabled) end
    -- 取消勾选时同步隐藏拖动框（仅控制台打开且功能开启时才显示）
    if addonTable.RefreshAnchorState then addonTable.RefreshAnchorState(f:IsShown()) end
    print("|cffffd100[DiGua]|r 技能剩餘5秒中央倒計時: " .. (isEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

local cbPlayerDebuff = CreateCheckButton("DiGuaTimelinePlayerDebuffCheck", "顯示玩家減益圖示", 250, -215, function(self)
    DiGuaTimelineAudioHelper.playerDebuffEnabled = self:GetChecked()
    print("|cffffd100[DiGua]|r 玩家減益圖示: " .. (DiGuaTimelineAudioHelper.playerDebuffEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
    if addonTable.SetPlayerDebuffEnabled then addonTable.SetPlayerDebuffEnabled(self:GetChecked()) end
end)

local cbFocusCastBar = CreateCheckButton("DiGuaTimelineFocusCastBarCheck", "焦點特定技能施法條(測試版)", 250, -240, function(self)
    DiGuaTimelineAudioHelper.focusCastBarEnabled = self:GetChecked()
    print("|cffffd100[DiGua]|r 焦點特定技能施法條(測試版): " .. (DiGuaTimelineAudioHelper.focusCastBarEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
    if addonTable.RefreshFocusCastBarState then addonTable.RefreshFocusCastBarState(f:IsShown()) end
end)

local cbTotemText = CreateCheckButton("DiGuaTimelineTotemTextCheck", "姓名板顯示\"圖騰\"文字", 250, -265, function(self)
    DiGuaTimelineAudioHelper.nameplateTotemTextEnabled = self:GetChecked()
    if addonTable.SetNameplateTotemTextEnabled then addonTable.SetNameplateTotemTextEnabled(self:GetChecked()) end
    print("|cffffd100[DiGua]|r 姓名板顯示\"圖騰\"文字: " .. (DiGuaTimelineAudioHelper.nameplateTotemTextEnabled and "|cff00ff00已開啟|r" or "|cffff0000已關閉|r"))
end)

-- 主音量滑块（映射魔兽系统主音量 Sound_MasterVolume，范围 0-1，显示 0%-100%）
-- 归入左栏“听觉”分组底部
local masterVolumeSlider = CreateFrame("Slider", "DiGuaTimelineMasterVolumeSlider", f, "OptionsSliderTemplate")
masterVolumeSlider:SetPoint("TOPLEFT", 20, -270) -- 往下移 25，给上方“关闭光环音效”行腾位置
masterVolumeSlider:SetMinMaxValues(0, 1)
masterVolumeSlider:SetValueStep(0.05)
masterVolumeSlider:SetObeyStepOnDrag(true)
masterVolumeSlider:SetWidth(150)
local masterVolumeText = _G["DiGuaTimelineMasterVolumeSliderText"]
if masterVolumeText then
    masterVolumeText:SetText("主音量")
    masterVolumeText:SetTextColor(1, 0.82, 0)
end
local masterVolumeValue = _G["DiGuaTimelineMasterVolumeSliderValue"]
local masterVolumeLow = _G["DiGuaTimelineMasterVolumeSliderLow"]
local masterVolumeHigh = _G["DiGuaTimelineMasterVolumeSliderHigh"]
if masterVolumeLow then masterVolumeLow:SetText("0%") end
if masterVolumeHigh then masterVolumeHigh:SetText("100%") end
local masterVolumeUpdating = false
local function UpdateMasterVolumeLabel(value)
    if masterVolumeValue then
        masterVolumeValue:SetText(format("%d%%", math.floor((value or 0) * 100 + 0.5)))
    end
end
masterVolumeSlider:SetScript("OnValueChanged", function(self, value)
    if masterVolumeUpdating then return end
    SetCVar("Sound_MasterVolume", value)
    UpdateMasterVolumeLabel(value)
end)
-- 初始同步系统当前主音量
masterVolumeUpdating = true
masterVolumeSlider:SetValue(tonumber(GetCVar("Sound_MasterVolume")) or 1)
masterVolumeUpdating = false
UpdateMasterVolumeLabel(masterVolumeSlider:GetValue())

-- 中央倒计时大小滑块（0~9 档，0 = 代码默认最小；每档图标与文字各放大 2px）
-- 放在右栏“技能剩余5秒中央倒计时”勾选项正下方，便于一起调节
local centerSizeSlider = CreateFrame("Slider", "DiGuaTimelineCenterSizeSlider", f, "OptionsSliderTemplate")
centerSizeSlider:SetPoint("TOPLEFT", 250, -178)
centerSizeSlider:SetMinMaxValues(0, 9)
centerSizeSlider:SetValueStep(1)
centerSizeSlider:SetObeyStepOnDrag(true)
centerSizeSlider:SetWidth(170)
local centerSizeText = _G["DiGuaTimelineCenterSizeSliderText"]
if centerSizeText then
    centerSizeText:SetText("中央倒計時整體大小")
    centerSizeText:SetTextColor(1, 0.82, 0)
end
local centerSizeValue = _G["DiGuaTimelineCenterSizeSliderValue"]
local centerSizeLow = _G["DiGuaTimelineCenterSizeSliderLow"]
local centerSizeHigh = _G["DiGuaTimelineCenterSizeSliderHigh"]
if centerSizeLow then centerSizeLow:SetText("小") end
if centerSizeHigh then centerSizeHigh:SetText("大") end
local centerSizeUpdating = false
local function UpdateCenterSizeLabel(value)
    if centerSizeValue then
        -- 档位 0~9 对应显示为 1~10 档，直观对应“共10个档位”
        centerSizeValue:SetText(format("%d档", math.floor((value or 0) + 0.5) + 1))
    end
end
centerSizeSlider:SetScript("OnValueChanged", function(self, value)
    if centerSizeUpdating then return end
    value = math.floor(value + 0.5)
    DiGuaTimelineAudioHelper.centerCountdownSize = value
    if addonTable.SetCenterCountdownSize then addonTable.SetCenterCountdownSize(value) end
    UpdateCenterSizeLabel(value)
end)
-- 初始同步当前已保存档位（ADDON_LOADED 前 db 可能为 nil，需安全读取）
centerSizeUpdating = true
centerSizeSlider:SetValue(tonumber((DiGuaTimelineAudioHelper or {}).centerCountdownSize) or 0)
centerSizeUpdating = false
UpdateCenterSizeLabel(centerSizeSlider:GetValue())

f:SetScript("OnShow", function()
    if addonTable.RefreshAnchorState then addonTable.RefreshAnchorState(true) end
    if addonTable.RefreshFocusCastBarState then addonTable.RefreshFocusCastBarState(true) end
    if addonTable.RefreshPlayerDebuffAnchor then addonTable.RefreshPlayerDebuffAnchor(true) end
    -- 打开控制台时同步系统主音量（防止在系统设置里改过）
    if masterVolumeSlider then
        masterVolumeUpdating = true
        masterVolumeSlider:SetValue(tonumber(GetCVar("Sound_MasterVolume")) or 1)
        masterVolumeUpdating = false
        UpdateMasterVolumeLabel(masterVolumeSlider:GetValue())
    end
    -- 同步中央倒计时大小档位滑块
    if centerSizeSlider then
        centerSizeUpdating = true
        centerSizeSlider:SetValue(tonumber((DiGuaTimelineAudioHelper or {}).centerCountdownSize) or 0)
        centerSizeUpdating = false
        UpdateCenterSizeLabel(centerSizeSlider:GetValue())
    end
end)
f:SetScript("OnHide", function()
    if addonTable.RefreshAnchorState then addonTable.RefreshAnchorState(false) end
    if addonTable.RefreshFocusCastBarState then addonTable.RefreshFocusCastBarState(false) end
    if addonTable.RefreshPlayerDebuffAnchor then addonTable.RefreshPlayerDebuffAnchor(false) end
end)

SLASH_DIGUA1 = "/digua"
SLASH_DIGUA2 = "/dg" -- 新增别名 /dg
SlashCmdList["DIGUA"] = function()
    if f:IsShown() then f:Hide() else f:Show() end
end
-- 5. 跨文件接口提供
addonTable.GetMediaPath = function() return MEDIA_PATH end
addonTable.GetDefaultMediaPath = function() return DEFAULT_MEDIA_PATH end
addonTable.GetAudioChannel = function() return DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master" end