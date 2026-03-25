local addonName, ns = ...
local L = ns.L
local DB_DEFAULTS = ns.DB_DEFAULTS

----------------------------------------------------------------------
-- Lust class/spell configuration (easy-to-edit arrays)
----------------------------------------------------------------------
local LUST_SPELLS = {
    { classID = "SHAMAN",  spellID = 2825,   altSpellID = 32182 },  -- Bloodlust / Heroism
    { classID = "MAGE",    spellID = 80353  },                       -- Time Warp
    { classID = "EVOKER",  spellID = 390386 },                       -- Fury of the Aspects
    { classID = "HUNTER",  spellID = 264667, altSpellID = 466904 },  -- Primal Rage / Harrier's Cry
}

----------------------------------------------------------------------
-- Lust debuff IDs (reuse from ns)
----------------------------------------------------------------------
local LUST_DEBUFFS = ns.LUST_DEBUFFS

----------------------------------------------------------------------
-- Built-in reminder sounds (easy to change default)
----------------------------------------------------------------------
-- SoundKit IDs:
--   8959  = Raid Warning
--   8960  = Ready Check
--   8454  = Level Up
--   8332  = PvP Warning
--   7279  = Alarm Clock
--   8574  = Dungeon Reward
local REMINDER_SOUND = 8959  -- ← change this to use a different default

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local db
local reminderFrame, reminderIcon, reminderText
local watchingDebuffExpiry = false
local firstPullPending = false
local isInEditMode = false

----------------------------------------------------------------------
-- Detect if player can cast a lust spell
----------------------------------------------------------------------
local function PlayerCanLust()
    for _, entry in ipairs(LUST_SPELLS) do
        if IsSpellKnown(entry.spellID) or IsSpellKnown(entry.spellID, true) then
            return true
        end
        if entry.altSpellID and (IsSpellKnown(entry.altSpellID) or IsSpellKnown(entry.altSpellID, true)) then
            return true
        end
    end
    local _, className = UnitClass("player")
    if className == "HUNTER" then return true end
    return false
end

----------------------------------------------------------------------
-- Get player's lust spell info (name + icon)
----------------------------------------------------------------------
local function GetPlayerLustSpell()
    local _, className = UnitClass("player")
    for _, entry in ipairs(LUST_SPELLS) do
        if entry.classID == className then
            local name = C_Spell.GetSpellName(entry.spellID)
            local info = C_Spell.GetSpellInfo(entry.spellID)
            if name and info then
                return name, info.iconID
            end
            if entry.altSpellID then
                name = C_Spell.GetSpellName(entry.altSpellID)
                info = C_Spell.GetSpellInfo(entry.altSpellID)
                if name and info then
                    return name, info.iconID
                end
            end
        end
    end
    return nil, nil
end

----------------------------------------------------------------------
-- Check if player has any lust-lockout debuff
----------------------------------------------------------------------
local function PlayerHasLustDebuff()
    for _, spellID in ipairs(LUST_DEBUFFS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then return true end
    end
    return false
end

----------------------------------------------------------------------
-- Play reminder sound
----------------------------------------------------------------------
local function PlayReminderSound()
    if not db then db = ns.GetDB() end
    if not db or not db.reminderSoundEnabled then return end
    local sound = db.reminderSound or REMINDER_SOUND
    if sound then
        local numSound = tonumber(sound)
        if numSound then
            ns.DebugPrint("PlayReminderSound: Calling PlaySound for ID", numSound)
            local s, err = pcall(PlaySound, numSound, "Master")
            if not s then ns.DebugPrint("PlaySound crashed:", err) end
        elseif type(sound) == "string" then
            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
            if LSM then
                local path = LSM:Fetch("sound", sound)
                if path then
                    PlaySoundFile(path, "Master")
                end
            end
        end
    end
end
ns.PlayReminderSound = PlayReminderSound

----------------------------------------------------------------------
-- Play TTS
----------------------------------------------------------------------
local function PlayTTS(text)
    if not db then db = ns.GetDB() end
    if not db or not db.reminderTTSEnabled then return end
    
    local voiceName = db.reminderTTSVoice
    local voices = C_VoiceChat.GetTtsVoices()
    local voiceID = nil
    ns.DebugPrint("PlayTTS called with voiceName:", voiceName)
    
    if voices and #voices > 0 then
        -- Find by name
        if voiceName and voiceName ~= "" then
            for _, v in ipairs(voices) do
                if v.name == voiceName then
                    voiceID = v.voiceID
                    break
                end
            end
        end
        -- Default to first if not found
        if not voiceID then
            voiceID = voices[1].voiceID
            ns.DebugPrint("PlayTTS: voiceName not found, defaulting to", voices[1].name)
        end
    else
        ns.DebugPrint("PlayTTS error: C_VoiceChat.GetTtsVoices() is empty!")
    end
    
    if voiceID then
        ns.DebugPrint("PlayTTS speaking with voiceID:", voiceID)
        local destination = (Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback) or 0
        local success, err = pcall(C_VoiceChat.SpeakText, voiceID, text, destination, 0, 100)
        if not success then
            ns.DebugPrint("TTS API Error caught:", err)
        end
    end
end
ns.PlayTTS = PlayTTS

----------------------------------------------------------------------
-- Reminder frame creation
----------------------------------------------------------------------
local function CreateReminderFrame()
    if reminderFrame then return end
    ns.DebugPrint("Creating Reminder Frame...")

    reminderFrame = CreateFrame("Frame", "MiliUI_LustReminderFrame", UIParent)
    reminderFrame:SetSize(400, 60)
    reminderFrame:SetFrameStrata("HIGH")
    reminderFrame:SetFrameLevel(50)
    reminderFrame:SetMovable(true)
    reminderFrame:SetUserPlaced(false)
    reminderFrame:SetClampedToScreen(true)
    reminderFrame:Hide()

    -- Icon on left
    local iconBorder = CreateFrame("Frame", nil, reminderFrame, "BackdropTemplate")
    iconBorder:SetSize(42, 42)
    iconBorder:SetPoint("LEFT", reminderFrame, "LEFT", 0, 0)
    iconBorder:SetFrameLevel(reminderFrame:GetFrameLevel() + 1)
    iconBorder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    iconBorder:SetBackdropColor(0, 0, 0, 0.6)
    iconBorder:SetBackdropBorderColor(0, 0, 0, 1)

    reminderIcon = iconBorder:CreateTexture(nil, "ARTWORK")
    reminderIcon:SetPoint("TOPLEFT", iconBorder, "TOPLEFT", 1, -1)
    reminderIcon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -1, 1)
    reminderIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    reminderFrame.iconBorder = iconBorder

    -- Text (yellow, big, with shadow)
    reminderText = reminderFrame:CreateFontString(nil, "OVERLAY")
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if GetLocale() == "zhTW" then
        fontPath = "Fonts\\blei00d.TTF"
    elseif GetLocale() == "zhCN" then
        fontPath = "Fonts\\ARKai_T.ttf"
    elseif GetLocale() == "koKR" then
        fontPath = "Fonts\\2002.TTF"
    end
    reminderText:SetFont(fontPath, 28, "OUTLINE")
    reminderText:SetPoint("LEFT", iconBorder, "RIGHT", 10, 0)
    reminderText:SetTextColor(1, 1, 0)
    reminderText:SetShadowOffset(2, -2)
    reminderText:SetShadowColor(0, 0, 0, 0.8)

    -- EditMode selection highlight
    local editSelection = CreateFrame("Frame", nil, reminderFrame, "EditModeSystemSelectionTemplate")
    editSelection:SetAllPoints()
    editSelection:Hide()
    editSelection:RegisterForDrag("LeftButton")
    editSelection:SetScript("OnDragStart", function() reminderFrame:StartMoving() end)
    editSelection:SetScript("OnDragStop", function()
        reminderFrame:StopMovingOrSizing()
        reminderFrame:SetUserPlaced(false)
        -- Save absolute position (independent from bar)
        local cx, cy = UIParent:GetCenter()
        local fx, fy = reminderFrame:GetCenter()
        if db then
            db.reminderX = math.floor(fx - cx + 0.5)
            db.reminderY = math.floor(fy - cy + 0.5)
        end
    end)
    editSelection.system = {
        GetSystemName = function() return L["ADDON_TITLE_REMINDER"] or "Lust Reminder" end
    }
    reminderFrame.editSelection = editSelection

    -- Auto-hide timer
    reminderFrame.elapsed = 0
    reminderFrame:SetScript("OnUpdate", function(self, dt)
        -- Don't auto-hide in EditMode
        if isInEditMode then return end

        self.elapsed = self.elapsed + dt
        local duration = (db and db.reminderDuration) or DB_DEFAULTS.reminderDuration
        if self.elapsed >= duration then
            self:Hide()
            return
        end
        -- Dismiss early if lust debuff appeared
        if PlayerHasLustDebuff() then
            self:Hide()
            return
        end
    end)
end

----------------------------------------------------------------------
-- Position the reminder frame (absolute, independent from bar)
----------------------------------------------------------------------
local function UpdateReminderPosition()
    if not reminderFrame then return end
    -- Don't reposition if user is dragging in EditMode
    if isInEditMode and reminderFrame.unlocked then return end

    reminderFrame:ClearAllPoints()
    local rx = (db and db.reminderX) or DB_DEFAULTS.reminderX
    local ry = (db and db.reminderY) or DB_DEFAULTS.reminderY
    reminderFrame:SetPoint("CENTER", UIParent, "CENTER", rx, ry)
end
ns.UpdateReminderPosition = UpdateReminderPosition

----------------------------------------------------------------------
-- EditMode integration
----------------------------------------------------------------------
local function UpdateEditModeState(entering)
    isInEditMode = entering
    if not db then db = ns.GetDB() end
    ns.DebugPrint("UpdateEditModeState entering:", entering, "db.reminderEnabled:", db and db.reminderEnabled)

    CreateReminderFrame()

    if entering and db and db.reminderEnabled then
        if reminderIcon then
            reminderIcon:SetTexture(ns.DEFAULT_LUST_ICON)
        end
        reminderText:SetText(L["REMINDER_EDITMODE_TEXT"] or "Lust available!")
        reminderFrame.editSelection:ShowHighlighted()
        UpdateReminderPosition()
        reminderFrame.unlocked = true
        reminderFrame:Show()
    else
        if reminderFrame then
            reminderFrame.editSelection:Hide()
            reminderFrame.unlocked = false
            reminderFrame:Hide()
            ns.DebugPrint("EditMode Frame Hidden.")
        end
    end
end

local editModeHooked = false
local function HookReminderEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    ns.DebugPrint("LustReminder EditMode HOOKED successfully")

    EditModeManagerFrame:HookScript("OnShow", function()
        UpdateEditModeState(true)
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        UpdateEditModeState(false)
    end)

    -- Catch-up: if EditMode is already shown when we hook
    if EditModeManagerFrame:IsShown() then
        UpdateEditModeState(true)
    end
end

-- Tier 1: immediate
HookReminderEditMode()

-- Tier 2: delayed addon load
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", function()
        HookReminderEditMode()
    end)
end

-- Eagerly create reminder frame so EditMode can find it
CreateReminderFrame()

----------------------------------------------------------------------
-- Show the reminder alert
----------------------------------------------------------------------
local function ShowReminder()
    if not db then db = ns.GetDB() end
    if not db or not db.reminderEnabled then 
        ns.DebugPrint("ShowReminder aborted, reminderEnabled is false")
        return 
    end

    CreateReminderFrame()

    -- Determine spell name and icon
    local spellName, spellIcon = GetPlayerLustSpell()
    if not spellName then
        spellName = ns.DEFAULT_LUST_NAME
        spellIcon = ns.DEFAULT_LUST_ICON
    end

    local text = string.format(L["REMINDER_AVAILABLE"] or "%s可用！", spellName)
    if reminderIcon then
        reminderIcon:SetTexture(spellIcon)
    end
    reminderText:SetText(text)

    ns.DebugPrint("ShowReminder executing for:", spellName)

    -- Play sound and TTS
    PlayReminderSound()
    PlayTTS(text)

    UpdateReminderPosition()
    reminderFrame.elapsed = 0
    reminderFrame:Show()
    
    local l, b, w, h = reminderFrame:GetRect()
    ns.DebugPrint("Reminder shown successfully. Rect:", l, b, w, h, "Alpha:", reminderFrame:GetAlpha(), "IsShown:", reminderFrame:IsShown())
end
ns.ShowReminder = ShowReminder

----------------------------------------------------------------------
-- Event frame
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
local function StopWatchingDebuff()
    watchingDebuffExpiry = false
    eventFrame:UnregisterEvent("UNIT_AURA")
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        db = ns.GetDB()
        self:RegisterEvent("ENCOUNTER_START")
        self:RegisterEvent("ENCOUNTER_END")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("CHALLENGE_MODE_START")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        
        -- Tier 3: Final fallback hook at PLAYER_LOGIN
        HookReminderEditMode()
        CreateReminderFrame()

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not db then db = ns.GetDB() end
        local _, instanceType = IsInInstance()
        firstPullPending = (instanceType == "party")

    elseif event == "ENCOUNTER_START" then
        if not db or not db.reminderEnabled then return end
        if db.reminderLustClassOnly and not PlayerCanLust() then return end

        if PlayerHasLustDebuff() then
            if db.reminderDebuffExpiry then
                watchingDebuffExpiry = true
                self:RegisterEvent("UNIT_AURA")
            end
        else
            ShowReminder()
        end

    elseif event == "ENCOUNTER_END" then
        StopWatchingDebuff()

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit ~= "player" then return end
        if not watchingDebuffExpiry then return end
        if not PlayerHasLustDebuff() then
            StopWatchingDebuff()
            ShowReminder()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        local _, instanceType = IsInInstance()
        firstPullPending = (instanceType == "party")

    elseif event == "CHALLENGE_MODE_START" then
        firstPullPending = true

    elseif event == "PLAYER_REGEN_DISABLED" then
        if not firstPullPending then return end
        if not db or not db.reminderEnabled then return end
        if not db.reminderDungeonPull then return end
        firstPullPending = false
        if db.reminderLustClassOnly and not PlayerCanLust() then return end
        if not PlayerHasLustDebuff() then
            ShowReminder()
        end
    end
end)
