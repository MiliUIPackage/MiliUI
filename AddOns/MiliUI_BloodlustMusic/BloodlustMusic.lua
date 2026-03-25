local addonName, ns = ...

-- Localization
local L = LibStub("AceLocale-3.0"):GetLocale("MiliUI_BloodlustMusic")

----------------------------------------------------------------------
-- Spell ID Configuration (easy to maintain at the top)
----------------------------------------------------------------------

-- Lust BUFF spell IDs (the actual haste effect, ~40s duration)
local LUST_BUFFS = {
    2825,    -- Bloodlust       (Shaman)
    32182,   -- Heroism          (Shaman)
    80353,   -- Time Warp        (Mage)
    264667,  -- Primal Rage      (Hunter pet)
    390386,  -- Fury of the Aspects (Evoker)
    466904,  -- Harrier's Cry    (Hunter - Marksmanship)
}

-- Lust DEBUFF spell IDs (exhaustion lockout, ~10min)
local LUST_DEBUFFS = {
    57723,   -- Exhaustion      (Heroism)
    57724,   -- Sated           (Bloodlust)
    80354,   -- Temporal Displacement (Time Warp)
    95809,   -- Insanity        (Ancient Hysteria / Hunter pet)
    390435,  -- Exhaustion      (Fury of the Aspects – Evoker)
    264689,  -- Fatigued        (Primal Rage / Drums)
}

----------------------------------------------------------------------
-- Music Configuration (easy to add new tracks)
----------------------------------------------------------------------
local MUSIC_FILES = {
    { name = "Bloodlust Mid",    path = "Interface\\AddOns\\MiliUI_BloodlustMusic\\Media\\bloodlust_mid.mp3" },
}

local MUSIC_DURATION = 40  -- seconds to play music
local CHANNELS = { "Master", "SFX" }

----------------------------------------------------------------------
-- SavedVariables Defaults
----------------------------------------------------------------------
local DB_DEFAULTS = {
    musicEnabled     = true,
    barEnabled       = true,
    playMode         = "random",   -- "random" or "sequential"
    channel          = "Master",
    trackEnabled     = {},         -- [index] = true/false per track
    lastTrackIndex   = 0,
    barWidth         = 185,
    barHeight        = 10,
    barX             = 0,
    barY             = 300,
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local db
local debugMode = false

local function DebugPrint(...)
    if debugMode then
        print("|cffff8800[BLM Debug]|r", ...)
    end
end
local playing = false

-- Faction-based default name and icon
local DEFAULT_LUST_NAME, DEFAULT_LUST_ICON
do
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        DEFAULT_LUST_NAME = C_Spell.GetSpellName(32182) or "Heroism"    -- 英勇
        DEFAULT_LUST_ICON = "Interface\\Icons\\Ability_Shaman_Heroism"
    else
        DEFAULT_LUST_NAME = C_Spell.GetSpellName(2825) or "Bloodlust"  -- 嗜血
        DEFAULT_LUST_ICON = "Interface\\Icons\\Spell_Nature_Bloodlust"
    end
end
local playingHandle = nil
local previewHandle = nil
local savedMusicVol = nil
local savedAmbienceVol = nil
local restoreTimer = nil
local activeLustSpellID = nil
local activeLustExpiration = nil
local activeLustDuration = nil
local barFrame, barStatusBar, barIcon, barText, barTimeText
local barTestTimer = nil
local isInEditMode = false

----------------------------------------------------------------------
-- Utility: Initialize DB
----------------------------------------------------------------------
local function InitDB()
    if not MiliUI_BloodlustMusic_DB then MiliUI_BloodlustMusic_DB = {} end
    db = MiliUI_BloodlustMusic_DB

    -- Apply defaults
    for k, v in pairs(DB_DEFAULTS) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
                for kk, vv in pairs(v) do db[k][kk] = vv end
            else
                db[k] = v
            end
        end
    end

    -- Default all tracks enabled
    for i = 1, #MUSIC_FILES do
        if db.trackEnabled[i] == nil then
            db.trackEnabled[i] = true
        end
    end
end

----------------------------------------------------------------------
-- Utility: Get enabled track list
----------------------------------------------------------------------
local function GetEnabledTracks()
    local tracks = {}
    for i, t in ipairs(MUSIC_FILES) do
        if db.trackEnabled[i] then
            table.insert(tracks, { index = i, name = t.name, path = t.path })
        end
    end
    return tracks
end

----------------------------------------------------------------------
-- Music Playback
----------------------------------------------------------------------
local function StopMusic()
    if playingHandle then
        StopSound(playingHandle)
        playingHandle = nil
    end

    -- Restore volumes
    if savedMusicVol then
        SetCVar("Sound_MusicVolume", savedMusicVol)
        savedMusicVol = nil
    end
    if savedAmbienceVol then
        SetCVar("Sound_AmbienceVolume", savedAmbienceVol)
        savedAmbienceVol = nil
    end

    if restoreTimer then
        restoreTimer:Cancel()
        restoreTimer = nil
    end

    playing = false
end

local function PlayLustMusic()
    if not db.musicEnabled then return end
    if playing then return end

    local tracks = GetEnabledTracks()
    if #tracks == 0 then return end

    -- Pick track
    local track
    if db.playMode == "random" then
        track = tracks[math.random(#tracks)]
    else
        -- Sequential
        local nextIndex = db.lastTrackIndex + 1
        -- Find next enabled track starting from lastTrackIndex
        local found = false
        for _, t in ipairs(tracks) do
            if t.index > db.lastTrackIndex then
                track = t
                found = true
                break
            end
        end
        if not found then
            track = tracks[1]  -- wrap around
        end
        db.lastTrackIndex = track.index
    end

    -- Save and mute background audio
    savedMusicVol = tonumber(GetCVar("Sound_MusicVolume"))
    savedAmbienceVol = tonumber(GetCVar("Sound_AmbienceVolume"))
    SetCVar("Sound_MusicVolume", 0)
    SetCVar("Sound_AmbienceVolume", 0)

    -- Play
    local success, handle = PlaySoundFile(track.path, db.channel or "Master")
    if success then
        playing = true
        playingHandle = handle
        print(string.format(L["MSG_MUSIC_PLAYING"], track.name))
    end

    -- Restore after MUSIC_DURATION seconds (always 40s, regardless of buff)
    restoreTimer = C_Timer.NewTimer(MUSIC_DURATION, function()
        StopMusic()
    end)
end

----------------------------------------------------------------------
-- Preview Playback (for settings panel)
----------------------------------------------------------------------
local function StopPreview()
    if previewHandle then
        StopSound(previewHandle)
        previewHandle = nil
    end
end

local function PreviewTrack(index)
    StopPreview()
    local track = MUSIC_FILES[index]
    if not track then return end
    local channel = (db and db.channel) or "Master"
    local success, handle = PlaySoundFile(track.path, channel)
    if success then
        previewHandle = handle
    end
end

----------------------------------------------------------------------
-- Countdown Bar (DBT-style: text above bar, icon outside left)
----------------------------------------------------------------------

-- Locale-aware font (same as DBM)
local barFont
if LOCALE_koKR then
    barFont = "Fonts\\2002.TTF"
elseif LOCALE_zhCN then
    barFont = "Fonts\\ARKai_T.ttf"
elseif LOCALE_zhTW then
    barFont = "Fonts\\blei00d.TTF"
else
    barFont = "Fonts\\FRIZQT__.TTF"
end

-- Bar texture: prefer normTex (SharedMedia) → DBM default → fallback
local barTexture
if C_AddOns.IsAddOnLoaded("SharedMedia") then
    barTexture = "Interface\\AddOns\\SharedMedia\\statusbar\\normTex"
elseif C_AddOns.IsAddOnLoaded("DBM-StatusBarTimers") then
    barTexture = "Interface\\AddOns\\DBM-StatusBarTimers\\textures\\default.blp"
else
    barTexture = "Interface\\Buttons\\WHITE8X8"
end

local barSpark  -- spark texture reference

local function CreateBarFrame()
    if barFrame then return end

    local bw = (db and db.barWidth) or DB_DEFAULTS.barWidth
    local bh = (db and db.barHeight) or DB_DEFAULTS.barHeight
    local bx = (db and db.barX) or DB_DEFAULTS.barX
    local by = (db and db.barY) or DB_DEFAULTS.barY
    local iconSize = bh + 14  -- icon spans bar + text area
    local textOverlap = 4     -- how much text overlaps into bar

    -- Main frame: icon + bar + text overlap area
    barFrame = CreateFrame("Frame", "MiliUI_BloodlustMusicBar", UIParent)
    barFrame:SetSize(bw + iconSize + 4, iconSize + 10)  -- 10 for text above overlap
    barFrame:SetPoint("CENTER", UIParent, "CENTER", bx, by)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetFrameLevel(10)
    barFrame:Hide()

    -- Icon border (1px black border around icon)
    local iconBorder = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    iconBorder:SetSize(iconSize, iconSize)
    iconBorder:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", 0, 0)
    iconBorder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    iconBorder:SetBackdropColor(0, 0, 0, 1)
    iconBorder:SetBackdropBorderColor(0, 0, 0, 1)

    -- Spell icon (inside icon border)
    barIcon = iconBorder:CreateTexture(nil, "ARTWORK")
    barIcon:SetPoint("TOPLEFT", iconBorder, "TOPLEFT", 1, -1)
    barIcon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -1, 1)
    barIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    barIcon:SetTexture(DEFAULT_LUST_ICON)
    barFrame.iconBorder = iconBorder

    -- Bar container with 1px black border
    local barBorder = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    barBorder:SetPoint("BOTTOMLEFT", iconBorder, "BOTTOMRIGHT", 2, 0)
    barBorder:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", 0, 0)
    barBorder:SetHeight(bh + 2)  -- bar area only
    barBorder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    barBorder:SetBackdropColor(0, 0, 0, 0.5)
    barBorder:SetBackdropBorderColor(0, 0, 0, 1)
    barFrame.barBorder = barBorder

    -- Status bar (inside the border)
    barStatusBar = CreateFrame("StatusBar", nil, barBorder)
    barStatusBar:SetPoint("TOPLEFT", barBorder, "TOPLEFT", 1, -1)
    barStatusBar:SetPoint("BOTTOMRIGHT", barBorder, "BOTTOMRIGHT", -1, 1)
    barStatusBar:SetStatusBarTexture(barTexture)
    barStatusBar:SetStatusBarColor(0.345, 0.545, 1, 1)  -- blue
    barStatusBar:SetMinMaxValues(0, 1)
    barStatusBar:SetValue(1)

    -- Spark overlay at fill edge
    barSpark = barStatusBar:CreateTexture(nil, "OVERLAY")
    barSpark:SetSize(12, bh * 3)
    barSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    barSpark:SetBlendMode("ADD")
    barSpark:SetPoint("CENTER", barStatusBar:GetStatusBarTexture(), "RIGHT", 0, 0)

    -- Text overlay frame (higher frame level to sit above bar)
    local textOverlay = CreateFrame("Frame", nil, barFrame)
    textOverlay:SetAllPoints(barFrame)
    textOverlay:SetFrameLevel(barBorder:GetFrameLevel() + 10)

    -- Spell name text — overlapping slightly on bar top, left side
    barText = textOverlay:CreateFontString(nil, "OVERLAY")
    barText:SetFont(barFont, 15, "OUTLINE")
    barText:SetPoint("BOTTOMLEFT", barBorder, "TOPLEFT", 4, -textOverlap)
    barText:SetJustifyH("LEFT")
    barText:SetWordWrap(false)
    barText:SetText(DEFAULT_LUST_NAME)

    -- Time remaining text — centered on bar, bigger
    barTimeText = textOverlay:CreateFontString(nil, "OVERLAY")
    barTimeText:SetFont(barFont, 18, "OUTLINE")
    barTimeText:SetPoint("RIGHT", barBorder, "RIGHT", -4, 8)
    barTimeText:SetJustifyH("RIGHT")
    barTimeText:SetTextColor(1, 1, 1)
    barTimeText:SetText("40.0")

    -- Constrain name text to not overlap timer
    barText:SetPoint("RIGHT", barTimeText, "LEFT", -2, 0)

    -- Drag support (Edit Mode only)
    barFrame:SetMovable(true)
    barFrame:SetUserPlaced(false)
    barFrame:SetClampedToScreen(true)
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", function(self)
        if self.unlocked then self:StartMoving() end
    end)
    barFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        local cx, cy = UIParent:GetCenter()
        local fx, fy = self:GetCenter()
        db.barX = math.floor(fx - cx + 0.5)
        db.barY = math.floor(fy - cy + 0.5)
    end)

    -- Edit Mode selection overlay
    local editSelection = CreateFrame("Frame", nil, barFrame, "EditModeSystemSelectionTemplate")
    editSelection:SetAllPoints()
    editSelection:Hide()
    editSelection:RegisterForDrag("LeftButton")
    editSelection:SetScript("OnDragStart", function() barFrame:StartMoving() end)
    editSelection:SetScript("OnDragStop", function()
        barFrame:StopMovingOrSizing()
        barFrame:SetUserPlaced(false)
        local cx, cy = UIParent:GetCenter()
        local fx, fy = barFrame:GetCenter()
        db.barX = math.floor(fx - cx + 0.5)
        db.barY = math.floor(fy - cy + 0.5)
    end)
    editSelection.system = {
        GetSystemName = function()
            return L["ADDON_TITLE"]
        end
    }
    barFrame.editSelection = editSelection

    -- OnUpdate for countdown animation
    barFrame:SetScript("OnUpdate", function(self, dt)
        if not activeLustExpiration then
            if barTestTimer then return end
            if isInEditMode then return end  -- Don't hide in Edit Mode
            self:Hide()
            return
        end

        local remaining = activeLustExpiration - GetTime()
        if remaining <= 0 then
            self:Hide()
            activeLustSpellID = nil
            activeLustExpiration = nil
            activeLustDuration = nil
            return
        end

        local ratio = remaining / (activeLustDuration or 40)
        barStatusBar:SetValue(ratio)
        barTimeText:SetText(string.format("%.1f", remaining))

        -- Dynamic color: blue → dark blue as time runs out
        local r = 0.15 + 0.195 * ratio
        local g = 0.385 + 0.16 * ratio
        local b = 1
        barStatusBar:SetStatusBarColor(r, g, b, 1)
    end)
end

local function UpdateBarPosition()
    if not barFrame then return end
    barFrame:ClearAllPoints()
    local bx = (db and db.barX) or DB_DEFAULTS.barX
    local by = (db and db.barY) or DB_DEFAULTS.barY
    barFrame:SetPoint("CENTER", UIParent, "CENTER", bx, by)
end

local function UpdateBarSize()
    if not barFrame then return end
    local bw = (db and db.barWidth) or DB_DEFAULTS.barWidth
    local bh = (db and db.barHeight) or DB_DEFAULTS.barHeight
    local iconSize = bh + 14
    barFrame:SetSize(bw + iconSize + 4, iconSize + 4)
    if barFrame.iconBorder then
        barFrame.iconBorder:SetSize(iconSize, iconSize)
    end
    if barFrame.barBorder then
        barFrame.barBorder:SetHeight(bh + 2)
    end
    if barSpark then
        barSpark:SetSize(12, bh * 3)
    end
end

local function UpdateEditModeState()
    if isInEditMode then
        -- Only show in edit mode if bar is enabled
        if not (db and db.barEnabled) then
            if barFrame then
                barFrame.editSelection:Hide()
                barFrame:Hide()
            end
            return
        end
        -- Create bar frame first if it doesn't exist yet
        CreateBarFrame()
        barFrame.unlocked = true
        barFrame:EnableMouse(true)
        -- Show bar in edit mode for positioning
        barStatusBar:SetValue(0.7)
        barText:SetText(DEFAULT_LUST_NAME)
        barTimeText:SetText("30.0")
        barIcon:SetTexture(DEFAULT_LUST_ICON)
        barFrame.editSelection:ShowHighlighted()
        UpdateBarPosition()
        UpdateBarSize()
        barFrame:Show()
    else
        if not barFrame then return end
        barFrame.unlocked = false
        barFrame:EnableMouse(false)
        barFrame.editSelection:Hide()
        -- Only hide if no active buff
        if not activeLustSpellID then
            barFrame:Hide()
        end
    end
end

-- Robust EditMode hook — handles all timing scenarios
-- EditModeManagerFrame might not exist at file load (LoD or late init)
local editModeHooked = false

local function HookEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    DebugPrint("EditMode HOOKED successfully")

    EditModeManagerFrame:HookScript("OnShow", function()
        DebugPrint("EditMode OnShow fired")
        isInEditMode = true
        UpdateEditModeState()
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        DebugPrint("EditMode OnHide fired")
        isInEditMode = false
        UpdateEditModeState()
    end)

    -- If EditMode is already shown (e.g. hooked during first open), trigger now
    if EditModeManagerFrame:IsShown() then
        DebugPrint("EditMode already shown, triggering now")
        isInEditMode = true
        UpdateEditModeState()
    end
end

-- Tier 1: Try immediately at file scope
HookEditMode()

-- Tier 2: Wait for Blizzard_EditMode addon if it's LoadOnDemand
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", function()
        DebugPrint("Blizzard_EditMode addon loaded, attempting hook")
        HookEditMode()
    end)
end

-- Eagerly create bar frame at file scope so EditMode can find it
CreateBarFrame()

local function ShowBar(spellID, spellName, spellIcon, duration, expirationTime)
    if not db.barEnabled then return end

    CreateBarFrame()

    activeLustSpellID = spellID
    activeLustDuration = duration or 40
    activeLustExpiration = expirationTime or (GetTime() + activeLustDuration)

    barIcon:SetTexture(spellIcon or DEFAULT_LUST_ICON)
    barText:SetText(spellName or DEFAULT_LUST_NAME)
    barStatusBar:SetValue(1)
    barTimeText:SetText(string.format("%.0f", activeLustDuration))

    UpdateBarPosition()
    UpdateBarSize()
    barFrame:Show()
end

local testBarShowing = false
local testBarBtnRef = nil  -- will be set when button is created

local function HideTestBar()
    testBarShowing = false
    if barTestTimer then barTestTimer:Cancel() barTestTimer = nil end
    activeLustSpellID = nil
    activeLustExpiration = nil
    activeLustDuration = nil
    if barFrame then barFrame:Hide() end
    if testBarBtnRef then testBarBtnRef:SetText(L["TEST_BAR"]) end
end

local function ShowTestBar()
    if testBarShowing then
        HideTestBar()
        return
    end

    CreateBarFrame()

    activeLustSpellID = 2825
    activeLustDuration = 40
    activeLustExpiration = GetTime() + 40

    barIcon:SetTexture(DEFAULT_LUST_ICON)
    barText:SetText(DEFAULT_LUST_NAME)
    barStatusBar:SetValue(1)
    barTimeText:SetText("40")

    UpdateBarPosition()
    UpdateBarSize()
    barFrame:Show()
    testBarShowing = true
    if testBarBtnRef then testBarBtnRef:SetText(L["HIDE_BAR"]) end

    -- Auto-hide after test
    if barTestTimer then barTestTimer:Cancel() end
    barTestTimer = C_Timer.NewTimer(40, function()
        HideTestBar()
    end)
end

----------------------------------------------------------------------
-- Bloodlust Detection (Debuff-based, 12.0 combat safe)
-- Debuffs (Exhaustion/Sated) are more reliably readable in combat.
-- When debuff appears → trigger music & bar.
-- Try to read buff for display info (icon, name, duration).
----------------------------------------------------------------------

-- Check for lust debuff (primary trigger)
local function CheckForLustDebuff()
    for _, spellID in ipairs(LUST_DEBUFFS) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok and aura then
            DebugPrint("Found lust DEBUFF: spellID=", spellID, "name=", aura.name)
            return spellID, aura.name
        elseif not ok then
            DebugPrint("pcall error for debuff spellID", spellID, ":", aura)
        end
    end
    return nil
end

-- Try to read lust buff for display info (icon, name, countdown)
local function GetLustBuffInfo()
    for _, spellID in ipairs(LUST_BUFFS) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok and aura then
            DebugPrint("Found lust BUFF info: spellID=", spellID, "name=", aura.name, "duration=", aura.duration, "expiration=", aura.expirationTime)
            return spellID, aura.name, aura.icon, aura.duration, aura.expirationTime
        end
    end
    return nil
end

local lustDetected = false

local eventFrame = CreateFrame("Frame")

local function OnUnitAura(_, unit)
    if unit ~= "player" then return end
    DebugPrint("UNIT_AURA fired for player, lustDetected=", tostring(lustDetected), "inCombat=", tostring(InCombatLockdown()))

    local debuffID = CheckForLustDebuff()

    if debuffID and not lustDetected then
        -- Lust debuff just appeared → lust was cast!
        lustDetected = true
        DebugPrint("Lust TRIGGERED via debuff", debuffID)

        -- Try to get buff info for display (name, icon, duration)
        local buffID, buffName, buffIcon, buffDuration, buffExpiration = GetLustBuffInfo()

        -- Use buff info if available, fallback to defaults
        local displayName = buffName or DEFAULT_LUST_NAME
        local displayIcon = buffIcon or DEFAULT_LUST_ICON
        local displayDuration = buffDuration or 40
        local displayExpiration = buffExpiration or (GetTime() + 40)
        local displaySpellID = buffID or debuffID

        DebugPrint("Playing music and showing bar: name=", displayName, "duration=", displayDuration)
        PlayLustMusic()
        ShowBar(displaySpellID, displayName, displayIcon, displayDuration, displayExpiration)

    elseif debuffID and lustDetected then
        -- Still active, try to update bar with buff info if available
        local buffID, buffName, buffIcon, buffDuration, buffExpiration = GetLustBuffInfo()
        if buffID and activeLustSpellID ~= buffID then
            activeLustSpellID = buffID
            activeLustDuration = buffDuration or 40
            activeLustExpiration = buffExpiration or (GetTime() + activeLustDuration)
            if barFrame and barFrame:IsShown() then
                barIcon:SetTexture(buffIcon or DEFAULT_LUST_ICON)
                barText:SetText(buffName or DEFAULT_LUST_NAME)
            end
        end

    elseif not debuffID and lustDetected then
        -- Lust debuff gone (shouldn't happen during 40s window, but handle)
        DebugPrint("Lust debuff GONE, resetting")
        lustDetected = false
        activeLustSpellID = nil
        activeLustExpiration = nil
        activeLustDuration = nil
        -- Bar will auto-hide via OnUpdate when remaining <= 0
        -- Music continues for its full duration (40s)
    end
end

----------------------------------------------------------------------
-- Event Handling
----------------------------------------------------------------------
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitDB()

        -- Register slash commands
        SLASH_MILIUI_BLM1 = "/blm"
        SLASH_MILIUI_BLM2 = "/bloodlustmusic"
        SlashCmdList["MILIUI_BLM"] = function(input)
            input = strtrim(input or ""):lower()
            if input == "test" then
                PlayLustMusic()
                ShowTestBar()
            elseif input == "bar" then
                ShowTestBar()
            elseif input == "stop" then
                StopMusic()
                StopPreview()
            elseif input == "debug" then
                debugMode = not debugMode
                print("|cffff8800[BLM]|r Debug mode:", debugMode and "|cff00ff00ON|r" or "|cffff0000OFF|r")
                if debugMode then
                    print("|cffff8800[BLM]|r lustDetected=", tostring(lustDetected), "activeLustSpellID=", tostring(activeLustSpellID))
                    print("|cffff8800[BLM]|r db.musicEnabled=", tostring(db and db.musicEnabled), "db.barEnabled=", tostring(db and db.barEnabled))
                    -- Quick scan for any active lust buff
                    local did = CheckForLustDebuff()
                    print("|cffff8800[BLM]|r Current lust debuff:", tostring(did))
                    local bid, bn = GetLustBuffInfo()
                    print("|cffff8800[BLM]|r Current lust buff:", tostring(bid), tostring(bn))
                end
            else
                if _G.MiliUI_OpenBloodlustMusicSettings then
                    _G.MiliUI_OpenBloodlustMusicSettings()
                end
            end
        end

        -- Tier 3: Try hooking EditMode at PLAYER_LOGIN as final fallback
        HookEditMode()

        -- Eagerly create bar frame so EditMode can use it
        CreateBarFrame()



        -- Check if lust BUFF is still active on login (use buff, NOT debuff — debuff lasts 10min)
        C_Timer.After(1, function()
            local buffID, name, icon, duration, expirationTime = GetLustBuffInfo()
            if buffID then
                lustDetected = true
                ShowBar(buffID, name or DEFAULT_LUST_NAME, icon or DEFAULT_LUST_ICON, duration or 40, expirationTime or (GetTime() + 40))
            end
        end)

        print(L["LOADED_MSG"])

    elseif event == "UNIT_AURA" then
        if db then
            OnUnitAura(self, ...)
        end
    end
end)

----------------------------------------------------------------------
-- Settings Panel (Retail Settings API)
----------------------------------------------------------------------

-- Store category reference
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
enableMusicCheck:SetChecked(DB_DEFAULTS.musicEnabled)  -- immediate default
enableMusicCheck.Text = enableMusicCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableMusicCheck.Text:SetPoint("LEFT", enableMusicCheck, "RIGHT", 5, 0)
enableMusicCheck.Text:SetText(L["ENABLE_MUSIC"])

local enableMusicDesc = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
enableMusicDesc:SetPoint("LEFT", enableMusicCheck.Text, "RIGHT", 10, 0)
enableMusicDesc:SetText("- " .. L["ENABLE_MUSIC_DESC"])

enableMusicCheck:SetScript("OnShow", function(self)
    if db then self:SetChecked(db.musicEnabled) end
end)
enableMusicCheck:SetScript("OnClick", function(self)
    if db then db.musicEnabled = self:GetChecked() and true or false end
end)

-- Play Mode Toggle Button
local playModeBtn = CreateFrame("Button", nil, musicPanel, "UIPanelButtonTemplate")
playModeBtn:SetSize(140, 28)
playModeBtn:SetPoint("TOPLEFT", enableMusicCheck, "BOTTOMLEFT", 4, -15)
playModeBtn:SetText(L["PLAY_MODE_RANDOM"])  -- immediate fallback text

local function UpdatePlayModeButton()
    local mode = (db and db.playMode) or "random"
    if mode == "random" then
        playModeBtn:SetText(L["PLAY_MODE_RANDOM"])
    else
        playModeBtn:SetText(L["PLAY_MODE_SEQUENTIAL"])
    end
end

playModeBtn:SetScript("OnShow", function() UpdatePlayModeButton() end)
playModeBtn:SetScript("OnClick", function()
    if not db then return end
    if db.playMode == "random" then
        db.playMode = "sequential"
    else
        db.playMode = "random"
    end
    UpdatePlayModeButton()
end)

local playModeDesc = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
playModeDesc:SetPoint("LEFT", playModeBtn, "RIGHT", 10, 0)
playModeDesc:SetText("- " .. L["PLAY_MODE_DESC"])

-- Channel Toggle Button
local channelBtn = CreateFrame("Button", nil, musicPanel, "UIPanelButtonTemplate")
channelBtn:SetSize(140, 28)
channelBtn:SetPoint("TOPLEFT", playModeBtn, "BOTTOMLEFT", 0, -10)
channelBtn:SetText(L["CHANNEL"] .. ": Master")  -- immediate fallback text

local channelDesc = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
channelDesc:SetPoint("LEFT", channelBtn, "RIGHT", 10, 0)
channelDesc:SetText("- " .. L["CHANNEL_DESC"])

-- Dynamic channel explanation below the button
local channelExplain = musicPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
channelExplain:SetPoint("TOPLEFT", channelBtn, "BOTTOMLEFT", 2, -4)
channelExplain:SetWidth(400)
channelExplain:SetJustifyH("LEFT")
channelExplain:SetText("|cff888888" .. L["CHANNEL_MASTER_DESC"] .. "|r")  -- immediate fallback

local function UpdateChannelButton()
    local ch = (db and db.channel) or "Master"
    channelBtn:SetText(L["CHANNEL"] .. ": " .. ch)
    if ch == "Master" then
        channelExplain:SetText("|cff888888" .. L["CHANNEL_MASTER_DESC"] .. "|r")
    else
        channelExplain:SetText("|cff888888" .. L["CHANNEL_SFX_DESC"] .. "|r")
    end
end

channelBtn:SetScript("OnShow", function() UpdateChannelButton() end)
channelBtn:SetScript("OnClick", function()
    if not db then return end
    -- Cycle through channels
    local current = db.channel or "Master"
    for i, ch in ipairs(CHANNELS) do
        if ch == current then
            db.channel = CHANNELS[(i % #CHANNELS) + 1]
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
    local lastAnchor = trackHeader

    for i, track in ipairs(MUSIC_FILES) do
        -- Checkbox
        local ck = trackChecks[i]
        if not ck then
            ck = CreateFrame("CheckButton", nil, musicPanel, "UICheckButtonTemplate")
            ck.Text = ck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            ck.Text:SetPoint("LEFT", ck, "RIGHT", 5, 0)
            trackChecks[i] = ck
        end

        ck:ClearAllPoints()
        ck:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", i == 1 and 0 or 0, -5)
        ck.Text:SetText(track.name)

        if db then
            ck:SetChecked(db.trackEnabled[i] ~= false)
        end

        ck:SetScript("OnClick", function(self)
            if db then
                db.trackEnabled[i] = self:GetChecked() and true or false
            end
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
                -- Auto-reset button text after a while
                C_Timer.After(10, function()
                    if not previewHandle then
                        self:SetText(L["PREVIEW"])
                    end
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

-- Force-show all track UI elements
local function ForceShowTrackList()
    for i, ck in ipairs(trackChecks) do
        if ck then ck:Show() end
    end
    for i, pvBtn in ipairs(trackPreviews) do
        if pvBtn then pvBtn:Show() end
    end
end

musicPanel:SetScript("OnShow", function()
    InitDB()
    RefreshTrackList()
    UpdatePlayModeButton()
    UpdateChannelButton()
    if db then enableMusicCheck:SetChecked(db.musicEnabled) end

    -- Force show all track elements
    ForceShowTrackList()

    -- Delayed refresh to handle Settings API timing (same pattern as ChatBar)
    C_Timer.After(0.1, function()
        if musicPanel:IsShown() then
            InitDB()
            RefreshTrackList()
            UpdatePlayModeButton()
            UpdateChannelButton()
            if db then enableMusicCheck:SetChecked(db.musicEnabled) end
            ForceShowTrackList()
        end
    end)
end)

musicPanel:SetScript("OnHide", function()
    StopPreview()
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
enableBarCheck:SetChecked(DB_DEFAULTS.barEnabled)  -- immediate default
enableBarCheck.Text = enableBarCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableBarCheck.Text:SetPoint("LEFT", enableBarCheck, "RIGHT", 5, 0)
enableBarCheck.Text:SetText(L["ENABLE_BAR"])

local enableBarDesc = barPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
enableBarDesc:SetPoint("LEFT", enableBarCheck.Text, "RIGHT", 10, 0)
enableBarDesc:SetText("- " .. L["ENABLE_BAR_DESC"])

enableBarCheck:SetScript("OnShow", function(self)
    if db then self:SetChecked(db.barEnabled) end
end)
enableBarCheck:SetScript("OnClick", function(self)
    if db then
        db.barEnabled = self:GetChecked() and true or false
        if not db.barEnabled then
            -- Immediately hide test bar and reset button
            HideTestBar()
        end
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
widthSlider:SetValue(DB_DEFAULTS.barWidth)  -- immediate default

widthSlider:SetScript("OnShow", function(self)
    if db then
        self:SetValue(db.barWidth)
        self.Text:SetText(L["BAR_WIDTH"] .. ": " .. db.barWidth)
    end
end)
widthSlider:SetScript("OnValueChanged", function(self, value)
    local val = math.floor(value)
    self.Text:SetText(L["BAR_WIDTH"] .. ": " .. val)
    if db then
        db.barWidth = val
        UpdateBarSize()
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
heightSlider:SetValue(DB_DEFAULTS.barHeight)  -- immediate default

heightSlider:SetScript("OnShow", function(self)
    if db then
        self:SetValue(db.barHeight)
        self.Text:SetText(L["BAR_HEIGHT"] .. ": " .. db.barHeight)
    end
end)
heightSlider:SetScript("OnValueChanged", function(self, value)
    local val = math.floor(value)
    self.Text:SetText(L["BAR_HEIGHT"] .. ": " .. val)
    if db then
        db.barHeight = val
        UpdateBarSize()
    end
end)

-- Test Bar Button
local testBarBtn = CreateFrame("Button", nil, barPanel, "UIPanelButtonTemplate")
testBarBtn:SetSize(140, 28)
testBarBtn:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -20)
testBarBtn:SetText(L["TEST_BAR"])
testBarBtnRef = testBarBtn  -- store reference for toggle text updates
testBarBtn:SetScript("OnClick", function()
    if not db or not db.barEnabled then return end
    ShowTestBar()
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
    if db then
        db.barX = DB_DEFAULTS.barX
        db.barY = DB_DEFAULTS.barY
        UpdateBarPosition()
        print(L["MSG_POSITION_RESET"])
    end
end)

local resetPosDesc = barPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
resetPosDesc:SetPoint("LEFT", resetPosBtn, "RIGHT", 10, 0)
resetPosDesc:SetText("- " .. L["RESET_POSITION_DESC"])

barPanel:SetScript("OnShow", function()
    InitDB()
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
-- Pre-create track list at load time (same pattern as ChatBar)
----------------------------------------------------------------------
C_Timer.After(0.5, function()
    InitDB()
    RefreshTrackList()
end)

-- Also refresh after PLAYER_LOGIN to ensure everything is ready
local settingsLoader = CreateFrame("Frame")
settingsLoader:RegisterEvent("PLAYER_LOGIN")
settingsLoader:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        InitDB()
        RefreshTrackList()
        UpdatePlayModeButton()
        UpdateChannelButton()
    end)
end)

