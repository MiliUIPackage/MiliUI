local addonName, ns = ...

----------------------------------------------------------------------
-- Imports from Config.lua
----------------------------------------------------------------------
local L                 = ns.L
local DB_DEFAULTS       = ns.DB_DEFAULTS
local LUST_DEBUFFS      = ns.LUST_DEBUFFS
local LUST_CLASS_SPELLS = ns.LUST_CLASS_SPELLS
local REMINDER_FONT     = ns.LOCALE_FONT

----------------------------------------------------------------------
-- Built-in reminder sound default
-- SoundKit IDs: 8959 Raid Warning | 8960 Ready Check | 8454 Level Up
--               8332 PvP Warning  | 7279 Alarm Clock | 8574 Dungeon Reward
----------------------------------------------------------------------
local REMINDER_SOUND_DEFAULT = 8959

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local db
local reminderFrame, reminderIcon, reminderText
local reminderShowing          = false
local reminderHideTimer        = nil
local watchingDebuffExpiry     = false
local watchedDebuffInstanceID  = nil
local firstPullPending         = false
local isInEditMode             = false

local eventFrame = CreateFrame("Frame")

-- UNIT_AURA is registered only while it's actually needed:
--   (a) waiting for lust debuff to drop (watchingDebuffExpiry), or
--   (b) reminder currently showing (auto-dismiss on recast).
local function UpdateAuraSubscription()
    if watchingDebuffExpiry or reminderShowing then
        eventFrame:RegisterEvent("UNIT_AURA")
    else
        eventFrame:UnregisterEvent("UNIT_AURA")
    end
end

----------------------------------------------------------------------
-- Lust capability detection
----------------------------------------------------------------------
local function PlayerCanLust()
    for _, entry in ipairs(LUST_CLASS_SPELLS) do
        if IsSpellKnown(entry.spellID) or IsSpellKnown(entry.spellID, true) then
            return true
        end
        if entry.altSpellID and (IsSpellKnown(entry.altSpellID) or IsSpellKnown(entry.altSpellID, true)) then
            return true
        end
    end
    -- Hunters class-wide (pet may not be summoned at detection time)
    local _, className = UnitClass("player")
    if className == "HUNTER" then return true end
    return false
end

local function GetPlayerLustSpell()
    local _, className = UnitClass("player")
    for _, entry in ipairs(LUST_CLASS_SPELLS) do
        if entry.classID == className then
            local name = C_Spell.GetSpellName(entry.spellID)
            local info = C_Spell.GetSpellInfo(entry.spellID)
            if name and info then return name, info.iconID end
            if entry.altSpellID then
                name = C_Spell.GetSpellName(entry.altSpellID)
                info = C_Spell.GetSpellInfo(entry.altSpellID)
                if name and info then return name, info.iconID end
            end
        end
    end
    return nil, nil
end

-- Returns (hasDebuff, auraInstanceID) so callers can snapshot the ID
-- for payload-filtered UNIT_AURA dismissal.
local function PlayerHasLustDebuff()
    for _, spellID in ipairs(LUST_DEBUFFS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then return true, aura.auraInstanceID end
    end
    return false
end

----------------------------------------------------------------------
-- Reminder sound
----------------------------------------------------------------------
local function PlayReminderSound()
    if not db then db = ns.GetDB() end
    if not db or not db.reminderSoundEnabled then return end

    local sound = db.reminderSound or REMINDER_SOUND_DEFAULT
    if not sound then return end

    local numSound = tonumber(sound)
    if numSound then
        PlaySound(numSound, "Master")
    elseif type(sound) == "string" then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local path = LSM:Fetch("sound", sound)
            if path then PlaySoundFile(path, "Master") end
        end
    end
end
ns.PlayReminderSound = PlayReminderSound

----------------------------------------------------------------------
-- Frame creation
----------------------------------------------------------------------
local function CreateReminderFrame()
    if reminderFrame then return end

    reminderFrame = CreateFrame("Frame", "MiliUI_LustReminderFrame", UIParent)
    reminderFrame:SetSize(400, 60)
    reminderFrame:SetFrameStrata("MEDIUM")
    reminderFrame:SetFrameLevel(10)
    reminderFrame:SetMovable(true)
    reminderFrame:SetUserPlaced(false)
    reminderFrame:SetClampedToScreen(true)
    reminderFrame:Hide()

    -- Icon + border
    local iconBorder = CreateFrame("Frame", nil, reminderFrame, "BackdropTemplate")
    iconBorder:SetSize(42, 42)
    iconBorder:SetPoint("LEFT", reminderFrame, "LEFT", 0, 0)
    iconBorder:SetFrameLevel(reminderFrame:GetFrameLevel() + 1)
    iconBorder:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    iconBorder:SetBackdropColor(0, 0, 0, 0.6)
    iconBorder:SetBackdropBorderColor(0, 0, 0, 1)

    reminderIcon = iconBorder:CreateTexture(nil, "ARTWORK")
    reminderIcon:SetPoint("TOPLEFT",     iconBorder, "TOPLEFT",      1, -1)
    reminderIcon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -1,  1)
    reminderIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    reminderFrame.iconBorder = iconBorder

    -- Text
    reminderText = reminderFrame:CreateFontString(nil, "OVERLAY")
    reminderText:SetFont(REMINDER_FONT, 28, "OUTLINE")
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
        local cx, cy = UIParent:GetCenter()
        local fx, fy = reminderFrame:GetCenter()
        if db then
            db.reminderX = math.floor(fx - cx + 0.5)
            db.reminderY = math.floor(fy - cy + 0.5)
        end
    end)
    editSelection.system = {
        GetSystemName = function() return L["ADDON_TITLE_REMINDER"] or "Lust Reminder" end,
    }
    reminderFrame.editSelection = editSelection

    -- Centralized cleanup: whatever hides the frame (timer, event, edit-mode
    -- exit, manual), state resets here. No per-frame OnUpdate polling.
    reminderFrame:SetScript("OnHide", function()
        if reminderShowing then
            reminderShowing = false
            if reminderHideTimer then
                reminderHideTimer:Cancel()
                reminderHideTimer = nil
            end
            UpdateAuraSubscription()
        end
    end)
end

local function UpdateReminderPosition()
    if not reminderFrame then return end
    if isInEditMode and reminderFrame.unlocked then return end

    reminderFrame:ClearAllPoints()
    local rx = (db and db.reminderX) or DB_DEFAULTS.reminderX
    local ry = (db and db.reminderY) or DB_DEFAULTS.reminderY
    reminderFrame:SetPoint("CENTER", UIParent, "CENTER", rx, ry)
end
ns.UpdateReminderPosition = UpdateReminderPosition

----------------------------------------------------------------------
-- EditMode
----------------------------------------------------------------------
local function UpdateEditModeState(entering)
    isInEditMode = entering
    if not db then db = ns.GetDB() end
    CreateReminderFrame()

    if entering and db and db.reminderEnabled then
        if reminderIcon then reminderIcon:SetTexture(ns.DEFAULT_LUST_ICON) end
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
        end
    end
end

local editModeHooked = false
local function HookReminderEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true

    EditModeManagerFrame:HookScript("OnShow", function() UpdateEditModeState(true)  end)
    EditModeManagerFrame:HookScript("OnHide", function() UpdateEditModeState(false) end)

    if EditModeManagerFrame:IsShown() then UpdateEditModeState(true) end
end

HookReminderEditMode()  -- Tier 1
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookReminderEditMode)  -- Tier 2
end
CreateReminderFrame()

----------------------------------------------------------------------
-- Show reminder
----------------------------------------------------------------------
local function ShowReminder()
    if not db then db = ns.GetDB() end
    if not db or not db.reminderEnabled then return end

    CreateReminderFrame()

    local spellName, spellIcon = GetPlayerLustSpell()
    if not spellName then
        spellName = ns.DEFAULT_LUST_NAME
        spellIcon = ns.DEFAULT_LUST_ICON
    end

    local text = string.format(L["REMINDER_AVAILABLE"] or "%s可用！", spellName)
    if reminderIcon then reminderIcon:SetTexture(spellIcon) end
    reminderText:SetText(text)

    PlayReminderSound()
    UpdateReminderPosition()

    reminderShowing = true
    UpdateAuraSubscription()

    local duration = (db and db.reminderDuration) or DB_DEFAULTS.reminderDuration
    if reminderHideTimer then reminderHideTimer:Cancel() end
    reminderHideTimer = C_Timer.NewTimer(duration, function()
        if reminderFrame then reminderFrame:Hide() end  -- OnHide handles cleanup
    end)

    reminderFrame:Show()
end
ns.ShowReminder = ShowReminder

local function StopWatchingDebuff()
    watchingDebuffExpiry    = false
    watchedDebuffInstanceID = nil
    UpdateAuraSubscription()
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        db = ns.GetDB()
        self:RegisterEvent("ENCOUNTER_START")
        self:RegisterEvent("ENCOUNTER_END")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("CHALLENGE_MODE_START")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")

        HookReminderEditMode()  -- Tier 3
        CreateReminderFrame()

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not db then db = ns.GetDB() end
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

    elseif event == "ENCOUNTER_START" then
        if not db or not db.reminderEnabled then return end
        if db.reminderLustClassOnly and not PlayerCanLust() then return end

        local hasDebuff, instID = PlayerHasLustDebuff()
        if hasDebuff then
            if db.reminderDebuffExpiry then
                watchingDebuffExpiry    = true
                watchedDebuffInstanceID = instID
                UpdateAuraSubscription()
            end
        else
            ShowReminder()
        end

    elseif event == "ENCOUNTER_END" then
        StopWatchingDebuff()

    elseif event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if unit ~= "player" then return end

        -- Payload-filter fast path. In 12.0 the `spellId` on `addedAuras`
        -- entries may be "secret" (can't index a table with it), so we can
        -- only answer "was anything added?" cheaply. That still skips the
        -- bulk of combat events, which are pure stack/refresh updates.
        local shouldScan = true
        if updateInfo and not updateInfo.isFullUpdate then
            shouldScan = false
            if watchedDebuffInstanceID and updateInfo.removedAuraInstanceIDs then
                for _, id in ipairs(updateInfo.removedAuraInstanceIDs) do
                    if id == watchedDebuffInstanceID then
                        shouldScan = true
                        break
                    end
                end
            end
            if not shouldScan and reminderShowing
               and updateInfo.addedAuras and #updateInfo.addedAuras > 0 then
                shouldScan = true
            end
        end
        if not shouldScan then return end

        local hasDebuff = PlayerHasLustDebuff()

        if watchingDebuffExpiry and not hasDebuff then
            StopWatchingDebuff()
            ShowReminder()
            return
        end

        if reminderShowing and hasDebuff then
            reminderFrame:Hide()  -- OnHide cleans up reminderShowing + timer + subscription
        end
    end
end)
