local addonName, ns = ...
local L = ns.L
local DB_DEFAULTS = ns.DB_DEFAULTS
local MUSIC_FILES = ns.MUSIC_FILES
local CHANNELS = ns.CHANNELS

----------------------------------------------------------------------
-- Shared references (populated on show)
----------------------------------------------------------------------
local db
local function GetDB()
    if not db then
        ns.InitDB()
        db = ns.GetDB()
    end
    return db
end

----------------------------------------------------------------------
-- Store category reference
----------------------------------------------------------------------
local settingsCategory

local function OpenSettings()
    if Settings and Settings.OpenToCategory and settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end
_G.MiliUI_OpenBloodlustMusicSettings = OpenSettings

----------------------------------------------------------------------
-- Utility: CreateSD (pixel border)
----------------------------------------------------------------------
local function CreateSD(parent)
    parent:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    parent:SetBackdropColor(0, 0, 0, 0.5)
    parent:SetBackdropBorderColor(0, 0, 0, 1)
end

----------------------------------------------------------------------
-- Preview helpers
----------------------------------------------------------------------
local previewHandle = nil

local function StopPreview()
    if previewHandle then
        StopSound(previewHandle)
        previewHandle = nil
    end
end

local function PreviewTrack(index)
    StopPreview()
    local track = MUSIC_FILES[index]
    if track then
        local channel = (db and db.channel) or "SFX"
        local _, handle = PlaySoundFile(track.path, channel)
        previewHandle = handle
    end
end

----------------------------------------------------------------------
-- Custom Dropdown UI Factory
----------------------------------------------------------------------
local function CreateCustomDropdown(parent, name, labelText, itemsFunc, selectedGet, selectedSet)
    local frame = CreateFrame("Button", name, parent, "UIMenuButtonStretchTemplate")
    frame:SetSize(220, 24)
    
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", frame, "LEFT", 8, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    frame.text = text

    local arrow = frame:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", frame, "RIGHT", -2, -1)
    
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
    label:SetText(labelText)
    
    local listFrame = CreateFrame("Frame", name.."_List", UIParent, "BackdropTemplate")
    listFrame:SetFrameStrata("TOOLTIP")
    listFrame:SetSize(280, 200)
    listFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    listFrame:Hide()
    
    local scrollFrame = CreateFrame("ScrollFrame", name.."_Scroll", listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(240, 10)
    scrollFrame:SetScrollChild(content)
    
    listFrame.buttons = {}
    
    listFrame.Refresh = function()
        local items = itemsFunc()
        for _, b in ipairs(listFrame.buttons) do b:Hide() end
        local y = 0
        local height = 20
        local currentVal = selectedGet()
        local displayFound = false
        
        for i, item in ipairs(items) do
            local b = listFrame.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, content)
                b:SetSize(236, height)
                local hl = b:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(1, 1, 1, 0.2)
                
                b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                b.text:SetPoint("LEFT", 4, 0)
                b.text:SetPoint("RIGHT", -24, 0)
                b.text:SetJustifyH("LEFT")
                b.text:SetWordWrap(false)
                
                b.playBtn = CreateFrame("Button", nil, b)
                b.playBtn:SetSize(16, 16)
                b.playBtn:SetPoint("RIGHT", -2, 0)
                local tex = b.playBtn:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints()
                tex:SetTexture("Interface\\Common\\VoiceChat-Speaker")
                tex:SetVertexColor(1, 1, 0)
                
                b.playBtn:SetScript("OnClick", function(self)
                    if self.previewFunc then self.previewFunc() end
                end)
                table.insert(listFrame.buttons, b)
            end
            
            b:SetPoint("TOPLEFT", 0, -y)
            b.text:SetText(item.name)
            if tostring(item.val) == tostring(currentVal) then
                b.text:SetTextColor(1, 1, 0)
                frame.text:SetText(item.name)
                displayFound = true
            else
                b.text:SetTextColor(1, 1, 1)
            end
            
            b:SetScript("OnClick", function()
                selectedSet(item.val)
                frame.text:SetText(item.name)
                listFrame:Hide()
            end)
            
            if item.previewFunc then
                b.playBtn:Show()
                b.playBtn.previewFunc = item.previewFunc
            else
                b.playBtn:Hide()
            end
            
            b:Show()
            y = y + height
        end
        if not displayFound then
            frame.text:SetText(L["SELECT_SOUND"] or "Select...")
        end
        content:SetHeight(math.max(y, 10))
    end
    
    frame:SetScript("OnClick", function()
        if listFrame:IsShown() then
            listFrame:Hide()
        else
            listFrame:ClearAllPoints()
            listFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
            listFrame.Refresh()
            listFrame:Show()
        end
    end)
    
    listFrame:SetScript("OnUpdate", function(self)
        if self:IsMouseOver() or frame:IsMouseOver() then
            self.hoverTimer = 0
        else
            self.hoverTimer = (self.hoverTimer or 0) + GetTickTime()
            if self.hoverTimer > 1.0 then self:Hide() end
        end
    end)
    
    frame.UpdateDisplay = function() 
        local items = itemsFunc()
        local currentVal = selectedGet()
        local found = false
        ns.DebugPrint("UpdateDisplay for", name, "currentVal:", currentVal)
        for _, item in ipairs(items) do
            if tostring(item.val) == tostring(currentVal) then
                frame.text:SetText(item.name)
                found = true
                break
            end
        end
        if not found then 
            frame.text:SetText(L["SELECT_SOUND"] or "Select...") 
            ns.DebugPrint("UpdateDisplay MATCH FAILED for currentVal:", currentVal)
        end
        listFrame.Refresh() 
    end
    
    -- Initialize immediately
    frame.UpdateDisplay()
    return frame
end

----------------------------------------------------------------------
-- Main Panel (Overview)
----------------------------------------------------------------------
local mainPanel = CreateFrame("Frame", "MiliUI_BloodlustMusicMainPanel", UIParent, "BackdropTemplate")
mainPanel.name = L["SETTINGS_MAIN"]
mainPanel.OnCommit = function() end
mainPanel.OnDefault = function() end
mainPanel.OnRefresh = function() end

local mainTitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
mainTitle:SetPoint("TOPLEFT", 16, -16)
mainTitle:SetText(L["ADDON_NAME"])

local mainDesc = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
mainDesc:SetPoint("TOPLEFT", mainTitle, "BOTTOMLEFT", 0, -8)
mainDesc:SetText(L["SETTINGS_MAIN_DESC"])
mainDesc:SetWidth(500)
mainDesc:SetJustifyH("LEFT")

local mainInfo = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
mainInfo:SetPoint("TOPLEFT", mainDesc, "BOTTOMLEFT", 0, -20)
mainInfo:SetJustifyH("LEFT")
mainInfo:SetText("|cffffd100" .. L["SELECT_SUBCATEGORY"] .. "|r")

local item1 = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
item1:SetPoint("TOPLEFT", mainInfo, "BOTTOMLEFT", 0, -12)
item1:SetText("• |cff00ff00" .. L["SETTINGS_MUSIC"] .. "|r")

local item1Desc = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
item1Desc:SetPoint("LEFT", item1, "RIGHT", 8, 0)
item1Desc:SetText("- " .. L["MUSIC_DESC"])

local item2 = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
item2:SetPoint("TOPLEFT", item1, "BOTTOMLEFT", 0, -8)
item2:SetText("• |cff00ff00" .. L["SETTINGS_BAR"] .. "|r")

local item2Desc = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
item2Desc:SetPoint("LEFT", item1Desc, "LEFT", 0, 0)
item2Desc:SetPoint("TOP", item2, "TOP", 0, 0)
item2Desc:SetText("- " .. L["BAR_DESC"])

local item3 = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
item3:SetPoint("TOPLEFT", item2, "BOTTOMLEFT", 0, -8)
item3:SetText("• |cff00ff00" .. L["SETTINGS_REMINDER"] .. "|r")

local item3Desc = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
item3Desc:SetPoint("LEFT", item1Desc, "LEFT", 0, 0)
item3Desc:SetPoint("TOP", item3, "TOP", 0, 0)
item3Desc:SetText("- " .. L["REMINDER_DESC"])

local creditText = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
creditText:SetPoint("TOPLEFT", item3, "BOTTOMLEFT", 0, -24)
creditText:SetJustifyH("LEFT")
creditText:SetWidth(600)
creditText:SetText("|cff888888" .. (L["CREDIT_DFTL"] or "Bloodlust Music and Reminder inspired by EnhBloodlust and Don't Forget to Lust") .. "|r")

-- Register main category
settingsCategory = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
Settings.RegisterAddOnCategory(settingsCategory)

----------------------------------------------------------------------
-- Music Settings Subcategory
----------------------------------------------------------------------
local musicPanel = CreateFrame("Frame", "MiliUI_BloodlustMusicSettingsPanel", UIParent, "BackdropTemplate")
musicPanel.name = L["SETTINGS_MUSIC"]
musicPanel.OnCommit = function() end
musicPanel.OnDefault = function() end
musicPanel.OnRefresh = function() end

local musicTitle = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
musicTitle:SetPoint("TOPLEFT", 16, -16)
musicTitle:SetText(L["MUSIC_SETTINGS_TITLE"])

local musicDesc = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
musicDesc:SetPoint("TOPLEFT", musicTitle, "BOTTOMLEFT", 0, -8)
musicDesc:SetText(L["MUSIC_SETTINGS_DESC"])

-- Enable Music Checkbox
local enableMusicCheck = CreateFrame("CheckButton", nil, musicPanel, "UICheckButtonTemplate")
enableMusicCheck:SetPoint("TOPLEFT", musicDesc, "BOTTOMLEFT", -4, -15)
enableMusicCheck:SetChecked(DB_DEFAULTS.musicEnabled)
enableMusicCheck.Text = enableMusicCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableMusicCheck.Text:SetPoint("LEFT", enableMusicCheck, "RIGHT", 5, 0)
enableMusicCheck.Text:SetText(L["ENABLE_MUSIC"])

local enableMusicDesc = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
enableMusicDesc:SetPoint("LEFT", enableMusicCheck.Text, "RIGHT", 10, 0)
enableMusicDesc:SetText("- " .. L["ENABLE_MUSIC_DESC"])

enableMusicCheck:SetScript("OnShow", function(self)
    local d = GetDB(); if d then self:SetChecked(d.musicEnabled) end
end)
enableMusicCheck:SetScript("OnClick", function(self)
    local d = GetDB(); if d then d.musicEnabled = self:GetChecked() and true or false end
end)

-- Play Mode Toggle Button
local playModeBtn = CreateFrame("Button", nil, musicPanel, "UIPanelButtonTemplate")
playModeBtn:SetSize(140, 28)
playModeBtn:SetPoint("TOPLEFT", enableMusicCheck, "BOTTOMLEFT", 4, -15)
playModeBtn:SetText(L["PLAY_MODE_RANDOM"])

local function UpdatePlayModeButton()
    local d = GetDB()
    local mode = (d and d.playMode) or "random"
    if mode == "random" then
        playModeBtn:SetText(L["PLAY_MODE_RANDOM"])
    else
        playModeBtn:SetText(L["PLAY_MODE_SEQUENTIAL"])
    end
end

playModeBtn:SetScript("OnShow", function() UpdatePlayModeButton() end)
playModeBtn:SetScript("OnClick", function()
    local d = GetDB(); if not d then return end
    d.playMode = (d.playMode == "random") and "sequential" or "random"
    UpdatePlayModeButton()
end)

local playModeDesc = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
playModeDesc:SetPoint("LEFT", playModeBtn, "RIGHT", 10, 0)
playModeDesc:SetText("- " .. L["PLAY_MODE_DESC"])

-- Channel Toggle Button
local channelBtn = CreateFrame("Button", nil, musicPanel, "UIPanelButtonTemplate")
channelBtn:SetSize(140, 28)
channelBtn:SetPoint("TOPLEFT", playModeBtn, "BOTTOMLEFT", 0, -10)
channelBtn:SetText(L["CHANNEL"] .. ": SFX")

local channelDesc = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
channelDesc:SetPoint("LEFT", channelBtn, "RIGHT", 10, 0)
channelDesc:SetText("- " .. L["CHANNEL_DESC"])

local channelExplain = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
channelExplain:SetPoint("TOPLEFT", channelBtn, "BOTTOMLEFT", 2, -4)
channelExplain:SetWidth(400)
channelExplain:SetJustifyH("LEFT")
channelExplain:SetText("|cff888888" .. L["CHANNEL_MASTER_DESC"] .. "|r")

local function UpdateChannelButton()
    local d = GetDB()
    local ch = (d and d.channel) or "SFX"
    channelBtn:SetText(L["CHANNEL"] .. ": " .. ch)
    if ch == "Master" then
        channelExplain:SetText("|cff888888" .. L["CHANNEL_MASTER_DESC"] .. "|r")
    elseif ch == "Dialog" then
        channelExplain:SetText("|cff888888" .. (L["CHANNEL_DIALOG_DESC"] or "") .. "|r")
    else
        channelExplain:SetText("|cff888888" .. L["CHANNEL_SFX_DESC"] .. "|r")
    end
end

channelBtn:SetScript("OnShow", function() UpdateChannelButton() end)
channelBtn:SetScript("OnClick", function()
    local d = GetDB(); if not d then return end
    local current = d.channel or "SFX"
    for i, ch in ipairs(CHANNELS) do
        if ch == current then
            d.channel = CHANNELS[(i % #CHANNELS) + 1]
            break
        end
    end
    UpdateChannelButton()
end)

-- Track List Header
local trackHeader = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
trackHeader:SetPoint("TOPLEFT", channelExplain, "BOTTOMLEFT", -2, -12)
trackHeader:SetText("|cffffd100" .. L["TRACK_ENABLED"] .. "|r")

-- Track List (checkboxes + preview buttons)
local trackChecks = {}
local trackPreviews = {}

local function RefreshTrackList()
    local d = GetDB()
    local lastAnchor = trackHeader

    for i, track in ipairs(MUSIC_FILES) do
        local ck = trackChecks[i]
        if not ck then
            ck = CreateFrame("CheckButton", nil, musicPanel, "UICheckButtonTemplate")
            ck.Text = ck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            ck.Text:SetPoint("LEFT", ck, "RIGHT", 5, 0)
            trackChecks[i] = ck
        end

        ck:ClearAllPoints()
        ck:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -5)
        ck.Text:SetText(track.name)

        if d then
            ck:SetChecked(d.trackEnabled[i] ~= false)
        end

        ck:SetScript("OnClick", function(self)
            local dd = GetDB()
            if dd then dd.trackEnabled[i] = self:GetChecked() and true or false end
        end)
        ck:Show()

        -- Preview button
        local pvBtn = trackPreviews[i]
        if not pvBtn then
            pvBtn = CreateFrame("Button", nil, musicPanel, "UIPanelButtonTemplate")
            pvBtn:SetSize(60, 20)
            trackPreviews[i] = pvBtn
        end

        pvBtn:ClearAllPoints()
        pvBtn:SetPoint("LEFT", ck.Text, "RIGHT", 10, 0)
        pvBtn:SetText(L["PREVIEW"])

        pvBtn:SetScript("OnClick", function(self)
            if previewHandle then
                StopPreview()
                self:SetText(L["PREVIEW"])
            else
                PreviewTrack(i)
                self:SetText(L["STOP_PREVIEW"])
                C_Timer.After(10, function()
                    if not previewHandle then self:SetText(L["PREVIEW"]) end
                end)
            end
        end)
        pvBtn:Show()

        lastAnchor = ck
    end

    -- Hide extra
    for i = #MUSIC_FILES + 1, #trackChecks do
        trackChecks[i]:Hide()
        if trackPreviews[i] then trackPreviews[i]:Hide() end
    end
end

local function ForceShowTrackList()
    for _, ck in ipairs(trackChecks) do if ck then ck:Show() end end
    for _, pvBtn in ipairs(trackPreviews) do if pvBtn then pvBtn:Show() end end
end

musicPanel:SetScript("OnShow", function()
    ns.InitDB(); db = ns.GetDB()
    RefreshTrackList()
    UpdatePlayModeButton()
    UpdateChannelButton()
    if db then enableMusicCheck:SetChecked(db.musicEnabled) end
    ForceShowTrackList()

    C_Timer.After(0.1, function()
        if musicPanel:IsShown() then
            ns.InitDB(); db = ns.GetDB()
            RefreshTrackList()
            UpdatePlayModeButton()
            UpdateChannelButton()
            if db then enableMusicCheck:SetChecked(db.musicEnabled) end
            ForceShowTrackList()
        end
    end)
end)

musicPanel:SetScript("OnHide", function()
    -- StopPreview() removed intentionally to allow music to play while switching setting tabs
end)

-- Register as subcategory
local musicSubcategory = Settings.RegisterCanvasLayoutSubcategory(settingsCategory, musicPanel, musicPanel.name)
Settings.RegisterAddOnCategory(musicSubcategory)

----------------------------------------------------------------------
-- Bar Settings Subcategory
----------------------------------------------------------------------
local barPanel = CreateFrame("Frame", "MiliUI_BloodlustMusicBarPanel", UIParent, "BackdropTemplate")
barPanel.name = L["SETTINGS_BAR"]
barPanel.OnCommit = function() end
barPanel.OnDefault = function() end
barPanel.OnRefresh = function() end

local barTitle = barPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
barTitle:SetPoint("TOPLEFT", 16, -16)
barTitle:SetText(L["BAR_SETTINGS_TITLE"])

local barDesc2 = barPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
barDesc2:SetPoint("TOPLEFT", barTitle, "BOTTOMLEFT", 0, -8)
barDesc2:SetText(L["BAR_SETTINGS_DESC"])

-- Enable Bar Checkbox
local enableBarCheck = CreateFrame("CheckButton", nil, barPanel, "UICheckButtonTemplate")
enableBarCheck:SetPoint("TOPLEFT", barDesc2, "BOTTOMLEFT", -4, -15)
enableBarCheck:SetChecked(DB_DEFAULTS.barEnabled)
enableBarCheck.Text = enableBarCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableBarCheck.Text:SetPoint("LEFT", enableBarCheck, "RIGHT", 5, 0)
enableBarCheck.Text:SetText(L["ENABLE_BAR"])

local enableBarDesc = barPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
enableBarDesc:SetPoint("LEFT", enableBarCheck.Text, "RIGHT", 10, 0)
enableBarDesc:SetText("- " .. L["ENABLE_BAR_DESC"])

enableBarCheck:SetScript("OnShow", function(self)
    local d = GetDB(); if d then self:SetChecked(d.barEnabled) end
end)
enableBarCheck:SetScript("OnClick", function(self)
    local d = GetDB()
    if d then
        d.barEnabled = self:GetChecked() and true or false
        if not d.barEnabled then ns.HideTestBar() end
    end
end)

-- Bar Width Slider
local widthSlider = CreateFrame("Slider", "MiliUI_BLM_WidthSlider", barPanel, "OptionsSliderTemplate")
widthSlider:SetPoint("TOPLEFT", enableBarCheck, "BOTTOMLEFT", 4, -30)
widthSlider:SetWidth(200)
widthSlider:SetMinMaxValues(50, 400)
widthSlider:SetValueStep(5)
widthSlider:SetObeyStepOnDrag(true)
widthSlider.Low:SetText("50")
widthSlider.High:SetText("400")
widthSlider.Text:SetText(L["BAR_WIDTH"] .. ": " .. DB_DEFAULTS.barWidth)
widthSlider:SetValue(DB_DEFAULTS.barWidth)

widthSlider:SetScript("OnShow", function(self)
    local d = GetDB()
    if d then
        self:SetValue(d.barWidth)
        self.Text:SetText(L["BAR_WIDTH"] .. ": " .. d.barWidth)
    end
end)
widthSlider:SetScript("OnValueChanged", function(self, value)
    local val = math.floor(value)
    self.Text:SetText(L["BAR_WIDTH"] .. ": " .. val)
    local d = GetDB()
    if d then
        d.barWidth = val
        ns.UpdateBarSize()
    end
end)

-- Bar Height Slider
local heightSlider = CreateFrame("Slider", "MiliUI_BLM_HeightSlider", barPanel, "OptionsSliderTemplate")
heightSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -30)
heightSlider:SetWidth(200)
heightSlider:SetMinMaxValues(5, 40)
heightSlider:SetValueStep(1)
heightSlider:SetObeyStepOnDrag(true)
heightSlider.Low:SetText("5")
heightSlider.High:SetText("40")
heightSlider.Text:SetText(L["BAR_HEIGHT"] .. ": " .. DB_DEFAULTS.barHeight)
heightSlider:SetValue(DB_DEFAULTS.barHeight)

heightSlider:SetScript("OnShow", function(self)
    local d = GetDB()
    if d then
        self:SetValue(d.barHeight)
        self.Text:SetText(L["BAR_HEIGHT"] .. ": " .. d.barHeight)
    end
end)
heightSlider:SetScript("OnValueChanged", function(self, value)
    local val = math.floor(value)
    self.Text:SetText(L["BAR_HEIGHT"] .. ": " .. val)
    local d = GetDB()
    if d then
        d.barHeight = val
        ns.UpdateBarSize()
    end
end)

-- Test Bar Button
local testBarBtnRef
local testBarBtn = CreateFrame("Button", nil, barPanel, "UIPanelButtonTemplate")
testBarBtn:SetSize(140, 28)
testBarBtn:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -20)
testBarBtn:SetText(L["TEST_BAR"])
testBarBtnRef = testBarBtn
ns.testBarBtnRef = testBarBtnRef
testBarBtn:SetScript("OnClick", function()
    local d = GetDB()
    if not d or not d.barEnabled then return end
    ns.ShowTestBar()
end)

local testBarDesc = barPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
testBarDesc:SetPoint("LEFT", testBarBtn, "RIGHT", 10, 0)
testBarDesc:SetText("- " .. L["TEST_BAR_DESC"])

-- Reset Position Button
local resetPosBtn = CreateFrame("Button", nil, barPanel, "UIPanelButtonTemplate")
resetPosBtn:SetSize(140, 28)
resetPosBtn:SetPoint("TOPLEFT", testBarBtn, "BOTTOMLEFT", 0, -10)
resetPosBtn:SetText(L["RESET_POSITION"])
resetPosBtn:SetScript("OnClick", function()
    local d = GetDB()
    if d then
        d.barX = DB_DEFAULTS.barX
        d.barY = DB_DEFAULTS.barY
        ns.UpdateBarPosition()
        print(L["MSG_POSITION_RESET"])
    end
end)

local resetPosDesc = barPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
resetPosDesc:SetPoint("LEFT", resetPosBtn, "RIGHT", 10, 0)
resetPosDesc:SetText("- " .. L["RESET_POSITION_DESC"])

barPanel:SetScript("OnShow", function()
    ns.InitDB(); db = ns.GetDB()
    if db then
        enableBarCheck:SetChecked(db.barEnabled)
        widthSlider:SetValue(db.barWidth)
        heightSlider:SetValue(db.barHeight)
    end
end)

-- Register as subcategory
local barSubcategory = Settings.RegisterCanvasLayoutSubcategory(settingsCategory, barPanel, barPanel.name)
Settings.RegisterAddOnCategory(barSubcategory)

----------------------------------------------------------------------
-- Reminder Settings Subcategory
----------------------------------------------------------------------
local reminderPanel = CreateFrame("Frame", "MiliUI_BLM_ReminderPanel", UIParent, "BackdropTemplate")
reminderPanel.name = L["SETTINGS_REMINDER"]
reminderPanel.OnCommit = function() end
reminderPanel.OnDefault = function() end
reminderPanel.OnRefresh = function() end

local remTitle = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
remTitle:SetPoint("TOPLEFT", 16, -16)
remTitle:SetText(L["REMINDER_SETTINGS_TITLE"])

local remDesc = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
remDesc:SetPoint("TOPLEFT", remTitle, "BOTTOMLEFT", 0, -8)
remDesc:SetText(L["REMINDER_SETTINGS_DESC"])

-- Enable Reminder
local enableRemCheck = CreateFrame("CheckButton", nil, reminderPanel, "UICheckButtonTemplate")
enableRemCheck:SetPoint("TOPLEFT", remDesc, "BOTTOMLEFT", -4, -15)
enableRemCheck:SetChecked(DB_DEFAULTS.reminderEnabled)
enableRemCheck.Text = enableRemCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableRemCheck.Text:SetPoint("LEFT", enableRemCheck, "RIGHT", 5, 0)
enableRemCheck.Text:SetText(L["ENABLE_REMINDER"])

local enableRemDesc = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
enableRemDesc:SetPoint("LEFT", enableRemCheck.Text, "RIGHT", 10, 0)
enableRemDesc:SetText("- " .. L["ENABLE_REMINDER_DESC"])

enableRemCheck:SetScript("OnShow", function(self)
    local d = GetDB(); if d then self:SetChecked(d.reminderEnabled) end
end)
enableRemCheck:SetScript("OnClick", function(self)
    local d = GetDB(); if d then d.reminderEnabled = self:GetChecked() and true or false end
end)

-- Lust Class Only
local lustClassCheck = CreateFrame("CheckButton", nil, reminderPanel, "UICheckButtonTemplate")
lustClassCheck:SetPoint("TOPLEFT", enableRemCheck, "BOTTOMLEFT", 0, -5)
lustClassCheck:SetChecked(DB_DEFAULTS.reminderLustClassOnly)
lustClassCheck.Text = lustClassCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lustClassCheck.Text:SetPoint("LEFT", lustClassCheck, "RIGHT", 5, 0)
lustClassCheck.Text:SetText(L["REMINDER_LUST_CLASS_ONLY"])

local lustClassDesc = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
lustClassDesc:SetPoint("LEFT", lustClassCheck.Text, "RIGHT", 10, 0)
lustClassDesc:SetText("- " .. L["REMINDER_LUST_CLASS_ONLY_DESC"])

lustClassCheck:SetScript("OnShow", function(self)
    local d = GetDB(); if d then self:SetChecked(d.reminderLustClassOnly) end
end)
lustClassCheck:SetScript("OnClick", function(self)
    local d = GetDB(); if d then d.reminderLustClassOnly = self:GetChecked() and true or false end
end)

-- Dungeon First Pull
local dungeonPullCheck = CreateFrame("CheckButton", nil, reminderPanel, "UICheckButtonTemplate")
dungeonPullCheck:SetPoint("TOPLEFT", lustClassCheck, "BOTTOMLEFT", 0, -5)
dungeonPullCheck:SetChecked(DB_DEFAULTS.reminderDungeonPull)
dungeonPullCheck.Text = dungeonPullCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dungeonPullCheck.Text:SetPoint("LEFT", dungeonPullCheck, "RIGHT", 5, 0)
dungeonPullCheck.Text:SetText(L["REMINDER_DUNGEON_PULL"])

local dungeonPullDesc = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
dungeonPullDesc:SetPoint("LEFT", dungeonPullCheck.Text, "RIGHT", 10, 0)
dungeonPullDesc:SetText("- " .. L["REMINDER_DUNGEON_PULL_DESC"])

dungeonPullCheck:SetScript("OnShow", function(self)
    local d = GetDB(); if d then self:SetChecked(d.reminderDungeonPull) end
end)
dungeonPullCheck:SetScript("OnClick", function(self)
    local d = GetDB(); if d then d.reminderDungeonPull = self:GetChecked() and true or false end
end)

-- Debuff Expiry
local debuffExpiryCheck = CreateFrame("CheckButton", nil, reminderPanel, "UICheckButtonTemplate")
debuffExpiryCheck:SetPoint("TOPLEFT", dungeonPullCheck, "BOTTOMLEFT", 0, -5)
debuffExpiryCheck:SetChecked(DB_DEFAULTS.reminderDebuffExpiry)
debuffExpiryCheck.Text = debuffExpiryCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debuffExpiryCheck.Text:SetPoint("LEFT", debuffExpiryCheck, "RIGHT", 5, 0)
debuffExpiryCheck.Text:SetText(L["REMINDER_DEBUFF_EXPIRY"])

local debuffExpiryDesc = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
debuffExpiryDesc:SetPoint("LEFT", debuffExpiryCheck.Text, "RIGHT", 10, 0)
debuffExpiryDesc:SetText("- " .. L["REMINDER_DEBUFF_EXPIRY_DESC"])

debuffExpiryCheck:SetScript("OnShow", function(self)
    local d = GetDB(); if d then self:SetChecked(d.reminderDebuffExpiry) end
end)
debuffExpiryCheck:SetScript("OnClick", function(self)
    local d = GetDB(); if d then d.reminderDebuffExpiry = self:GetChecked() and true or false end
end)

-- Sound Enabled Checkbox
local soundRemCheck = CreateFrame("CheckButton", nil, reminderPanel, "UICheckButtonTemplate")
soundRemCheck:SetPoint("TOPLEFT", debuffExpiryCheck, "BOTTOMLEFT", 0, -5)
soundRemCheck:SetChecked(DB_DEFAULTS.reminderSoundEnabled)
soundRemCheck.Text = soundRemCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soundRemCheck.Text:SetPoint("LEFT", soundRemCheck, "RIGHT", 5, 0)
soundRemCheck.Text:SetText(L["REMINDER_SOUND_ENABLED"])

local soundRemDesc = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
soundRemDesc:SetPoint("LEFT", soundRemCheck.Text, "RIGHT", 10, 0)
soundRemDesc:SetText("- " .. L["REMINDER_SOUND_ENABLED_DESC"])

soundRemCheck:SetScript("OnShow", function(self)
    local d = GetDB(); if d then self:SetChecked(d.reminderSoundEnabled) end
end)
soundRemCheck:SetScript("OnClick", function(self)
    local d = GetDB(); if d then d.reminderSoundEnabled = self:GetChecked() and true or false end
end)

local function GetAvailableSounds()
    local list = {}
    local p = (L["SOUND_PREFIX"] or "Sound") .. " "
    table.insert(list, { name = p.."1", val = 8457, previewFunc = function() PlaySound(8457, "Master") end })
    table.insert(list, { name = p.."2", val = 8959, previewFunc = function() PlaySound(8959, "Master") end })
    table.insert(list, { name = p.."3", val = 8960, previewFunc = function() PlaySound(8960, "Master") end })
    table.insert(list, { name = p.."4", val = 8332, previewFunc = function() PlaySound(8332, "Master") end })
    table.insert(list, { name = p.."5", val = 8414, previewFunc = function() PlaySound(8414, "Master") end })
    table.insert(list, { name = p.."6", val = 8454, previewFunc = function() PlaySound(8454, "Master") end })
    table.insert(list, { name = p.."7", val = 3081, previewFunc = function() PlaySound(3081, "Master") end })
    table.insert(list, { name = p.."8", val = 48149, previewFunc = function() PlaySound(48149, "Master") end })
    table.insert(list, { name = p.."9", val = 48150, previewFunc = function() PlaySound(48150, "Master") end })
    table.insert(list, { name = p.."10", val = 56747, previewFunc = function() PlaySound(56747, "Master") end })
    table.insert(list, { name = p.."11", val = 5674, previewFunc = function() PlaySound(5674, "Master") end })
    table.insert(list, { name = p.."12", val = 102607, previewFunc = function() PlaySound(102607, "Master") end })
    table.insert(list, { name = p.."13", val = 8458, previewFunc = function() PlaySound(8458, "Master") end })
    table.insert(list, { name = p.."14", val = 8455, previewFunc = function() PlaySound(8455, "Master") end })
    table.insert(list, { name = p.."15", val = 5874, previewFunc = function() PlaySound(5874, "Master") end })
    table.insert(list, { name = p.."16", val = 3175, previewFunc = function() PlaySound(3175, "Master") end })
    table.insert(list, { name = p.."17", val = 8463, previewFunc = function() PlaySound(8463, "Master") end })
    table.insert(list, { name = p.."18", val = 11466, previewFunc = function() PlaySound(11466, "Master") end })
    table.insert(list, { name = p.."19", val = 17316, previewFunc = function() PlaySound(17316, "Master") end })
    table.insert(list, { name = p.."20", val = 3439, previewFunc = function() PlaySound(3439, "Master") end })
    table.insert(list, { name = p.."21", val = 111370, previewFunc = function() PlaySound(111370, "Master") end })
    table.insert(list, { name = p.."22", val = 39517, previewFunc = function() PlaySound(39517, "Master") end })
    table.insert(list, { name = p.."23", val = 895, previewFunc = function() PlaySound(895, "Master") end })

    -- LibSharedMedia Sounds (includes Ayije_CDM sounds if loaded)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("sound")) do
            local path = LSM:Fetch("sound", name)
            if path then
                table.insert(list, { name = "[LSM] "..name, val = name, previewFunc = function() PlaySoundFile(path, "Master") end })
            end
        end
    end
    return list
end

local soundDropdown = CreateCustomDropdown(reminderPanel, "MiliUI_BLM_SoundDropdown", L["SELECT_SOUND"], GetAvailableSounds,
    function() local d = GetDB() return d and d.reminderSound or DB_DEFAULTS.reminderSound end,
    function(val) local d = GetDB() if d then d.reminderSound = val end end
)
soundDropdown:SetPoint("TOPLEFT", soundRemCheck, "BOTTOMLEFT", 6, -18)

-- Duration Slider (localized units)
local unit = L["REMINDER_DURATION_UNIT"] or "s"
local durationSlider = CreateFrame("Slider", "MiliUI_BLM_ReminderDurationSlider", reminderPanel, "OptionsSliderTemplate")
durationSlider:SetPoint("TOPLEFT", soundDropdown, "BOTTOMLEFT", -2, -30)
durationSlider:SetWidth(200)
durationSlider:SetMinMaxValues(1, 15)
durationSlider:SetValueStep(1)
durationSlider:SetObeyStepOnDrag(true)
durationSlider.Low:SetText("1")
durationSlider.High:SetText("15")
durationSlider.Text:SetText(L["REMINDER_DURATION"] .. ": " .. DB_DEFAULTS.reminderDuration .. unit)
durationSlider:SetValue(DB_DEFAULTS.reminderDuration)

durationSlider:SetScript("OnShow", function(self)
    local d = GetDB()
    if d then
        self:SetValue(d.reminderDuration)
        self.Text:SetText(L["REMINDER_DURATION"] .. ": " .. d.reminderDuration .. unit)
    end
end)
durationSlider:SetScript("OnValueChanged", function(self, value)
    local val = math.floor(value)
    self.Text:SetText(L["REMINDER_DURATION"] .. ": " .. val .. unit)
    local d = GetDB()
    if d then d.reminderDuration = val end
end)

-- Test Reminder Button (also plays sound)
local testRemBtn = CreateFrame("Button", nil, reminderPanel, "UIPanelButtonTemplate")
testRemBtn:SetSize(140, 28)
testRemBtn:SetPoint("TOPLEFT", durationSlider, "BOTTOMLEFT", 0, -20)
testRemBtn:SetText(L["REMINDER_TEST"])
testRemBtn:SetScript("OnClick", function()
    if ns.ShowReminder then ns.ShowReminder() end
end)

local testRemDesc = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
testRemDesc:SetPoint("LEFT", testRemBtn, "RIGHT", 10, 0)
testRemDesc:SetText("- " .. (L["REMINDER_TEST_DESC"] or "Preview reminder"))

-- Reset Reminder Position Button
local resetRemPosBtn = CreateFrame("Button", nil, reminderPanel, "UIPanelButtonTemplate")
resetRemPosBtn:SetSize(140, 28)
resetRemPosBtn:SetPoint("TOPLEFT", testRemBtn, "BOTTOMLEFT", 0, -15)
resetRemPosBtn:SetText(L["RESET_REMINDER_POSITION"] or "Reset Position")
resetRemPosBtn:SetScript("OnClick", function()
    local d = GetDB()
    if d then
        d.reminderX = DB_DEFAULTS.reminderX
        d.reminderY = DB_DEFAULTS.reminderY
        if ns.UpdateReminderPosition then ns.UpdateReminderPosition() end
        print(L["MSG_REMINDER_POSITION_RESET"] or "Reminder position reset.")
    end
end)

local resetRemPosDesc = reminderPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
resetRemPosDesc:SetPoint("LEFT", resetRemPosBtn, "RIGHT", 10, 0)
resetRemPosDesc:SetText("- " .. (L["RESET_REMINDER_POSITION_DESC"] or "Reset reminder to bar"))

reminderPanel.OnRefresh = function()
    ns.InitDB(); db = ns.GetDB()
    if db then
        enableRemCheck:SetChecked(db.reminderEnabled)
        lustClassCheck:SetChecked(db.reminderLustClassOnly)
        dungeonPullCheck:SetChecked(db.reminderDungeonPull)
        debuffExpiryCheck:SetChecked(db.reminderDebuffExpiry)
        soundRemCheck:SetChecked(db.reminderSoundEnabled)
        durationSlider:SetValue(db.reminderDuration)
        soundDropdown.UpdateDisplay()
    end
end
reminderPanel:SetScript("OnShow", reminderPanel.OnRefresh)

-- Register as subcategory
local reminderSubcategory = Settings.RegisterCanvasLayoutSubcategory(settingsCategory, reminderPanel, reminderPanel.name)
Settings.RegisterAddOnCategory(reminderSubcategory)

----------------------------------------------------------------------
-- Pre-create track list at load time
----------------------------------------------------------------------
C_Timer.After(0.5, function()
    ns.InitDB(); db = ns.GetDB()
    RefreshTrackList()
end)

-- Also refresh after PLAYER_LOGIN
local settingsLoader = CreateFrame("Frame")
settingsLoader:RegisterEvent("PLAYER_LOGIN")
settingsLoader:SetScript("OnEvent", function(...)
    -- This ensures we refresh values after DB is actually loaded
    C_Timer.After(2, function()
        ns.InitDB(); db = ns.GetDB()
        RefreshTrackList()
        UpdatePlayModeButton()
        UpdateChannelButton()
        if mainPanel.OnRefresh then mainPanel.OnRefresh() end
        if reminderPanel.OnRefresh then reminderPanel.OnRefresh() end
    end)
end)
