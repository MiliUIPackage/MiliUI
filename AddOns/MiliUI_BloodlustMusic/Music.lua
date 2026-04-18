local addonName, ns = ...

----------------------------------------------------------------------
-- Imports from Config.lua
----------------------------------------------------------------------
local L                         = ns.L
local LUST_BUFFS                = ns.LUST_BUFFS
local LUST_DEBUFFS              = ns.LUST_DEBUFFS
local LUST_DEBUFF_FRESH_THRESHOLD = ns.LUST_DEBUFF_FRESH_THRESHOLD
local MUSIC_FILES               = ns.MUSIC_FILES
local MUSIC_DURATION            = ns.MUSIC_DURATION
local MUSIC_MEDIA_PREFIX        = ns.MUSIC_MEDIA_PREFIX
local DEFAULT_CHANNEL           = ns.DEFAULT_CHANNEL
local BOOST_NUM_CHANNELS        = ns.BOOST_NUM_CHANNELS
local BOOST_CACHE_SIZE          = ns.BOOST_CACHE_SIZE
local DB_DEFAULTS               = ns.DB_DEFAULTS
local DEFAULT_LUST_NAME         = ns.DEFAULT_LUST_NAME
local DEFAULT_LUST_ICON         = ns.DEFAULT_LUST_ICON

----------------------------------------------------------------------
-- Debug
----------------------------------------------------------------------
local debugMode = false

local function DebugPrint(...)
    if debugMode then
        print("|cffff8800[BLM Debug]|r", ...)
    end
end
ns.DebugPrint = DebugPrint

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local db
local lastPlayTime          = 0
local activeLustSpellID     = nil
local activeLustExpiration  = nil
local activeLustDuration    = nil
local lustDetected          = false
local trackedDebuffInstanceID = nil
local barFrame, barStatusBar, barIcon, barText, barTimeText, barSpark
local barTestTimer          = nil
local testBarShowing        = false
local isInEditMode          = false

----------------------------------------------------------------------
-- DB init
----------------------------------------------------------------------
local function InitDB()
    if not MiliUI_BloodlustMusic_DB then MiliUI_BloodlustMusic_DB = {} end
    db = MiliUI_BloodlustMusic_DB

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

    for i = 1, #MUSIC_FILES do
        if db.trackEnabled[i] == nil then
            db.trackEnabled[i] = true
        end
    end
end
ns.InitDB = InitDB
ns.GetDB  = function() return db end

----------------------------------------------------------------------
-- Track list builders (built-in + custom)
----------------------------------------------------------------------
local function BuildAllTracks()
    local all = {}
    for i, t in ipairs(MUSIC_FILES) do
        all[#all + 1] = {
            source  = "builtin",
            index   = i,
            name    = t.name,
            path    = t.path,
            enabled = db.trackEnabled[i] ~= false,
        }
    end
    if db.customTracks then
        for i, t in ipairs(db.customTracks) do
            local fn = t.filename or ""
            all[#all + 1] = {
                source   = "custom",
                index    = i,
                name     = (t.name ~= nil and t.name ~= "") and t.name or fn,
                filename = fn,
                path     = MUSIC_MEDIA_PREFIX .. fn,
                enabled  = t.enabled ~= false,
            }
        end
    end
    return all
end

local function GetEnabledTracks()
    local tracks = {}
    for _, t in ipairs(BuildAllTracks()) do
        if t.enabled and t.path and t.path ~= MUSIC_MEDIA_PREFIX then
            tracks[#tracks + 1] = t
        end
    end
    return tracks
end

----------------------------------------------------------------------
-- SoundSession: shared save/mute/boost/play/restore lifecycle.
-- Used for both main lust playback and settings preview, removing the
-- ~80 lines of parallel state that existed before.
----------------------------------------------------------------------
local function NewSoundSession()
    local self = {
        handle           = nil,
        savedMusicVol    = nil,
        savedAmbienceVol = nil,
        savedNumChannels = nil,
        savedCacheSize   = nil,
        restoreTimer     = nil,
    }

    function self:Stop()
        if self.handle then
            StopSound(self.handle)
            self.handle = nil
        end
        if self.savedMusicVol then
            SetCVar("Sound_MusicVolume", self.savedMusicVol)
            self.savedMusicVol = nil
        end
        if self.savedAmbienceVol then
            SetCVar("Sound_AmbienceVolume", self.savedAmbienceVol)
            self.savedAmbienceVol = nil
        end
        if self.savedNumChannels then
            SetCVar("Sound_NumChannels", self.savedNumChannels)
            self.savedNumChannels = nil
        end
        if self.savedCacheSize then
            SetCVar("Sound_MaxCacheSizeInBytes", self.savedCacheSize)
            self.savedCacheSize = nil
        end
        if self.restoreTimer then
            self.restoreTimer:Cancel()
            self.restoreTimer = nil
        end
    end

    function self:Play(path, channel, duration)
        self:Stop()

        local curMusic    = tonumber(GetCVar("Sound_MusicVolume")) or 0
        local curAmbience = tonumber(GetCVar("Sound_AmbienceVolume")) or 0
        -- Only save if non-zero, so we don't latch a previously muted state
        if curMusic    > 0 then self.savedMusicVol    = curMusic    end
        if curAmbience > 0 then self.savedAmbienceVol = curAmbience end
        SetCVar("Sound_MusicVolume",    0)
        SetCVar("Sound_AmbienceVolume", 0)

        self.savedNumChannels = tonumber(GetCVar("Sound_NumChannels")) or 64
        self.savedCacheSize   = tonumber(GetCVar("Sound_MaxCacheSizeInBytes")) or 0
        SetCVar("Sound_NumChannels",       BOOST_NUM_CHANNELS)
        SetCVar("Sound_MaxCacheSizeInBytes", BOOST_CACHE_SIZE)

        local ok, handle = PlaySoundFile(path, channel)
        if not ok then
            self:Stop()  -- restore immediately, don't leave audio muted
            return false
        end
        self.handle = handle
        self.restoreTimer = C_Timer.NewTimer(duration, function() self:Stop() end)
        return true
    end

    function self:IsPlaying() return self.handle ~= nil end

    return self
end

local mainSession    = NewSoundSession()
local previewSession = NewSoundSession()

----------------------------------------------------------------------
-- Main playback
----------------------------------------------------------------------
local function StopMusic()
    mainSession:Stop()
    lastPlayTime = 0
end

local function PlayLustMusic()
    if not db.musicEnabled then return end

    -- 40s hard cooldown prevents double-fire (and double volume save).
    -- Set the timestamp before attempting to play, so a failed attempt
    -- doesn't let the next UNIT_AURA retry-spam us.
    local currentTime = GetTime()
    if (currentTime - lastPlayTime) < 40 then return end
    lastPlayTime = currentTime
    if mainSession:IsPlaying() then return end

    local tracks = GetEnabledTracks()
    if #tracks == 0 then return end

    local track
    if db.playMode == "random" then
        track = tracks[math.random(#tracks)]
    else
        local nextPos = (db.lastTrackIndex or 0) + 1
        if nextPos > #tracks or nextPos < 1 then nextPos = 1 end
        track = tracks[nextPos]
        db.lastTrackIndex = nextPos
    end

    if mainSession:Play(track.path, db.channel or DEFAULT_CHANNEL, MUSIC_DURATION) then
        print(string.format(L["MSG_MUSIC_PLAYING"], track.name))
    end
end

----------------------------------------------------------------------
-- Preview (settings panel)
----------------------------------------------------------------------
local function StopPreview()
    previewSession:Stop()
end

local function PreviewTrack(source, index)
    local path, name
    if source == "builtin" then
        local t = MUSIC_FILES[index]
        if t then path, name = t.path, t.name end
    elseif source == "custom" then
        local t = db and db.customTracks and db.customTracks[index]
        if t and t.filename and t.filename ~= "" then
            path = MUSIC_MEDIA_PREFIX .. t.filename
            name = (t.name ~= nil and t.name ~= "") and t.name or t.filename
        end
    end
    if not path or path == "" then return false end

    local channel = (db and db.channel) or DEFAULT_CHANNEL
    if previewSession:Play(path, channel, MUSIC_DURATION) then
        return true, name
    end
    return false, name
end

----------------------------------------------------------------------
-- Countdown bar (DBT-style: text above bar, icon outside-left)
----------------------------------------------------------------------
local barFont    = ns.LOCALE_FONT
local barTexture = ns.GetBarTexture()

-- Layout constants (used by both CreateBarFrame and UpdateBarSize)
local TEXT_OVERLAP   = 4
local ICON_EXTRA     = 14   -- iconSize = barHeight + ICON_EXTRA
local FRAME_VPADDING = 10   -- extra frame height above bar (for text overlap)
local FRAME_HPADDING = 4    -- gap between icon and bar

local function ComputeFrameSize(bw, bh)
    local iconSize = bh + ICON_EXTRA
    return bw + iconSize + FRAME_HPADDING, iconSize + FRAME_VPADDING, iconSize
end

-- Bar OnUpdate throttle accumulator (only update text/color at ~10 Hz;
-- remaining value at %.1f precision updates at most 10×/sec anyway).
local barUpdateAccum = 0

local function CreateBarFrame()
    if barFrame then return end

    local bw = (db and db.barWidth)  or DB_DEFAULTS.barWidth
    local bh = (db and db.barHeight) or DB_DEFAULTS.barHeight
    local bx = (db and db.barX)      or DB_DEFAULTS.barX
    local by = (db and db.barY)      or DB_DEFAULTS.barY

    local fw, fh, iconSize = ComputeFrameSize(bw, bh)

    barFrame = CreateFrame("Frame", "MiliUI_BloodlustMusicBar", UIParent)
    barFrame:SetSize(fw, fh)
    barFrame:SetPoint("CENTER", UIParent, "CENTER", bx, by)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetFrameLevel(10)
    barFrame:Hide()

    -- Icon + 1px border
    local iconBorder = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    iconBorder:SetSize(iconSize, iconSize)
    iconBorder:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", 0, 0)
    iconBorder:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    iconBorder:SetBackdropColor(0, 0, 0, 1)
    iconBorder:SetBackdropBorderColor(0, 0, 0, 1)

    barIcon = iconBorder:CreateTexture(nil, "ARTWORK")
    barIcon:SetPoint("TOPLEFT",     iconBorder, "TOPLEFT",      1, -1)
    barIcon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -1,  1)
    barIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    barIcon:SetTexture(DEFAULT_LUST_ICON)
    barFrame.iconBorder = iconBorder

    -- Bar container + 1px border
    local barBorder = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    barBorder:SetPoint("BOTTOMLEFT",  iconBorder, "BOTTOMRIGHT", 2, 0)
    barBorder:SetPoint("BOTTOMRIGHT", barFrame,   "BOTTOMRIGHT", 0, 0)
    barBorder:SetHeight(bh + 2)
    barBorder:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    barBorder:SetBackdropColor(0, 0, 0, 0.5)
    barBorder:SetBackdropBorderColor(0, 0, 0, 1)
    barFrame.barBorder = barBorder

    barStatusBar = CreateFrame("StatusBar", nil, barBorder)
    barStatusBar:SetPoint("TOPLEFT",     barBorder, "TOPLEFT",      1, -1)
    barStatusBar:SetPoint("BOTTOMRIGHT", barBorder, "BOTTOMRIGHT", -1,  1)
    barStatusBar:SetStatusBarTexture(barTexture)
    barStatusBar:SetStatusBarColor(0.345, 0.545, 1, 1)
    barStatusBar:SetMinMaxValues(0, 1)
    barStatusBar:SetValue(1)

    barSpark = barStatusBar:CreateTexture(nil, "OVERLAY")
    barSpark:SetSize(12, bh * 3)
    barSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    barSpark:SetBlendMode("ADD")
    barSpark:SetPoint("CENTER", barStatusBar:GetStatusBarTexture(), "RIGHT", 0, 0)

    -- Text overlay (higher frame level so text sits above bar)
    local textOverlay = CreateFrame("Frame", nil, barFrame)
    textOverlay:SetAllPoints(barFrame)
    textOverlay:SetFrameLevel(barBorder:GetFrameLevel() + 10)

    barText = textOverlay:CreateFontString(nil, "OVERLAY")
    barText:SetFont(barFont, 15, "OUTLINE")
    barText:SetPoint("BOTTOMLEFT", barBorder, "TOPLEFT", 4, -TEXT_OVERLAP)
    barText:SetJustifyH("LEFT")
    barText:SetWordWrap(false)
    barText:SetText(DEFAULT_LUST_NAME)

    barTimeText = textOverlay:CreateFontString(nil, "OVERLAY")
    barTimeText:SetFont(barFont, 18, "OUTLINE")
    barTimeText:SetPoint("RIGHT", barBorder, "RIGHT", -4, 8)
    barTimeText:SetJustifyH("RIGHT")
    barTimeText:SetTextColor(1, 1, 1)
    barTimeText:SetText("40.0")

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
        GetSystemName = function() return L["ADDON_TITLE"] end,
    }
    barFrame.editSelection = editSelection

    -- OnUpdate: ratio every frame (cheap GPU redraw), text+color at 10 Hz
    barFrame:SetScript("OnUpdate", function(self, dt)
        if not activeLustExpiration then
            if barTestTimer then return end
            if isInEditMode then return end
            self:Hide()
            return
        end

        local remaining = activeLustExpiration - GetTime()
        if remaining <= 0 then
            self:Hide()
            activeLustSpellID    = nil
            activeLustExpiration = nil
            activeLustDuration   = nil
            barUpdateAccum       = 0
            return
        end

        local ratio = remaining / (activeLustDuration or 40)
        barStatusBar:SetValue(ratio)

        barUpdateAccum = barUpdateAccum + dt
        if barUpdateAccum >= 0.1 then
            barUpdateAccum = 0
            barTimeText:SetText(string.format("%.1f", remaining))
            -- Blue → darker blue as time runs out
            local r = 0.15  + 0.195 * ratio
            local g = 0.385 + 0.16  * ratio
            barStatusBar:SetStatusBarColor(r, g, 1, 1)
        end
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
    local bw = (db and db.barWidth)  or DB_DEFAULTS.barWidth
    local bh = (db and db.barHeight) or DB_DEFAULTS.barHeight
    local fw, fh, iconSize = ComputeFrameSize(bw, bh)
    barFrame:SetSize(fw, fh)
    if barFrame.iconBorder then barFrame.iconBorder:SetSize(iconSize, iconSize) end
    if barFrame.barBorder  then barFrame.barBorder:SetHeight(bh + 2) end
    if barSpark            then barSpark:SetSize(12, bh * 3) end
end

local function UpdateEditModeState()
    if isInEditMode then
        if not (db and db.barEnabled) then
            if barFrame then
                barFrame.editSelection:Hide()
                barFrame:Hide()
            end
            return
        end
        CreateBarFrame()
        barFrame.unlocked = true
        barFrame:EnableMouse(true)
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
        if not activeLustSpellID then
            barFrame:Hide()
        end
    end
end

----------------------------------------------------------------------
-- EditMode hook (three tiers: file-scope, AddOn-loaded, PLAYER_LOGIN)
----------------------------------------------------------------------
local editModeHooked = false
local function HookEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    DebugPrint("EditMode HOOKED successfully")

    EditModeManagerFrame:HookScript("OnShow", function()
        isInEditMode = true
        UpdateEditModeState()
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        isInEditMode = false
        UpdateEditModeState()
    end)

    if EditModeManagerFrame:IsShown() then
        isInEditMode = true
        UpdateEditModeState()
    end
end

HookEditMode()  -- Tier 1

if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)  -- Tier 2
end

CreateBarFrame()  -- create eagerly so EditMode can find it

----------------------------------------------------------------------
-- Bar show / test
----------------------------------------------------------------------
local function ShowBar(spellID, spellName, spellIcon, duration, expirationTime)
    if not db.barEnabled then return end
    CreateBarFrame()

    activeLustSpellID    = spellID
    activeLustDuration   = duration or 40
    activeLustExpiration = expirationTime or (GetTime() + activeLustDuration)
    barUpdateAccum       = 0.1  -- force immediate text/color update on first frame

    barIcon:SetTexture(spellIcon or DEFAULT_LUST_ICON)
    barText:SetText(spellName or DEFAULT_LUST_NAME)
    barStatusBar:SetValue(1)
    barTimeText:SetText(string.format("%.0f", activeLustDuration))

    UpdateBarPosition()
    UpdateBarSize()
    barFrame:Show()
end

local function HideTestBar()
    testBarShowing = false
    if barTestTimer then barTestTimer:Cancel(); barTestTimer = nil end
    activeLustSpellID    = nil
    activeLustExpiration = nil
    activeLustDuration   = nil
    if barFrame then barFrame:Hide() end
    if ns.testBarBtnRef then ns.testBarBtnRef:SetText(L["TEST_BAR"]) end
end

local function ShowTestBar()
    if testBarShowing then HideTestBar(); return end

    CreateBarFrame()
    activeLustSpellID    = 2825
    activeLustDuration   = 40
    activeLustExpiration = GetTime() + 40
    barUpdateAccum       = 0.1

    barIcon:SetTexture(DEFAULT_LUST_ICON)
    barText:SetText(DEFAULT_LUST_NAME)
    barStatusBar:SetValue(1)
    barTimeText:SetText("40")

    UpdateBarPosition()
    UpdateBarSize()
    barFrame:Show()
    testBarShowing = true
    if ns.testBarBtnRef then ns.testBarBtnRef:SetText(L["HIDE_BAR"]) end

    if barTestTimer then barTestTimer:Cancel() end
    barTestTimer = C_Timer.NewTimer(40, HideTestBar)
end

----------------------------------------------------------------------
-- Lust detection helpers
----------------------------------------------------------------------
local function ScanForLustDebuff()
    for _, spellID in ipairs(LUST_DEBUFFS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then
            return spellID, aura.name, aura.expirationTime, aura.auraInstanceID
        end
    end
    return nil
end

local function GetLustBuffInfo()
    for _, spellID in ipairs(LUST_BUFFS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then
            return spellID, aura.name, aura.icon, aura.duration, aura.expirationTime
        end
    end
    return nil
end

local function IsDebuffFresh(expirationTime)
    if not expirationTime or expirationTime <= 0 then return true end
    return (expirationTime - GetTime()) > LUST_DEBUFF_FRESH_THRESHOLD
end

-- UNIT_AURA payload filtering helpers.
-- NOTE: 12.0 may mark `aura.spellId` on `addedAuras` entries as "secret"
-- (unusable as a table index). Only `auraInstanceID` is reliably readable.
-- So we can only answer "was SOMETHING added?" — if so, fall through to a
-- full scan. Removals compare against our own tracked instance ID, which
-- is always safe. Pure updates (stack/refresh) still get skipped — that's
-- where the bulk of savings come from during combat.
local function RemovedContainsTracked(removedIDs, target)
    if not removedIDs or not target then return false end
    for _, id in ipairs(removedIDs) do
        if id == target then return true end
    end
    return false
end

----------------------------------------------------------------------
-- UNIT_AURA: main detection + bar refresh
----------------------------------------------------------------------
local function OnUnitAura(unit, updateInfo)
    if unit ~= "player" then return end

    -- Fast path: skip pure-update events using the 12.0 payload.
    -- Full updates (login/zone) always scan; otherwise we care about:
    --   • any aura being added (can't cheaply tell which → scan), or
    --   • our tracked debuff instance being removed.
    if updateInfo and not updateInfo.isFullUpdate then
        local relevant =
            (updateInfo.addedAuras and #updateInfo.addedAuras > 0) or
            RemovedContainsTracked(updateInfo.removedAuraInstanceIDs, trackedDebuffInstanceID)
        if not relevant then return end
    end

    if debugMode then
        DebugPrint("UNIT_AURA relevant, lustDetected=", lustDetected, "inCombat=", InCombatLockdown())
    end

    local debuffID, _, debuffExpiration, debuffInstanceID = ScanForLustDebuff()

    if debuffID and not lustDetected then
        -- First time we see the debuff. Could be a fresh cast, or a stale
        -- exhaustion left over from before we started watching (reload after
        -- a wipe). Mark detected either way so we don't keep re-entering;
        -- only play music/bar when fresh.
        lustDetected              = true
        trackedDebuffInstanceID   = debuffInstanceID

        if not IsDebuffFresh(debuffExpiration) then
            DebugPrint("Stale lust debuff, suppressing playback")
            return
        end

        DebugPrint("Lust TRIGGERED via debuff", debuffID)

        local buffID, buffName, buffIcon, buffDuration, buffExpiration = GetLustBuffInfo()
        local displayName       = buffName or DEFAULT_LUST_NAME
        local displayIcon       = buffIcon or DEFAULT_LUST_ICON
        local displayDuration   = buffDuration or 40
        local displayExpiration = buffExpiration or (GetTime() + 40)
        local displaySpellID    = buffID or debuffID

        PlayLustMusic()
        ShowBar(displaySpellID, displayName, displayIcon, displayDuration, displayExpiration)

    elseif debuffID and lustDetected then
        -- Already tracking. Update instance ID (in case debuff was refreshed)
        -- and try to upgrade bar with real buff info when it becomes readable.
        trackedDebuffInstanceID = debuffInstanceID
        local buffID, buffName, buffIcon, buffDuration, buffExpiration = GetLustBuffInfo()
        if buffID and activeLustSpellID ~= buffID then
            activeLustSpellID    = buffID
            activeLustDuration   = buffDuration or 40
            activeLustExpiration = buffExpiration or (GetTime() + activeLustDuration)
            if barFrame and barFrame:IsShown() then
                barIcon:SetTexture(buffIcon or DEFAULT_LUST_ICON)
                barText:SetText(buffName or DEFAULT_LUST_NAME)
            end
        end

    elseif not debuffID and lustDetected then
        -- Debuff gone (rare within 40s, but handle). Bar auto-hides when
        -- remaining <= 0 via OnUpdate; music continues its full 40s.
        DebugPrint("Lust debuff gone, resetting state")
        lustDetected            = false
        trackedDebuffInstanceID = nil
        activeLustSpellID       = nil
        activeLustExpiration    = nil
        activeLustDuration      = nil
    end
end

----------------------------------------------------------------------
-- Event frame + slash commands
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitDB()

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
                    local did = ScanForLustDebuff()
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

        HookEditMode()    -- Tier 3
        CreateBarFrame()

        -- At login: figure out if we're already inside a lust window.
        --   buff active                  → show bar, suppress re-trigger
        --   stale debuff (>9 min old)    → mark detected so no replay
        --   fresh debuff but no buff yet → let UNIT_AURA handle on next tick
        C_Timer.After(1, function()
            local buffID, name, icon, duration, expirationTime = GetLustBuffInfo()
            if buffID then
                lustDetected = true
                local debuffID, _, _, instID = ScanForLustDebuff()
                if instID then trackedDebuffInstanceID = instID end
                ShowBar(buffID, name or DEFAULT_LUST_NAME, icon or DEFAULT_LUST_ICON,
                        duration or 40, expirationTime or (GetTime() + 40))
            else
                local dbID, _, dbExpiration, dbInstID = ScanForLustDebuff()
                if dbID and not IsDebuffFresh(dbExpiration) then
                    lustDetected            = true
                    trackedDebuffInstanceID = dbInstID
                    DebugPrint("Login: stale lust debuff, suppressing replay")
                end
            end
        end)

        print(L["LOADED_MSG"])

    elseif event == "UNIT_AURA" then
        if db then OnUnitAura(...) end
    end
end)

----------------------------------------------------------------------
-- Namespace exports
----------------------------------------------------------------------
ns.UpdateBarPosition = UpdateBarPosition
ns.UpdateBarSize     = UpdateBarSize
ns.ShowTestBar       = ShowTestBar
ns.HideTestBar       = HideTestBar
ns.ShowBar           = ShowBar
ns.StopPreview       = StopPreview
ns.PreviewTrack      = PreviewTrack
ns.IsPreviewPlaying  = function() return previewSession:IsPlaying() end
ns.GetBarFrame       = function() return barFrame end
