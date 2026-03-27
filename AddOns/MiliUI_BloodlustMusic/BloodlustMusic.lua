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
    -- Drums (Leatherworking consumables, 15% haste)
    1243972, -- Void Touched Drums (MidNight)
    444257,  -- Thunderous Drums     (TWW / The War Within)
    381301,  -- Feral Hide Drums     (Dragonflight)
    309658,  -- Drums of Deathly Ferocity (Shadowlands)
    292686,  -- Mallet of Thunderous Skins (BfA)
}

-- Lust DEBUFF spell IDs (exhaustion lockout, ~10min)
local LUST_DEBUFFS = {
    57723,   -- Exhaustion      (Heroism / Drums)
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
    { name = "Power of the Horde",    path = "Interface\\AddOns\\MiliUI_BloodlustMusic\\Media\\power_of_the_horde.mp3" },
}

local MUSIC_DURATION = 40  -- seconds to play music
local DEFAULT_CHANNEL = "Master"  -- fallback channel (Master / SFX / Dialog)
local CHANNELS = { "Master", "SFX", "Dialog" }

-- Sound engine boost values applied during Bloodlust playback
local BOOST_NUM_CHANNELS = 128         -- Sound_NumChannels
local BOOST_CACHE_SIZE   = 134217728   -- Sound_MaxCacheSizeInBytes (128 MB)

----------------------------------------------------------------------
-- SavedVariables Defaults
----------------------------------------------------------------------
local DB_DEFAULTS = {
    musicEnabled     = true,
    barEnabled       = true,
    playMode         = "random",   -- "random" or "sequential"
    channel          = DEFAULT_CHANNEL,
    trackEnabled     = {},         -- [index] = true/false per track
    lastTrackIndex   = 0,
    barWidth         = 185,
    barHeight        = 10,
    barX             = 0,
    barY             = 300,
    -- Reminder settings
    reminderEnabled  = true,
    reminderSoundEnabled  = true,
    reminderSound         = 8457,
    reminderLustClassOnly = true,
    reminderDungeonPull   = true,
    reminderDebuffExpiry  = true,
    reminderDuration      = 5,
    reminderX             = 0,
    reminderY             = 360, -- absolute position, default above bar (barY=300 + 60)
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
local savedNumChannels = nil
local savedCacheSize = nil
local restoreTimer = nil
local lastPlayTime = 0
local activeLustSpellID = nil
local activeLustExpiration = nil
local activeLustDuration = nil
local barFrame, barStatusBar, barIcon, barText, barTimeText
local barTestTimer = nil
local isInEditMode = false

----------------------------------------------------------------------
-- Expose shared state to namespace (for Options.lua, LustReminder.lua)
----------------------------------------------------------------------
ns.L = L
ns.DB_DEFAULTS = DB_DEFAULTS
ns.LUST_BUFFS = LUST_BUFFS
ns.LUST_DEBUFFS = LUST_DEBUFFS
ns.MUSIC_FILES = MUSIC_FILES
ns.CHANNELS = CHANNELS
ns.DEFAULT_CHANNEL = DEFAULT_CHANNEL
ns.DEFAULT_LUST_NAME = DEFAULT_LUST_NAME
ns.DEFAULT_LUST_ICON = DEFAULT_LUST_ICON

-- These will be populated after functions are defined
ns.GetDB = function() return db end
ns.InitDB = function() end  -- placeholder, set below

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
ns.InitDB = InitDB

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

    -- Restore sound engine settings
    if savedNumChannels then
        SetCVar("Sound_NumChannels", savedNumChannels)
        savedNumChannels = nil
    end
    if savedCacheSize then
        SetCVar("Sound_MaxCacheSizeInBytes", savedCacheSize)
        savedCacheSize = nil
    end

    if restoreTimer then
        restoreTimer:Cancel()
        restoreTimer = nil
    end

    playing = false
    lastPlayTime = 0
end

local function PlayLustMusic()
    if not db.musicEnabled then return end

    -- 40s hard cooldown to prevent double execution and volume overwrites
    local currentTime = GetTime()
    if (currentTime - lastPlayTime) < 40 then return end
    lastPlayTime = currentTime

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
    local currentMusicVol = tonumber(GetCVar("Sound_MusicVolume")) or 0
    local currentAmbienceVol = tonumber(GetCVar("Sound_AmbienceVolume")) or 0
    
    -- Only save if not zero, to prevent saving muted states accidentally
    if currentMusicVol > 0 then
        savedMusicVol = currentMusicVol
    end
    if currentAmbienceVol > 0 then
        savedAmbienceVol = currentAmbienceVol
    end

    SetCVar("Sound_MusicVolume", 0)
    SetCVar("Sound_AmbienceVolume", 0)

    -- Boost sound engine to prevent audio interruption
    savedNumChannels = tonumber(GetCVar("Sound_NumChannels")) or 64
    savedCacheSize   = tonumber(GetCVar("Sound_MaxCacheSizeInBytes")) or 0
    SetCVar("Sound_NumChannels", BOOST_NUM_CHANNELS)
    SetCVar("Sound_MaxCacheSizeInBytes", BOOST_CACHE_SIZE)

    -- Play
    local success, handle = PlaySoundFile(track.path, db.channel or DEFAULT_CHANNEL)
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
local previewSavedMusicVol = nil
local previewSavedAmbienceVol = nil
local previewSavedNumChannels = nil
local previewSavedCacheSize = nil
local previewRestoreTimer = nil

local function StopPreview()
    if previewHandle then
        StopSound(previewHandle)
        previewHandle = nil
    end
    
    if previewSavedMusicVol then
        SetCVar("Sound_MusicVolume", previewSavedMusicVol)
        previewSavedMusicVol = nil
    end
    if previewSavedAmbienceVol then
        SetCVar("Sound_AmbienceVolume", previewSavedAmbienceVol)
        previewSavedAmbienceVol = nil
    end
    if previewSavedNumChannels then
        SetCVar("Sound_NumChannels", previewSavedNumChannels)
        previewSavedNumChannels = nil
    end
    if previewSavedCacheSize then
        SetCVar("Sound_MaxCacheSizeInBytes", previewSavedCacheSize)
        previewSavedCacheSize = nil
    end
    if previewRestoreTimer then
        previewRestoreTimer:Cancel()
        previewRestoreTimer = nil
    end
end

local function PreviewTrack(index)
    StopPreview()
    local track = MUSIC_FILES[index]
    if not track then return end
    
    local currentMusicVol = tonumber(GetCVar("Sound_MusicVolume")) or 0
    local currentAmbienceVol = tonumber(GetCVar("Sound_AmbienceVolume")) or 0
    
    if currentMusicVol > 0 then previewSavedMusicVol = currentMusicVol end
    if currentAmbienceVol > 0 then previewSavedAmbienceVol = currentAmbienceVol end
    
    SetCVar("Sound_MusicVolume", 0)
    SetCVar("Sound_AmbienceVolume", 0)

    -- Boost sound engine to prevent audio interruption
    previewSavedNumChannels = tonumber(GetCVar("Sound_NumChannels")) or 64
    previewSavedCacheSize   = tonumber(GetCVar("Sound_MaxCacheSizeInBytes")) or 0
    SetCVar("Sound_NumChannels", BOOST_NUM_CHANNELS)
    SetCVar("Sound_MaxCacheSizeInBytes", BOOST_CACHE_SIZE)

    local channel = (db and db.channel) or DEFAULT_CHANNEL
    local success, handle = PlaySoundFile(track.path, channel)
    if success then
        previewHandle = handle
        previewRestoreTimer = C_Timer.NewTimer(MUSIC_DURATION or 40, function() StopPreview() end)
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


local function HideTestBar()
    testBarShowing = false
    if barTestTimer then barTestTimer:Cancel() barTestTimer = nil end
    activeLustSpellID = nil
    activeLustExpiration = nil
    activeLustDuration = nil
    if barFrame then barFrame:Hide() end
    if ns.testBarBtnRef then ns.testBarBtnRef:SetText(L["TEST_BAR"]) end
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
    if ns.testBarBtnRef then ns.testBarBtnRef:SetText(L["HIDE_BAR"]) end

    -- Auto-hide after test
    if barTestTimer then barTestTimer:Cancel() end
    barTestTimer = C_Timer.NewTimer(40, function()
        HideTestBar()
    end)
end

----------------------------------------------------------------------
-- Expose functions to namespace (for Options.lua, LustReminder.lua)
----------------------------------------------------------------------
ns.UpdateBarPosition = UpdateBarPosition
ns.UpdateBarSize = UpdateBarSize
ns.ShowTestBar = ShowTestBar
ns.HideTestBar = HideTestBar
ns.ShowBar = ShowBar
ns.StopPreview = StopPreview
ns.PreviewTrack = PreviewTrack
ns.IsPreviewPlaying = function() return previewHandle ~= nil end
ns.GetBarFrame = function() return barFrame end
ns.DebugPrint = DebugPrint

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
            elseif input == "reminder" then
                if ns.ShowReminder then ns.ShowReminder() end
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
-- Settings Panel is now in Options.lua
----------------------------------------------------------------------

