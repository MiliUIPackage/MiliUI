local addonName, ns = ...

-- Spell IDs (verify in-game if needed)
local COLLAPSING_STAR = 1221150
local VOID_META_BUFF = 1217607
local VOID_RAY = 473728
local DARKNESS = 196718
-- Void Metamorphosis activation spell (the cast you press), distinct from
-- VOID_META_BUFF (the aura applied while transformed). 1217605 is the best-guess
-- activation id from research; VERIFY in-game via /vc debug (cast it, read
-- "CAST spellID=") and correct if needed.
local VOID_META = 1217605
-- Fallback-only (used only if IsSpellUsable does not track the soul threshold):
-- the VM resource aura whose stack count is the banked soul total, and the
-- activation threshold (35 with the Soul Glutton talent, not auto-detected).
local SOUL_RESOURCE_AURA = 1225789
local SOUL_THRESHOLD = 50

local ADDON_COLOR = "|cff8866cc"
local ICON_PATH = "Interface\\Icons\\inv_12_dh_void_ability_collapsingstar"

local SCALE_KEYS = { [1] = "minor", [2] = "major", [3] = "pyke", [4] = "counting", [5] = "custom" }
local SCALE_LABELS = {
    minor = "小調 (黑暗)",
    major = "大調 (明亮)",
    pyke = "Pyke (灰燼騎士)",
    counting = "報數 (語音)",
    custom = "自訂 (你的音符)",
}

local CUSTOM_MAX = 8

local FALL_OFF_KEYS = { [1] = "off", [2] = "sounds_off", [3] = "minor", [4] = "major", [5] = "voice", [6] = "custom" }
local FALL_OFF_LABELS = {
    off = "關閉",
    sounds_off = "電源關閉",
    minor = "小調和弦",
    major = "大調和弦",
    voice = "語音",
    custom = "自訂\226\128\166",
}

local FALL_OFF_FILES = {
    sounds_off = "Interface\\AddOns\\VoidChimes\\sounds\\fall_off\\sounds_off.mp3",
    minor = "Interface\\AddOns\\VoidChimes\\sounds\\fall_off\\minor.mp3",
    major = "Interface\\AddOns\\VoidChimes\\sounds\\fall_off\\major.mp3",
}

local VOID_RAY_READY_KEYS = { [1] = "off", [2] = "ping", [3] = "chime", [4] = "tone", [5] = "voice", [6] = "custom" }
local VOID_RAY_READY_LABELS = {
    off = "關閉",
    ping = "電子提示音",
    chime = "鐘聲 (明亮)",
    tone = "音調 (黑暗)",
    voice = "語音",
    custom = "自訂\226\128\166",
}

local VOID_RAY_READY_FILES = {
    ping = "Interface\\AddOns\\VoidChimes\\sounds\\void_ray_ready\\ping.mp3",
    chime = "Interface\\AddOns\\VoidChimes\\sounds\\void_ray_ready\\chime.mp3",
    tone = "Interface\\AddOns\\VoidChimes\\sounds\\void_ray_ready\\tone.mp3",
}

local DARKNESS_KEYS = { [1] = "off", [2] = "nocturne", [3] = "minor", [4] = "major", [5] = "voice", [6] = "custom" }
local DARKNESS_LABELS = {
    off = "關閉",
    nocturne = "夜曲 (黑暗)",
    minor = "小調鐘聲 (黑暗)",
    major = "大調鐘聲 (明亮)",
    voice = "語音",
    custom = "自訂\226\128\166",
}

local DARKNESS_FILES = {
    nocturne = "Interface\\AddOns\\VoidChimes\\sounds\\darkness\\nocturne.mp3",
    minor = "Interface\\AddOns\\VoidChimes\\sounds\\darkness\\minor.mp3",
    major = "Interface\\AddOns\\VoidChimes\\sounds\\darkness\\major.mp3",
}

local VOID_META_READY_KEYS = { [1] = "off", [2] = "surge", [3] = "dark", [4] = "bright", [5] = "voice", [6] = "custom" }
local VOID_META_READY_LABELS = {
    off = "關閉",
    surge = "能量湧動",
    dark = "黑暗漸強",
    bright = "明亮漸強",
    voice = "語音",
    custom = "自訂\226\128\166",
}

local VOID_META_READY_FILES = {
    surge = "Interface\\AddOns\\VoidChimes\\sounds\\void_meta_ready\\surge.mp3",
    dark = "Interface\\AddOns\\VoidChimes\\sounds\\void_meta_ready\\dark.mp3",
    bright = "Interface\\AddOns\\VoidChimes\\sounds\\void_meta_ready\\bright.mp3",
}

-- Output channel for file-based cues. Exposed because some users route the
-- addon's sounds to a channel they can volume-control (or keep audible) apart
-- from general SFX. Values are the SoundChannel enum strings PlaySoundFile
-- accepts. TTS options (Counting / Voice) use the game's text-to-speech volume
-- and are unaffected by this.
local SOUND_CHANNEL_KEYS = { [1] = "Master", [2] = "SFX", [3] = "Music", [4] = "Ambience", [5] = "Dialog" }
local SOUND_CHANNEL_LABELS = {
    Master = "主音量",
    SFX = "音效",
    Music = "音樂",
    Ambience = "環境音效",
    Dialog = "對話",
}

local SCALES = {
    minor = {
        "Interface\\AddOns\\VoidChimes\\sounds\\minor\\note_1.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\minor\\note_2.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\minor\\note_3.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\minor\\note_4.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\minor\\note_5.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\minor\\note_6.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\minor\\note_7.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\minor\\note_8.mp3",
    },
    major = {
        "Interface\\AddOns\\VoidChimes\\sounds\\major\\note_1.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\major\\note_2.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\major\\note_3.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\major\\note_4.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\major\\note_5.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\major\\note_6.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\major\\note_7.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\major\\note_8.mp3",
    },
    pyke = {
        "Interface\\AddOns\\VoidChimes\\sounds\\pyke\\note_1.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\pyke\\note_2.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\pyke\\note_3.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\pyke\\note_4.mp3",
        "Interface\\AddOns\\VoidChimes\\sounds\\pyke\\note_5.mp3",
    },
}

-- LibSharedMedia lets users pick any sound registered by any addon (including
-- their own files dropped into WeakAuras / SharedMediaAdditional). We expose it
-- behind the "Custom…" cue option and the Custom theme builder. The handle is
-- optional: if LSM somehow isn't present those features simply offer nothing.
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local LSM_PREFIX = "Void Chimes: "

-- Contribute our bundled cues and notes to the shared registry, so they lead the
-- Custom pickers and any other LSM-aware addon can reuse them. LSM only accepts
-- sound paths under Interface\ ending in .ogg/.mp3 — ours qualify.
local function RegisterBundledMedia()
    if not LSM then return end
    LSM:Register("sound", LSM_PREFIX .. "Powering Down", FALL_OFF_FILES.sounds_off)
    LSM:Register("sound", LSM_PREFIX .. "Minor Chord", FALL_OFF_FILES.minor)
    LSM:Register("sound", LSM_PREFIX .. "Major Chord", FALL_OFF_FILES.major)
    LSM:Register("sound", LSM_PREFIX .. "Synthetic Ping", VOID_RAY_READY_FILES.ping)
    LSM:Register("sound", LSM_PREFIX .. "Chime", VOID_RAY_READY_FILES.chime)
    LSM:Register("sound", LSM_PREFIX .. "Tone", VOID_RAY_READY_FILES.tone)
    LSM:Register("sound", LSM_PREFIX .. "Darkness (Nocturne)", DARKNESS_FILES.nocturne)
    LSM:Register("sound", LSM_PREFIX .. "Darkness (Dark Chime)", DARKNESS_FILES.minor)
    LSM:Register("sound", LSM_PREFIX .. "Darkness (Bright Chime)", DARKNESS_FILES.major)
    LSM:Register("sound", LSM_PREFIX .. "Void Meta (Surge)", VOID_META_READY_FILES.surge)
    LSM:Register("sound", LSM_PREFIX .. "Void Meta (Dark)", VOID_META_READY_FILES.dark)
    LSM:Register("sound", LSM_PREFIX .. "Void Meta (Bright)", VOID_META_READY_FILES.bright)
    for i, path in ipairs(SCALES.minor) do LSM:Register("sound", LSM_PREFIX .. "Minor Note " .. i, path) end
    for i, path in ipairs(SCALES.major) do LSM:Register("sound", LSM_PREFIX .. "Major Note " .. i, path) end
    for i, path in ipairs(SCALES.pyke) do LSM:Register("sound", LSM_PREFIX .. "Pyke Note " .. i, path) end
end
RegisterBundledMedia()

-- Registered LSM sound names, our own entries first (so the addon's sounds lead
-- the Custom pickers), then the rest alphabetically. Read live so newly
-- registered sounds appear whenever a dropdown is built.
local function SortedLSMSounds()
    local out = {}
    if not LSM then return out end
    -- Only path-backed sounds. LSM bootstraps a "None" entry whose value is the
    -- integer 1 (a silence sentinel), and other addons may register non-path
    -- values; those would resolve to a bogus fileDataID via PlaySoundFile.
    for name, value in pairs(LSM:HashTable("sound")) do
        if type(value) == "string" then
            out[#out + 1] = name
        end
    end
    table.sort(out, function(a, b)
        local aOurs = a:sub(1, #LSM_PREFIX) == LSM_PREFIX
        local bOurs = b:sub(1, #LSM_PREFIX) == LSM_PREFIX
        if aOurs ~= bOurs then return aOurs end
        return a:lower() < b:lower()
    end)
    return out
end

-- TTS-driven themes: each entry is the list of phrases spoken in order.
local TTS_PHRASES = {
    counting = { "one", "two", "three", "four", "five", "six", "seven", "eight" },
}

-- Spacing between clips when previewing via /vc test. Pyke clips are several
-- seconds long, so they need a wider gap than the short minor/major notes.
local TEST_SPACING = {
    minor = 0.4,
    major = 0.4,
    pyke = 4.7,
    counting = 0.7,
    custom = 0.5,
}

local db

local function SoundChannel()
    return (db and db.soundChannel) or "SFX"
end

-- Resolve an LSM sound name to a playable path. noDefault=true so an unset or
-- uninstalled sound resolves to nil and is simply skipped.
local function CustomSoundFile(name)
    if not LSM or not name or name == "" then return nil end
    local path = LSM:Fetch("sound", name, true)
    return type(path) == "string" and path or nil
end

-- The Custom theme is an ordered list of LSM sound names (db.customTheme), built
-- in the Advanced panel. Skip any empty/placeholder entries so the melody is just
-- the filled notes in order.
local function CustomThemeList()
    local out = {}
    if not db or not db.customTheme then return out end
    for _, name in ipairs(db.customTheme) do
        if name and name ~= "" then
            out[#out + 1] = name
        end
    end
    return out
end

local function IsValidTheme(theme)
    return SCALES[theme] ~= nil or TTS_PHRASES[theme] ~= nil or theme == "custom"
end

local function ThemeLength(theme)
    if SCALES[theme] then return #SCALES[theme] end
    if TTS_PHRASES[theme] then return #TTS_PHRASES[theme] end
    if theme == "custom" then return #CustomThemeList() end
    return 0
end

local function PlayNote(theme, index)
    if SCALES[theme] then
        PlaySoundFile(SCALES[theme][index], SoundChannel())
    elseif TTS_PHRASES[theme] then
        local voiceID = (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
        C_VoiceChat.SpeakText(voiceID, TTS_PHRASES[theme][index], 0, 100, false)
    elseif theme == "custom" then
        local file = CustomSoundFile(CustomThemeList()[index])
        if file then
            PlaySoundFile(file, SoundChannel())
        end
    end
end

local wasInMeta = false
local debugMode = false
local auraSeen = {}
local settingsCategory
local voidRayWasReady = false
-- True while Void Ray is mid-cast. Void Ray has a cast time, so Fury can swing
-- across 100 during the cast (spent at cast start, regen mid-cast); without this
-- the ready cue would replay the instant Fury bumps back over 100 even though
-- you're still casting. We swallow the cue for the whole cast window — the latch
-- still updates, so once the cast ends there's no stale edge waiting to fire.
local voidRayCasting = false
-- Void Metamorphosis is soul-threshold gated (not a cooldown), so readiness is
-- just "is the activation spell usable, and we're not already transformed".
-- voidMetaLastFired debounces the cue: IsSpellUsable for an off-GCD spell dips
-- false during any other GCD, so souls parked at threshold through a rotation
-- would otherwise re-fire every ~1.5s. The latch still updates every check; only
-- the sound is gated.
local voidMetaWasReady = false
local voidMetaLastFired = 0
local VOID_META_REARM = 2.0

local function PlayFallOffSound()
    if not db then return end
    local key = db.fallOffSound or "off"
    if key == "off" then return end
    if key == "voice" then
        local voiceID = (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
        C_VoiceChat.SpeakText(voiceID, "void ends", 0, 100, false)
        return
    end
    local file = (key == "custom") and CustomSoundFile(db.fallOffCustom) or FALL_OFF_FILES[key]
    if file then
        PlaySoundFile(file, SoundChannel())
    end
end

local function PlayVoidRayReadySound()
    if not db then return end
    local key = db.voidRayReadySound or "off"
    if key == "off" then return end
    if key == "voice" then
        local voiceID = (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
        C_VoiceChat.SpeakText(voiceID, "Void Ray", 0, 100, false)
        return
    end
    local file = (key == "custom") and CustomSoundFile(db.voidRayReadyCustom) or VOID_RAY_READY_FILES[key]
    if file then
        PlaySoundFile(file, SoundChannel())
    end
end

local function PlayDarknessSound()
    if not db then return end
    local key = db.darknessSound or "off"
    if key == "off" then return end
    if key == "voice" then
        local voiceID = (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
        C_VoiceChat.SpeakText(voiceID, "Darkness", 0, 100, false)
        return
    end
    local file = (key == "custom") and CustomSoundFile(db.darknessCustom) or DARKNESS_FILES[key]
    if file then
        PlaySoundFile(file, SoundChannel())
    end
end

local function PlayVoidMetaReadySound()
    if not db then return end
    local key = db.voidMetaReadySound or "off"
    if key == "off" then return end
    if key == "voice" then
        local voiceID = (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
        C_VoiceChat.SpeakText(voiceID, "Metamorphosis", 0, 100, false)
        return
    end
    local file = (key == "custom") and CustomSoundFile(db.voidMetaReadyCustom) or VOID_META_READY_FILES[key]
    if file then
        PlaySoundFile(file, SoundChannel())
    end
end

local function PreviewTheme()
    local len = ThemeLength(db.scale)
    if len == 0 then
        print(ADDON_COLOR .. "Void Chimes|r " .. SCALE_LABELS[db.scale] .. " 尚未設定任何音符 — 請至「進階」面板新增。")
        return
    end
    local spacing = TEST_SPACING[db.scale] or 0.4
    print(ADDON_COLOR .. "Void Chimes|r 正在播放 " .. SCALE_LABELS[db.scale] .. " 主題…")
    for i = 1, len do
        C_Timer.After((i - 1) * spacing, function()
            PlayNote(db.scale, i)
        end)
    end
end

-- Plays the Custom theme regardless of which theme is selected, so users can
-- audition the slots while building them.
local function PreviewCustomTheme()
    local len = ThemeLength("custom")
    if len == 0 then
        print(ADDON_COLOR .. "Void Chimes|r 自訂主題是空的 — 請在音符欄位中挑選聲音。")
        return
    end
    print(ADDON_COLOR .. "Void Chimes|r 正在播放自訂主題…")
    local spacing = TEST_SPACING.custom or 0.5
    for i = 1, len do
        C_Timer.After((i - 1) * spacing, function()
            PlayNote("custom", i)
        end)
    end
end

local function PreviewFallOff()
    local key = db.fallOffSound or "off"
    print(ADDON_COLOR .. "Void Chimes|r 結束音效：|cffffffff" .. FALL_OFF_LABELS[key] .. "|r")
    if key == "off" then
        print("  請改選其他選項以試聽。")
        return
    end
    if key == "custom" and not CustomSoundFile(db.fallOffCustom) then
        print("  請在「自訂結束音效」中挑選聲音以試聽。")
        return
    end
    PlayFallOffSound()
end

local function PreviewVoidRayReady()
    local key = db.voidRayReadySound or "off"
    print(ADDON_COLOR .. "Void Chimes|r 虛無射線音效：|cffffffff" .. VOID_RAY_READY_LABELS[key] .. "|r")
    if key == "off" then
        print("  請改選其他選項以試聽。")
        return
    end
    if key == "voice" then
        PlayVoidRayReadySound()
        return
    end
    if key == "custom" and not CustomSoundFile(db.voidRayReadyCustom) then
        print("  請在「自訂虛無射線音效」中挑選聲音以試聽。")
        return
    end
    local file = (key == "custom") and CustomSoundFile(db.voidRayReadyCustom) or VOID_RAY_READY_FILES[key]
    if not file then return end
    local willPlay = PlaySoundFile(file, SoundChannel())
    if not willPlay then
        print("  |cffff8800找不到音效檔|r — 請將檔案放到 " .. tostring(file) .. " 以啟用。")
    end
end

local function PreviewDarkness()
    local key = db.darknessSound or "off"
    print(ADDON_COLOR .. "Void Chimes|r 黑暗音效：|cffffffff" .. DARKNESS_LABELS[key] .. "|r")
    if key == "off" then
        print("  請改選其他選項以試聽。")
        return
    end
    if key == "voice" then
        PlayDarknessSound()
        return
    end
    if key == "custom" and not CustomSoundFile(db.darknessCustom) then
        print("  請在「自訂黑暗音效」中挑選聲音以試聽。")
        return
    end
    local file = (key == "custom") and CustomSoundFile(db.darknessCustom) or DARKNESS_FILES[key]
    if not file then return end
    local willPlay = PlaySoundFile(file, SoundChannel())
    if not willPlay then
        print("  |cffff8800找不到音效檔|r — 請將檔案放到 " .. tostring(file) .. " 以啟用。")
    end
end

local function PreviewVoidMetaReady()
    local key = db.voidMetaReadySound or "off"
    print(ADDON_COLOR .. "Void Chimes|r 虛無惡魔化身音效：|cffffffff" .. VOID_META_READY_LABELS[key] .. "|r")
    if key == "off" then
        print("  請改選其他選項以試聽。")
        return
    end
    if key == "voice" then
        PlayVoidMetaReadySound()
        return
    end
    if key == "custom" and not CustomSoundFile(db.voidMetaReadyCustom) then
        print("  請在「自訂虛無惡魔化身音效」中挑選聲音以試聽。")
        return
    end
    local file = (key == "custom") and CustomSoundFile(db.voidMetaReadyCustom) or VOID_META_READY_FILES[key]
    if not file then return end
    local willPlay = PlaySoundFile(file, SoundChannel())
    if not willPlay then
        print("  |cffff8800找不到音效檔|r — 請將檔案放到 " .. tostring(file) .. " 以啟用。")
    end
end

---------------------------------------------------------------------------
-- Ready-cue triggers
--
-- The Midnight (12.0) constraint: cooldown remaining/total/start are SECRET
-- values for spells modified by combat-fairness auras (Void Metamorphosis on
-- Void Ray). Arithmetic or comparison taints. SPELL_UPDATE_USABLE doesn't fire
-- on natural CD expiry for them. DurationObject:IsZero() is also secret in
-- combat. We cannot read the duration and we cannot poll.
--
-- The one production-blessed workaround (used by ArcUI, CDFlow, JustAC,
-- TellMeWhen, Plumber and others — see project_secret_cooldown_widget_trick
-- memory): feed C_Spell.GetSpellCooldownDuration through a hidden
-- CooldownFrameTemplate via SetCooldownFromDurationObject. The C engine
-- evaluates the secret timer internally, animates the (invisible) widget, and
-- fires OnCooldownDone at real expiry — no Lua-side read or compare. The
-- widget's :IsShown() is also NeverSecret, giving us a live "is on CD" boolean.
--
-- Composite ready predicate covers both Void Ray triggers in one expression:
--   nowReady = (not cdFrame:IsShown()) AND C_Spell.IsSpellUsable(VOID_RAY)
-- · Outside VM: cdFrame is never shown (no CD); IsSpellUsable flips on
--   Fury 100. nowReady tracks IsSpellUsable directly.
-- · Inside VM: IsSpellUsable is true (cost waived); nowReady tracks
--   cdFrame visibility — flips when OnCooldownDone fires.
---------------------------------------------------------------------------

local function CreateShadowCooldown()
    local f = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
    f:SetSize(1, 1)
    f:SetPoint("CENTER")
    f:SetAlpha(0)
    f:SetDrawSwipe(false)
    f:SetDrawBling(false)
    f:SetDrawEdge(false)
    return f
end

local voidRayCDFrame = CreateShadowCooldown()

-- Refresh the widget from the engine's current view of the spell's cooldown.
-- C_Spell.GetSpellCooldownDuration is 12.0-new and returns a DurationObject
-- (opaque/secret in combat but flows through SetCooldownFromDurationObject
-- unchanged). pcall guards the known TipTac-style taint edge case; on failure
-- the cue just won't fire this cycle.
--
-- GetSpellCooldownDuration includes the GCD by default, so a spell that's only
-- on the global cooldown (after any unrelated cast) would light up the widget
-- and fire a phantom OnCooldownDone ~1.5s later. Gate on the cooldown struct's
-- isOnGCD/isActive booleans — both NeverSecret — exactly as Blizzard's own
-- Cooldown Manager, ArcUI, and CDFlow do. Only the secret startTime/duration
-- fields are off-limits; we never read those.
local function RefreshCooldown(spellID, frame)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info or not info.isActive or info.isOnGCD then
        frame:Clear()
        return
    end
    local durObj = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(spellID)
    if not durObj then
        frame:Clear()
        return
    end
    pcall(frame.SetCooldownFromDurationObject, frame, durObj, true)
end

local function RefreshAllCooldowns()
    RefreshCooldown(VOID_RAY, voidRayCDFrame)
end

local function CheckVoidRayReady()
    local cdActive = voidRayCDFrame:IsShown()
    local isUsable = C_Spell.IsSpellUsable(VOID_RAY) and true or false
    local nowReady = (not cdActive) and isUsable
    if voidRayWasReady ~= nowReady then
        if debugMode then
            print(string.format("%sVoidChimes debug|r VOID_RAY %s (cd=%s usable=%s casting=%s)",
                ADDON_COLOR, nowReady and "READY" or "not-ready",
                cdActive and "active" or "none", tostring(isUsable),
                tostring(voidRayCasting)))
        end
        -- Swallow the cue while Void Ray is mid-cast: a Fury swing back over 100
        -- during the cast isn't a fresh "ready" worth announcing.
        if not voidRayWasReady and nowReady and not voidRayCasting then
            PlayVoidRayReadySound()
        end
    end
    voidRayWasReady = nowReady
end

voidRayCDFrame:SetScript("OnCooldownDone", function()
    if debugMode then print(ADDON_COLOR .. "Void Chimes debug|r VOID_RAY OnCooldownDone") end
    CheckVoidRayReady()
end)

-- Void Metamorphosis readiness. No cooldown to track (it's soul-threshold gated),
-- so this is just spell-usability edge detection — no shadow CooldownFrame. We
-- read only the IsSpellUsable boolean (NeverSecret), never the soul count, so
-- this is safe in restricted instances. Suppressed while already transformed.
local function CheckVoidMetaReady()
    local isUsable = C_Spell.IsSpellUsable(VOID_META) and true or false
    local nowReady = isUsable and not wasInMeta
    if voidMetaWasReady ~= nowReady then
        if debugMode then
            print(string.format("%sVoidChimes debug|r VOID_META %s (usable=%s inMeta=%s)",
                ADDON_COLOR, nowReady and "READY" or "not-ready",
                tostring(isUsable), tostring(wasInMeta)))
        end
        -- Debounce the sound: IsSpellUsable dips false during any GCD, so without
        -- this the cue would replay every ~1.5s while souls sit at threshold.
        if not voidMetaWasReady and nowReady and (GetTime() - voidMetaLastFired) >= VOID_META_REARM then
            voidMetaLastFired = GetTime()
            PlayVoidMetaReadySound()
        end
    end
    voidMetaWasReady = nowReady
end

---------------------------------------------------------------------------
-- Debug helpers (active only when debugMode is on; see /vc debug)
---------------------------------------------------------------------------
local function LogAura(label, spellID, name, stacks)
    local s = string.format("[VC dbg] AURA %-9s  id=%s  name=%s",
        label, tostring(spellID or "?"), tostring(name or "?"))
    if stacks and stacks > 0 then
        s = s .. "  stacks=" .. tostring(stacks)
    end
    print(s)
end

local function HandleDebugAuraUpdate(unit, updateInfo)
    if not updateInfo then return end
    if updateInfo.isFullUpdate then
        print("[VC dbg] AURA full-update (no diff)")
        return
    end
    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            auraSeen[aura.auraInstanceID] = { spellID = aura.spellId, name = aura.name }
            LogAura("APPLIED", aura.spellId, aura.name, aura.applications)
        end
    end
    if updateInfo.updatedAuraInstanceIDs then
        for _, id in ipairs(updateInfo.updatedAuraInstanceIDs) do
            local a = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
            if a then
                auraSeen[id] = { spellID = a.spellId, name = a.name }
                LogAura("REFRESHED", a.spellId, a.name, a.applications)
            end
        end
    end
    if updateInfo.removedAuraInstanceIDs then
        for _, id in ipairs(updateInfo.removedAuraInstanceIDs) do
            local seen = auraSeen[id]
            if seen then
                LogAura("REMOVED", seen.spellID, seen.name)
                auraSeen[id] = nil
            else
                print(string.format("[VC dbg] AURA REMOVED    instanceID=%s  (pre-debug)", tostring(id)))
            end
        end
    end
end

local DB_DEFAULTS = {
    scale = "minor",
    scaleIndex = 1,
    enabled = true,
    showCounter = true,
    counterOnlyInMeta = false,
    showMinimapButton = true,
    minimap = { hide = false },
    counterPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 200 },
    counterShowBorder = true,
    counterShowBackground = true,
    counterScale = 1.0,
    counterPreview = false,
    counterTextColor = "ffb380ff",
    counterTextAlpha = 1.0,
    counterTextOutline = false,
    counterShowIcon = false,
    counterIconRight = false,
    counterBgColor = "ff1a0d26",
    counterBgAlpha = 0.8,
    counterBorderColor = "ff804dcc",
    counterBorderAlpha = 0.9,
    counterResetOnMetaEnd = false,
    showVmTimer = true,
    vmTimerPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 160 },
    vmTimerShowBorder = true,
    vmTimerShowBackground = true,
    vmTimerScale = 1.0,
    vmTimerTextColor = "ffb380ff",
    vmTimerTextAlpha = 1.0,
    vmTimerTextOutline = false,
    vmTimerBgColor = "ff1a0d26",
    vmTimerBgAlpha = 0.8,
    vmTimerBorderColor = "ff804dcc",
    vmTimerBorderAlpha = 0.9,
    vmTimerShowIcon = false,
    vmTimerIconRight = false,
    linkAppearance = false,
    fallOffSound = "off",
    fallOffSoundIndex = 1,
    fallOffCustom = "",
    voidRayReadySound = "off",
    voidRayReadySoundIndex = 1,
    voidRayReadyCustom = "",
    darknessSound = "off",
    darknessSoundIndex = 1,
    darknessCustom = "",
    voidMetaReadySound = "off",
    voidMetaReadySoundIndex = 1,
    voidMetaReadyCustom = "",
    soundChannel = "SFX",
    soundChannelIndex = 2,
    customTheme = {},
}

local COUNTER_PREVIEW_VALUE = 5

local function InitDB()
    VoidChimesDB = VoidChimesDB or {}
    db = VoidChimesDB
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
    if not IsValidTheme(db.scale) then
        db.scale = "minor"
        db.scaleIndex = 1
    end
    if not FALL_OFF_LABELS[db.fallOffSound] then
        db.fallOffSound = "off"
        db.fallOffSoundIndex = 1
    end
    if not VOID_RAY_READY_LABELS[db.voidRayReadySound] then
        db.voidRayReadySound = "off"
        db.voidRayReadySoundIndex = 1
    end
    if not DARKNESS_LABELS[db.darknessSound] then
        db.darknessSound = "off"
        db.darknessSoundIndex = 1
    end
    if not VOID_META_READY_LABELS[db.voidMetaReadySound] then
        db.voidMetaReadySound = "off"
        db.voidMetaReadySoundIndex = 1
    end
    if not SOUND_CHANNEL_LABELS[db.soundChannel] then
        db.soundChannel = "SFX"
        db.soundChannelIndex = 2
    end
end

local function GetVersion()
    return C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
end

local function ScaleIndexFor(key)
    for i, k in ipairs(SCALE_KEYS) do
        if k == key then return i end
    end
    return 1
end

---------------------------------------------------------------------------
-- Star counter frame (visible during Void Metamorphosis)
---------------------------------------------------------------------------
local starCount = 0
local counterFrame = CreateFrame("Frame", "VoidChimesCounter", UIParent, "BackdropTemplate")
counterFrame:SetSize(40, 36)
counterFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
counterFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
counterFrame:SetBackdropColor(0.1, 0.05, 0.15, 0.8)
counterFrame:SetBackdropBorderColor(0.5, 0.3, 0.8, 0.9)
counterFrame:SetMovable(true)
counterFrame:EnableMouse(true)
counterFrame:RegisterForDrag("LeftButton")
counterFrame:SetScript("OnDragStart", counterFrame.StartMoving)
counterFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if db then
        db.counterPos = { point = point, relPoint = relPoint, x = x, y = y }
    end
end)
counterFrame:SetClampedToScreen(true)
counterFrame:Hide()

local counterIcon = counterFrame:CreateTexture(nil, "ARTWORK")
counterIcon:SetSize(24, 24)
counterIcon:SetTexture(ICON_PATH)
counterIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
counterIcon:Hide()

local counterText = counterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
counterText:SetPoint("CENTER")

---------------------------------------------------------------------------
-- Void Metamorphosis elapsed timer
--
-- A sibling readout that counts up while VM is active. It shares the star
-- counter's appearance settings (styled together in ApplyCounterAppearance /
-- ApplyCounterText) but keeps its own position and show toggle. Elapsed-only:
-- we stamp GetTime() at VM entry and tick the difference, so we never read the
-- aura's duration/expiration (those are secret/tainted in 12.0 combat).
---------------------------------------------------------------------------
local VM_TIMER_PREVIEW_VALUE = 23
local vmStartTime = nil

local vmTimerFrame = CreateFrame("Frame", "VoidChimesVMTimer", UIParent, "BackdropTemplate")
vmTimerFrame:SetSize(56, 36)
vmTimerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
vmTimerFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
vmTimerFrame:SetBackdropColor(0.1, 0.05, 0.15, 0.8)
vmTimerFrame:SetBackdropBorderColor(0.5, 0.3, 0.8, 0.9)
vmTimerFrame:SetMovable(true)
vmTimerFrame:EnableMouse(true)
vmTimerFrame:RegisterForDrag("LeftButton")
vmTimerFrame:SetScript("OnDragStart", vmTimerFrame.StartMoving)
vmTimerFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if db then
        db.vmTimerPos = { point = point, relPoint = relPoint, x = x, y = y }
    end
end)
vmTimerFrame:SetClampedToScreen(true)
vmTimerFrame:Hide()

local vmTimerIcon = vmTimerFrame:CreateTexture(nil, "ARTWORK")
vmTimerIcon:SetSize(24, 24)
vmTimerIcon:SetTexture(ICON_PATH)
vmTimerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
vmTimerIcon:Hide()

local vmTimerText = vmTimerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
vmTimerText:SetPoint("CENTER")

local function FormatElapsed(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function UpdateVmTimer()
    if db and db.counterPreview then
        vmTimerText:SetText(FormatElapsed(VM_TIMER_PREVIEW_VALUE))
    elseif vmStartTime then
        vmTimerText:SetText(FormatElapsed(GetTime() - vmStartTime))
    else
        vmTimerText:SetText(FormatElapsed(0))
    end
end

local function UpdateVmTimerVisibility()
    if not db or not db.showVmTimer then
        vmTimerFrame:Hide()
    elseif db.counterPreview or wasInMeta then
        vmTimerFrame:Show()
    else
        vmTimerFrame:Hide()
    end
end

local function RestoreVmTimerPos()
    if db and db.vmTimerPos then
        vmTimerFrame:ClearAllPoints()
        vmTimerFrame:SetPoint(db.vmTimerPos.point, UIParent, db.vmTimerPos.relPoint, db.vmTimerPos.x, db.vmTimerPos.y)
    end
end

-- Tick the elapsed text ~10x/sec. OnUpdate only fires while the frame is shown,
-- so it idles automatically outside VM / preview.
local vmTimerAccum = 0
vmTimerFrame:SetScript("OnUpdate", function(_, elapsed)
    vmTimerAccum = vmTimerAccum + elapsed
    if vmTimerAccum < 0.1 then return end
    vmTimerAccum = 0
    UpdateVmTimer()
end)

local function UpdateCounter()
    if db and db.counterPreview then
        counterText:SetText(COUNTER_PREVIEW_VALUE)
    else
        counterText:SetText(starCount)
    end
end

local function UpdateCounterVisibility()
    if not db or not db.showCounter then
        counterFrame:Hide()
    elseif db.counterPreview then
        counterFrame:Show()
    elseif db.counterOnlyInMeta and not wasInMeta then
        counterFrame:Hide()
    else
        counterFrame:Show()
    end
end

local function RestoreCounterPos()
    if db and db.counterPos then
        counterFrame:ClearAllPoints()
        counterFrame:SetPoint(db.counterPos.point, UIParent, db.counterPos.relPoint, db.counterPos.x, db.counterPos.y)
    end
end

-- Forward declarations: the counter apply functions mirror onto the timer when
-- "use same appearance" is on, but the timer apply functions are defined further
-- below (they need SetSettingValue). Declared here so the counter functions can
-- reference them as upvalues.
local ApplyVmTimerText, ApplyVmTimerIcon, ApplyVmTimerAppearance

local function ApplyCounterText()
    if not db then return end
    if db.counterTextOutline then
        local font, size = counterText:GetFont()
        if font and size then
            counterText:SetFont(font, size, "OUTLINE")
        end
    else
        counterText:SetFontObject("GameFontNormalLarge")
    end
    local color = CreateColorFromHexString(db.counterTextColor or "ffb380ff")
    local r, g, b = color:GetRGB()
    counterText:SetTextColor(r, g, b, db.counterTextAlpha or 1.0)
    if db.linkAppearance and ApplyVmTimerText then ApplyVmTimerText() end
end

local function ApplyCounterIcon()
    if not db then return end
    counterText:ClearAllPoints()
    counterIcon:ClearAllPoints()
    if db.counterShowIcon then
        counterFrame:SetSize(60, 36)
        if db.counterIconRight then
            counterText:SetPoint("CENTER", counterFrame, "CENTER", -16, 0)
            counterIcon:SetPoint("LEFT", counterText, "RIGHT", 4, 0)
        else
            counterText:SetPoint("CENTER", counterFrame, "CENTER", 16, 0)
            counterIcon:SetPoint("RIGHT", counterText, "LEFT", -4, 0)
        end
        counterIcon:Show()
    else
        counterFrame:SetSize(40, 36)
        counterText:SetPoint("CENTER")
        counterIcon:Hide()
    end
    if db.linkAppearance and ApplyVmTimerIcon then ApplyVmTimerIcon() end
end

local function ApplyCounterAppearance()
    if not db then return end
    counterFrame:SetScale(db.counterScale or 1.0)
    local bg = CreateColorFromHexString(db.counterBgColor or "ff1a0d26")
    local bgAlpha = (db.counterShowBackground == false) and 0 or (db.counterBgAlpha or 0.8)
    counterFrame:SetBackdropColor(bg.r, bg.g, bg.b, bgAlpha)
    local border = CreateColorFromHexString(db.counterBorderColor or "ff804dcc")
    local borderAlpha = (db.counterShowBorder == false) and 0 or (db.counterBorderAlpha or 0.9)
    counterFrame:SetBackdropBorderColor(border.r, border.g, border.b, borderAlpha)
    ApplyCounterText()
    ApplyCounterIcon()
    if db.linkAppearance and ApplyVmTimerAppearance then ApplyVmTimerAppearance() end
end

local settingRefs = {}

-- Mutate a setting through the Settings API when registered so the open panel
-- stays in sync; fall back to a direct db write + side effect otherwise.
local function SetSettingValue(key, value, fallback)
    local ref = settingRefs[key]
    if ref then
        ref:SetValue(value)
    else
        db[key] = value
        if fallback then fallback() end
    end
end

local function ResetCounterAppearance()
    if not db then return end
    db.counterPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 200 }
    RestoreCounterPos()
    SetSettingValue("counterShowBorder", true, ApplyCounterAppearance)
    SetSettingValue("counterShowBackground", true, ApplyCounterAppearance)
    SetSettingValue("counterScale", 1.0, ApplyCounterAppearance)
    SetSettingValue("counterTextColor", "ffb380ff", ApplyCounterText)
    SetSettingValue("counterTextAlpha", 1.0, ApplyCounterText)
    SetSettingValue("counterTextOutline", false, ApplyCounterText)
    SetSettingValue("counterShowIcon", false, ApplyCounterIcon)
    SetSettingValue("counterIconRight", false, ApplyCounterIcon)
    SetSettingValue("counterBgColor", "ff1a0d26", ApplyCounterAppearance)
    SetSettingValue("counterBgAlpha", 0.8, ApplyCounterAppearance)
    SetSettingValue("counterBorderColor", "ff804dcc", ApplyCounterAppearance)
    SetSettingValue("counterBorderAlpha", 0.9, ApplyCounterAppearance)
end

-- Resolve a timer appearance field. When "use same appearance" is on, the timer
-- mirrors the counter's fields (counterX) instead of its own (vmTimerX); the X
-- suffix is shared between the two field sets.
local function VmAppr(suffix, default)
    local src = (db and db.linkAppearance) and "counter" or "vmTimer"
    local v = db and db[src .. suffix]
    if v == nil then return default end
    return v
end

function ApplyVmTimerText()
    if not db then return end
    if VmAppr("TextOutline", false) then
        local font, size = vmTimerText:GetFont()
        if font and size then
            vmTimerText:SetFont(font, size, "OUTLINE")
        end
    else
        vmTimerText:SetFontObject("GameFontNormalLarge")
    end
    local color = CreateColorFromHexString(VmAppr("TextColor", "ffb380ff"))
    local r, g, b = color:GetRGB()
    vmTimerText:SetTextColor(r, g, b, VmAppr("TextAlpha", 1.0))
end

function ApplyVmTimerIcon()
    if not db then return end
    vmTimerText:ClearAllPoints()
    vmTimerIcon:ClearAllPoints()
    if VmAppr("ShowIcon", false) then
        vmTimerFrame:SetSize(80, 36)
        if VmAppr("IconRight", false) then
            vmTimerText:SetPoint("CENTER", vmTimerFrame, "CENTER", -14, 0)
            vmTimerIcon:SetPoint("LEFT", vmTimerText, "RIGHT", 4, 0)
        else
            vmTimerText:SetPoint("CENTER", vmTimerFrame, "CENTER", 14, 0)
            vmTimerIcon:SetPoint("RIGHT", vmTimerText, "LEFT", -4, 0)
        end
        vmTimerIcon:Show()
    else
        vmTimerFrame:SetSize(56, 36)
        vmTimerText:SetPoint("CENTER")
        vmTimerIcon:Hide()
    end
end

function ApplyVmTimerAppearance()
    if not db then return end
    vmTimerFrame:SetScale(VmAppr("Scale", 1.0))
    local bg = CreateColorFromHexString(VmAppr("BgColor", "ff1a0d26"))
    local bgAlpha = (VmAppr("ShowBackground", true) == false) and 0 or (VmAppr("BgAlpha", 0.8))
    vmTimerFrame:SetBackdropColor(bg.r, bg.g, bg.b, bgAlpha)
    local border = CreateColorFromHexString(VmAppr("BorderColor", "ff804dcc"))
    local borderAlpha = (VmAppr("ShowBorder", true) == false) and 0 or (VmAppr("BorderAlpha", 0.9))
    vmTimerFrame:SetBackdropBorderColor(border.r, border.g, border.b, borderAlpha)
    ApplyVmTimerText()
    ApplyVmTimerIcon()
end

local function ResetVmTimerAppearance()
    if not db then return end
    db.vmTimerPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 160 }
    RestoreVmTimerPos()
    SetSettingValue("vmTimerShowBorder", true, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerShowBackground", true, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerScale", 1.0, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerTextColor", "ffb380ff", ApplyVmTimerText)
    SetSettingValue("vmTimerTextAlpha", 1.0, ApplyVmTimerText)
    SetSettingValue("vmTimerTextOutline", false, ApplyVmTimerText)
    SetSettingValue("vmTimerBgColor", "ff1a0d26", ApplyVmTimerAppearance)
    SetSettingValue("vmTimerBgAlpha", 0.8, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerBorderColor", "ff804dcc", ApplyVmTimerAppearance)
    SetSettingValue("vmTimerBorderAlpha", 0.9, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerShowIcon", false, ApplyVmTimerIcon)
    SetSettingValue("vmTimerIconRight", false, ApplyVmTimerIcon)
end

-- Mirror one counter's appearance onto the other. Position and the counter's
-- icon options are intentionally left alone — only the shared visual style
-- (border / background / text / scale) is copied. Routed through
-- SetSettingValue so an open Settings panel reflects the new values.
local function CopyCounterStyleToTimer()
    if not db then return end
    SetSettingValue("vmTimerShowBorder", db.counterShowBorder, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerShowBackground", db.counterShowBackground, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerScale", db.counterScale, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerTextColor", db.counterTextColor, ApplyVmTimerText)
    SetSettingValue("vmTimerTextAlpha", db.counterTextAlpha, ApplyVmTimerText)
    SetSettingValue("vmTimerTextOutline", db.counterTextOutline, ApplyVmTimerText)
    SetSettingValue("vmTimerBgColor", db.counterBgColor, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerBgAlpha", db.counterBgAlpha, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerBorderColor", db.counterBorderColor, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerBorderAlpha", db.counterBorderAlpha, ApplyVmTimerAppearance)
    SetSettingValue("vmTimerShowIcon", db.counterShowIcon, ApplyVmTimerIcon)
    SetSettingValue("vmTimerIconRight", db.counterIconRight, ApplyVmTimerIcon)
end

local function CopyTimerStyleToCounter()
    if not db then return end
    SetSettingValue("counterShowBorder", db.vmTimerShowBorder, ApplyCounterAppearance)
    SetSettingValue("counterShowBackground", db.vmTimerShowBackground, ApplyCounterAppearance)
    SetSettingValue("counterScale", db.vmTimerScale, ApplyCounterAppearance)
    SetSettingValue("counterTextColor", db.vmTimerTextColor, ApplyCounterText)
    SetSettingValue("counterTextAlpha", db.vmTimerTextAlpha, ApplyCounterText)
    SetSettingValue("counterTextOutline", db.vmTimerTextOutline, ApplyCounterText)
    SetSettingValue("counterBgColor", db.vmTimerBgColor, ApplyCounterAppearance)
    SetSettingValue("counterBgAlpha", db.vmTimerBgAlpha, ApplyCounterAppearance)
    SetSettingValue("counterBorderColor", db.vmTimerBorderColor, ApplyCounterAppearance)
    SetSettingValue("counterBorderAlpha", db.vmTimerBorderAlpha, ApplyCounterAppearance)
    SetSettingValue("counterShowIcon", db.vmTimerShowIcon, ApplyCounterIcon)
    SetSettingValue("counterIconRight", db.vmTimerIconRight, ApplyCounterIcon)
end

local function ApplyMinimapVisibility()
    if not ns.LDBIcon then return end
    db.minimap.hide = not db.showMinimapButton
    if db.showMinimapButton then
        ns.LDBIcon:Show(addonName)
    else
        ns.LDBIcon:Hide(addonName)
    end
end

---------------------------------------------------------------------------
-- Settings panel (modern Settings API)
---------------------------------------------------------------------------
-- The Advanced subcategory object (set by RegisterAdvancedPanel). The main
-- panel's "Open Advanced Settings" button jumps to it via Settings.OpenToCategory.
local advancedCategory

local function OpenAdvancedPanel()
    if advancedCategory then
        Settings.OpenToCategory(advancedCategory:GetID())
    end
end

-- The "Open Advanced" button is only relevant once a "Custom" option is chosen.
local function AnyCustomSelected()
    return db ~= nil and (db.scale == "custom" or db.fallOffSound == "custom" or db.voidRayReadySound == "custom" or db.darknessSound == "custom" or db.voidMetaReadySound == "custom")
end

-- Re-evaluate settings-list visibility (e.g. the Advanced button's shown
-- predicate) after a dropdown changes. Deferred so it runs after the current
-- value-change finishes, and guarded so it never breaks anything.
local function RefreshSettingsDisplay()
    C_Timer.After(0, function()
        if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
            pcall(SettingsPanel.RepairDisplay, SettingsPanel)
        end
    end)
end

local function RegisterSettings()
    local ok, err = pcall(function()
        local category, layout = Settings.RegisterVerticalLayoutCategory("虛無鐘聲")

        -- Attach a shown predicate to an initializer (when supported) so a whole
        -- section can be hidden by gating each of its controls.
        local function ShownIf(init, pred)
            if pred and init and init.AddShownPredicate then init:AddShownPredicate(pred) end
            return init
        end

        local function AddHeader(label, pred)
            local init = CreateSettingsListSectionHeaderInitializer(label)
            ShownIf(init, pred)
            layout:AddInitializer(init)
            return init
        end

        local function AddPercentSlider(variable, variableKey, label, defaultValue, tooltip, callback, minValue, maxValue, shownPredicate)
            local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, VoidChimesDB, type(defaultValue), label, defaultValue)
            Settings.SetOnValueChangedCallback(variable, callback)
            local options = Settings.CreateSliderOptions(minValue or 0, maxValue or 1, 0.05)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return string.format("%d%%", math.floor(value * 100 + 0.5))
            end)
            ShownIf(Settings.CreateSlider(category, setting, options, tooltip), shownPredicate)
            return setting
        end

        local function CounterShown() return db ~= nil and db.showCounter end
        -- The timer's own appearance section is hidden when it mirrors the
        -- counter (linkAppearance) — there's nothing separate to edit then.
        local function VmTimerShown() return db ~= nil and db.showVmTimer and not db.linkAppearance end
        -- "Match" only makes sense when the two are styled independently.
        local function CounterMatchShown() return db ~= nil and db.showCounter and not db.linkAppearance end

        -- General
        AddHeader("一般")

        local minimapSetting = Settings.RegisterAddOnSetting(category, "VoidChimesShowMinimap", "showMinimapButton", VoidChimesDB, type(true), "小地圖按鈕", true)
        Settings.SetOnValueChangedCallback("VoidChimesShowMinimap", ApplyMinimapVisibility)
        Settings.CreateCheckbox(category, minimapSetting,
            "顯示或隱藏虛無鐘聲的小地圖按鈕。")
        settingRefs.showMinimapButton = minimapSetting

        -- Sound
        AddHeader("聲音")

        local enabledSetting = Settings.RegisterAddOnSetting(category, "VoidChimesEnabled", "enabled", VoidChimesDB, type(true), "啟用聲音", true)
        Settings.CreateCheckbox(category, enabledSetting,
            "在虛無惡魔化身期間，每次成功施放崩陷之星時播放漸升的音符。")
        settingRefs.enabled = enabledSetting

        do
            local variable = "VoidChimesSoundChannelIndex"
            local variableKey = "soundChannelIndex"
            local defaultValue = 2
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add(1, SOUND_CHANNEL_LABELS["Master"])
                container:Add(2, SOUND_CHANNEL_LABELS["SFX"])
                container:Add(3, SOUND_CHANNEL_LABELS["Music"])
                container:Add(4, SOUND_CHANNEL_LABELS["Ambience"])
                container:Add(5, SOUND_CHANNEL_LABELS["Dialog"])
                return container:GetData()
            end
            local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, VoidChimesDB, type(defaultValue), "音效頻道", defaultValue)
            Settings.SetOnValueChangedCallback(variable, function()
                db.soundChannel = SOUND_CHANNEL_KEYS[db.soundChannelIndex] or "SFX"
            end)
            Settings.CreateDropdown(category, setting, GetOptions,
                "鈴聲要透過哪個音效頻道播放，預設為「音效」。選擇主音量、環境音效、對話或音樂，可在遊戲的音效設定中個別調整其音量，或在降低音效音量時仍保持可聽見。「報數」與「語音」選項改用文字轉語音的音量，因此不受此設定影響。")
            settingRefs.soundChannelIndex = setting
        end

        -- Ability Cues: every sound tied to a specific spell — the Collapsing
        -- Star theme leads, then the one-shot event cues.
        AddHeader("技能提示音")

        do
            local variable = "VoidChimesScaleIndex"
            local variableKey = "scaleIndex"
            local defaultValue = 1
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add(1, SCALE_LABELS["minor"])
                container:Add(2, SCALE_LABELS["major"])
                container:Add(3, SCALE_LABELS["pyke"])
                container:Add(4, SCALE_LABELS["counting"])
                container:Add(5, SCALE_LABELS["custom"])
                return container:GetData()
            end
            local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, VoidChimesDB, type(defaultValue), "主題", defaultValue)
            Settings.SetOnValueChangedCallback(variable, function()
                db.scale = SCALE_KEYS[db.scaleIndex] or "minor"
                RefreshSettingsDisplay()
            end)
            Settings.CreateDropdown(category, setting, GetOptions,
                "小調五聲音階較為黑暗、符合虛無主題。大調五聲音階較為明亮、激昂。Pyke (灰燼騎士) 會播放《英雄聯盟》Pyke 灰燼騎士造型的語音。報數 (語音) 會透過系統的文字轉語音念出施放次數。自訂 (你的音符) 會播放你在「進階」面板自行編排的旋律。")
            settingRefs.scaleIndex = setting
        end

        layout:AddInitializer(CreateSettingsButtonInitializer(
            "試聽主題",
            "播放",
            PreviewTheme,
            "播放目前選擇的主題。",
            true))

        do
            local variable = "VoidChimesFallOffSoundIndex"
            local variableKey = "fallOffSoundIndex"
            local defaultValue = 1
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add(1, FALL_OFF_LABELS["off"])
                container:Add(2, FALL_OFF_LABELS["sounds_off"])
                container:Add(3, FALL_OFF_LABELS["minor"])
                container:Add(4, FALL_OFF_LABELS["major"])
                container:Add(5, FALL_OFF_LABELS["voice"])
                container:Add(6, FALL_OFF_LABELS["custom"])
                return container:GetData()
            end
            local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, VoidChimesDB, type(defaultValue), "結束音效", defaultValue)
            Settings.SetOnValueChangedCallback(variable, function()
                db.fallOffSound = FALL_OFF_KEYS[db.fallOffSoundIndex] or "off"
                RefreshSettingsDisplay()
            end)
            Settings.CreateDropdown(category, setting, GetOptions,
                "虛無惡魔化身結束時播放的聲音。「電源關閉」是逐漸關機的掃頻音，「小調和弦」是低沉的持續和弦，「大調和弦」是較明亮、類似鐘聲的和弦，「語音」使用文字轉語音。「自訂\226\128\166」會播放你在「進階」面板挑選的 LibSharedMedia 聲音。以上選項皆不會重複使用崩陷之星的音符。")
            settingRefs.fallOffSoundIndex = setting
        end

        layout:AddInitializer(CreateSettingsButtonInitializer(
            "試聽結束音效",
            "播放",
            PreviewFallOff,
            "播放目前選擇的結束音效。",
            true))

        do
            local variable = "VoidChimesVoidRayReadySoundIndex"
            local variableKey = "voidRayReadySoundIndex"
            local defaultValue = 1
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add(1, VOID_RAY_READY_LABELS["off"])
                container:Add(2, VOID_RAY_READY_LABELS["ping"])
                container:Add(3, VOID_RAY_READY_LABELS["chime"])
                container:Add(4, VOID_RAY_READY_LABELS["tone"])
                container:Add(5, VOID_RAY_READY_LABELS["voice"])
                container:Add(6, VOID_RAY_READY_LABELS["custom"])
                return container:GetData()
            end
            local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, VoidChimesDB, type(defaultValue), "虛無射線音效", defaultValue)
            Settings.SetOnValueChangedCallback(variable, function()
                db.voidRayReadySound = VOID_RAY_READY_KEYS[db.voidRayReadySoundIndex] or "off"
                RefreshSettingsDisplay()
            end)
            Settings.CreateDropdown(category, setting, GetOptions,
                "當虛無射線變為可用時播放的單次提示音：在虛無惡魔化身以外時狂怒超過 100，或在化身期間虛無射線冷卻結束時。「電子提示音」是中性的預設音，「鐘聲」搭配大調主題，「音調」搭配小調主題，「語音」使用文字轉語音。「自訂\226\128\166」會播放你在「進階」面板挑選的 LibSharedMedia 聲音。")
            settingRefs.voidRayReadySoundIndex = setting
        end

        layout:AddInitializer(CreateSettingsButtonInitializer(
            "試聽虛無射線音效",
            "播放",
            PreviewVoidRayReady,
            "播放目前選擇的虛無射線音效。若缺少音效檔會在聊天視窗中提示。",
            true))

        do
            local variable = "VoidChimesDarknessSoundIndex"
            local variableKey = "darknessSoundIndex"
            local defaultValue = 1
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add(1, DARKNESS_LABELS["off"])
                container:Add(2, DARKNESS_LABELS["nocturne"])
                container:Add(3, DARKNESS_LABELS["minor"])
                container:Add(4, DARKNESS_LABELS["major"])
                container:Add(5, DARKNESS_LABELS["voice"])
                container:Add(6, DARKNESS_LABELS["custom"])
                return container:GetData()
            end
            local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, VoidChimesDB, type(defaultValue), "黑暗音效", defaultValue)
            Settings.SetOnValueChangedCallback(variable, function()
                db.darknessSound = DARKNESS_KEYS[db.darknessSoundIndex] or "off"
                RefreshSettingsDisplay()
            end)
            Settings.CreateDropdown(category, setting, GetOptions,
                "施放黑暗時播放的聲音。「夜曲 (黑暗)」是《英雄聯盟》夜曲的語音。「小調鐘聲」與「大調鐘聲」是以崩陷之星音符編成的下行琶音 (分別為黑暗與明亮)。「語音」使用文字轉語音。「自訂\226\128\166」會播放你在「進階」面板挑選的 LibSharedMedia 聲音。")
            settingRefs.darknessSoundIndex = setting
        end

        layout:AddInitializer(CreateSettingsButtonInitializer(
            "試聽黑暗音效",
            "播放",
            PreviewDarkness,
            "播放目前選擇的黑暗音效。若缺少音效檔會在聊天視窗中提示。",
            true))

        do
            local variable = "VoidChimesVoidMetaReadySoundIndex"
            local variableKey = "voidMetaReadySoundIndex"
            local defaultValue = 1
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add(1, VOID_META_READY_LABELS["off"])
                container:Add(2, VOID_META_READY_LABELS["surge"])
                container:Add(3, VOID_META_READY_LABELS["dark"])
                container:Add(4, VOID_META_READY_LABELS["bright"])
                container:Add(5, VOID_META_READY_LABELS["voice"])
                container:Add(6, VOID_META_READY_LABELS["custom"])
                return container:GetData()
            end
            local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, VoidChimesDB, type(defaultValue), "虛無惡魔化身音效", defaultValue)
            Settings.SetOnValueChangedCallback(variable, function()
                db.voidMetaReadySound = VOID_META_READY_KEYS[db.voidMetaReadySoundIndex] or "off"
                RefreshSettingsDisplay()
            end)
            Settings.CreateDropdown(category, setting, GetOptions,
                "當虛無惡魔化身可以施放時 (已累積足夠的靈魂碎片) 播放的單次提示音。「能量湧動」是上升的掃頻音，「黑暗漸強」/「明亮漸強」是以崩陷之星音符編成的上行琶音，「語音」使用文字轉語音。「自訂\226\128\166」會播放你在「進階」面板挑選的 LibSharedMedia 聲音。")
            settingRefs.voidMetaReadySoundIndex = setting
        end

        layout:AddInitializer(CreateSettingsButtonInitializer(
            "試聽虛無惡魔化身音效",
            "播放",
            PreviewVoidMetaReady,
            "播放目前選擇的虛無惡魔化身音效。若缺少音效檔會在聊天視窗中提示。",
            true))

        -- Shown only while some "Custom" option is selected; jumps to the
        -- Advanced panel where that custom sound / theme is configured.
        local advButton = CreateSettingsButtonInitializer(
            "自訂音效",
            "進階",
            OpenAdvancedPanel,
            "編排自訂主題，並挑選上方任何「自訂」選項所使用的聲音 (主題、結束音效、虛無射線等)。",
            true)
        advButton:AddShownPredicate(AnyCustomSelected)
        layout:AddInitializer(advButton)

        -- On-Screen Display: master toggles + shared positioning preview. The
        -- per-element appearance sections below appear only once enabled.
        AddHeader("畫面顯示")

        local counterSetting = Settings.RegisterAddOnSetting(category, "VoidChimesShowCounter", "showCounter", VoidChimesDB, type(true), "顯示崩陷之星計數器", true)
        Settings.SetOnValueChangedCallback("VoidChimesShowCounter", function()
            UpdateCounterVisibility()
            RefreshSettingsDisplay()
        end)
        Settings.CreateCheckbox(category, counterSetting,
            "在畫面上顯示計數器，追蹤崩陷之星的施放次數。可拖曳以重新定位。")
        settingRefs.showCounter = counterSetting

        local showVmTimerSetting = Settings.RegisterAddOnSetting(category, "VoidChimesShowVmTimer", "showVmTimer", VoidChimesDB, type(true), "顯示虛無惡魔化身計時器", true)
        Settings.SetOnValueChangedCallback("VoidChimesShowVmTimer", function()
            UpdateVmTimerVisibility()
            RefreshSettingsDisplay()
        end)
        Settings.CreateCheckbox(category, showVmTimerSetting,
            "顯示計時器，計算虛無惡魔化身已持續的時間 (mm:ss)。僅在化身期間顯示。可拖曳以重新定位。")
        settingRefs.showVmTimer = showVmTimerSetting

        local previewSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterPreview", "counterPreview", VoidChimesDB, type(true), "預覽 (用於定位)", false)
        Settings.SetOnValueChangedCallback("VoidChimesCounterPreview", function()
            UpdateCounter()
            UpdateCounterVisibility()
            UpdateVmTimer()
            UpdateVmTimerVisibility()
        end)
        Settings.CreateCheckbox(category, previewSetting,
            "以範例數值強制顯示計數器與虛無惡魔化身計時器，方便你拖曳定位並調整外觀。它們在虛無惡魔化身之外通常為隱藏。重新載入介面後會自動關閉。")
        settingRefs.counterPreview = previewSetting

        local linkSetting = Settings.RegisterAddOnSetting(category, "VoidChimesLinkAppearance", "linkAppearance", VoidChimesDB, type(true), "兩者使用相同外觀", false)
        Settings.SetOnValueChangedCallback("VoidChimesLinkAppearance", function()
            ApplyVmTimerAppearance()
            RefreshSettingsDisplay()
        end)
        Settings.CreateCheckbox(category, linkSetting,
            "讓虛無惡魔化身計時器使用與崩陷之星計數器完全相同的外觀 (邊框、背景、文字、圖示、縮放)。開啟時會隱藏計時器自己的外觀選項；位置仍為獨立設定。")
        settingRefs.linkAppearance = linkSetting

        -- Star Counter appearance (shown only while the counter is enabled)
        AddHeader("崩陷之星計數器", CounterShown)

        local counterMetaSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterOnlyInMeta", "counterOnlyInMeta", VoidChimesDB, type(true), "僅在虛無惡魔化身時顯示", false)
        Settings.SetOnValueChangedCallback("VoidChimesCounterOnlyInMeta", function()
            UpdateCounterVisibility()
        end)
        ShownIf(Settings.CreateCheckbox(category, counterMetaSetting,
            "只在虛無惡魔化身啟用時顯示崩陷之星計數器。關閉此項可讓它保持顯示以便重新定位。"), CounterShown)
        settingRefs.counterOnlyInMeta = counterMetaSetting

        local resetOnMetaEndSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterResetOnMetaEnd", "counterResetOnMetaEnd", VoidChimesDB, type(true), "虛無惡魔化身結束後歸零", false)
        ShownIf(Settings.CreateCheckbox(category, resetOnMetaEndSetting,
            "在虛無惡魔化身結束時將計數器歸零。否則上一次的施放次數會持續顯示，直到下一次化身開始。"), CounterShown)
        settingRefs.counterResetOnMetaEnd = resetOnMetaEndSetting

        local borderSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterShowBorder", "counterShowBorder", VoidChimesDB, type(true), "顯示邊框", true)
        Settings.SetOnValueChangedCallback("VoidChimesCounterShowBorder", function()
            ApplyCounterAppearance()
        end)
        ShownIf(Settings.CreateCheckbox(category, borderSetting,
            "顯示崩陷之星計數器周圍的邊框。"), CounterShown)
        settingRefs.counterShowBorder = borderSetting

        local borderColorSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterBorderColor", "counterBorderColor", VoidChimesDB, type(""), "邊框顏色", "ff804dcc")
        Settings.SetOnValueChangedCallback("VoidChimesCounterBorderColor", ApplyCounterAppearance)
        ShownIf(Settings.CreateColorSwatch(category, borderColorSetting,
            "計數器周圍邊框的顏色。"), CounterShown)
        settingRefs.counterBorderColor = borderColorSetting

        settingRefs.counterBorderAlpha = AddPercentSlider(
            "VoidChimesCounterBorderAlpha", "counterBorderAlpha", "邊框不透明度", 0.9,
            "邊框的不透明度。0% 為完全透明，100% 為完全不透明。",
            ApplyCounterAppearance, nil, nil, CounterShown)

        local bgSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterShowBackground", "counterShowBackground", VoidChimesDB, type(true), "顯示背景", true)
        Settings.SetOnValueChangedCallback("VoidChimesCounterShowBackground", function()
            ApplyCounterAppearance()
        end)
        ShownIf(Settings.CreateCheckbox(category, bgSetting,
            "在計數器數字後方顯示深色背景填滿。關閉可讓數字呈現透明浮動效果。"), CounterShown)
        settingRefs.counterShowBackground = bgSetting

        local bgColorSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterBgColor", "counterBgColor", VoidChimesDB, type(""), "背景顏色", "ff1a0d26")
        Settings.SetOnValueChangedCallback("VoidChimesCounterBgColor", ApplyCounterAppearance)
        ShownIf(Settings.CreateColorSwatch(category, bgColorSetting,
            "計數器後方背景填滿的顏色。"), CounterShown)
        settingRefs.counterBgColor = bgColorSetting

        settingRefs.counterBgAlpha = AddPercentSlider(
            "VoidChimesCounterBgAlpha", "counterBgAlpha", "背景不透明度", 0.8,
            "背景填滿的不透明度。0% 為完全透明，100% 為完全不透明。",
            ApplyCounterAppearance, nil, nil, CounterShown)

        local textColorSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterTextColor", "counterTextColor", VoidChimesDB, type(""), "文字顏色", "ffb380ff")
        Settings.SetOnValueChangedCallback("VoidChimesCounterTextColor", ApplyCounterText)
        ShownIf(Settings.CreateColorSwatch(category, textColorSetting,
            "計數器數字的顏色。"), CounterShown)
        settingRefs.counterTextColor = textColorSetting

        settingRefs.counterTextAlpha = AddPercentSlider(
            "VoidChimesCounterTextAlpha", "counterTextAlpha", "文字不透明度", 1.0,
            "計數器數字的不透明度。0% 為完全透明，100% 為完全不透明。",
            ApplyCounterText, nil, nil, CounterShown)

        local textOutlineSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterTextOutline", "counterTextOutline", VoidChimesDB, type(true), "文字外框", false)
        Settings.SetOnValueChangedCallback("VoidChimesCounterTextOutline", ApplyCounterText)
        ShownIf(Settings.CreateCheckbox(category, textOutlineSetting,
            "在計數器數字周圍加上黑色外框，讓它在雜亂背景上更易閱讀。"), CounterShown)
        settingRefs.counterTextOutline = textOutlineSetting

        local showIconSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterShowIcon", "counterShowIcon", VoidChimesDB, type(true), "顯示崩陷之星圖示", false)
        Settings.SetOnValueChangedCallback("VoidChimesCounterShowIcon", ApplyCounterIcon)
        ShownIf(Settings.CreateCheckbox(category, showIconSetting,
            "在計數器數字旁顯示崩陷之星圖示。"), CounterShown)
        settingRefs.counterShowIcon = showIconSetting

        local iconRightSetting = Settings.RegisterAddOnSetting(category, "VoidChimesCounterIconRight", "counterIconRight", VoidChimesDB, type(true), "圖示置於右側", false)
        Settings.SetOnValueChangedCallback("VoidChimesCounterIconRight", ApplyCounterIcon)
        ShownIf(Settings.CreateCheckbox(category, iconRightSetting,
            "將崩陷之星圖示放在數字右側，而非左側。"), CounterShown)
        settingRefs.counterIconRight = iconRightSetting

        settingRefs.counterScale = AddPercentSlider(
            "VoidChimesCounterScale", "counterScale", "計數器縮放", 1.0,
            "調整崩陷之星計數器的大小。100% 為預設大小。",
            ApplyCounterAppearance, 0.5, 2.5, CounterShown)

        local counterResetBtn = CreateSettingsButtonInitializer(
            "重設外觀",
            "重設",
            ResetCounterAppearance,
            "將計數器的位置、顏色、縮放、文字與圖示設定重設為預設值。",
            true)
        counterResetBtn:AddShownPredicate(CounterShown)
        layout:AddInitializer(counterResetBtn)

        local counterMatchBtn = CreateSettingsButtonInitializer(
            "比照虛無惡魔化身計時器",
            "複製",
            CopyTimerStyleToCounter,
            "將虛無惡魔化身計時器的外觀 (邊框、背景、文字、圖示、縮放) 複製到崩陷之星計數器。位置維持不變。",
            true)
        counterMatchBtn:AddShownPredicate(CounterMatchShown)
        layout:AddInitializer(counterMatchBtn)

        -- Void Meta Timer appearance (shown only while the timer is enabled)
        AddHeader("虛無惡魔化身計時器", VmTimerShown)

        local vmBorderSetting = Settings.RegisterAddOnSetting(category, "VoidChimesVmTimerShowBorder", "vmTimerShowBorder", VoidChimesDB, type(true), "顯示邊框", true)
        Settings.SetOnValueChangedCallback("VoidChimesVmTimerShowBorder", ApplyVmTimerAppearance)
        ShownIf(Settings.CreateCheckbox(category, vmBorderSetting,
            "顯示虛無惡魔化身計時器周圍的邊框。"), VmTimerShown)
        settingRefs.vmTimerShowBorder = vmBorderSetting

        local vmBorderColorSetting = Settings.RegisterAddOnSetting(category, "VoidChimesVmTimerBorderColor", "vmTimerBorderColor", VoidChimesDB, type(""), "邊框顏色", "ff804dcc")
        Settings.SetOnValueChangedCallback("VoidChimesVmTimerBorderColor", ApplyVmTimerAppearance)
        ShownIf(Settings.CreateColorSwatch(category, vmBorderColorSetting,
            "計時器周圍邊框的顏色。"), VmTimerShown)
        settingRefs.vmTimerBorderColor = vmBorderColorSetting

        settingRefs.vmTimerBorderAlpha = AddPercentSlider(
            "VoidChimesVmTimerBorderAlpha", "vmTimerBorderAlpha", "邊框不透明度", 0.9,
            "邊框的不透明度。0% 為完全透明，100% 為完全不透明。",
            ApplyVmTimerAppearance, nil, nil, VmTimerShown)

        local vmBgSetting = Settings.RegisterAddOnSetting(category, "VoidChimesVmTimerShowBackground", "vmTimerShowBackground", VoidChimesDB, type(true), "顯示背景", true)
        Settings.SetOnValueChangedCallback("VoidChimesVmTimerShowBackground", ApplyVmTimerAppearance)
        ShownIf(Settings.CreateCheckbox(category, vmBgSetting,
            "在計時器後方顯示深色背景填滿。關閉可讓數字呈現透明浮動效果。"), VmTimerShown)
        settingRefs.vmTimerShowBackground = vmBgSetting

        local vmBgColorSetting = Settings.RegisterAddOnSetting(category, "VoidChimesVmTimerBgColor", "vmTimerBgColor", VoidChimesDB, type(""), "背景顏色", "ff1a0d26")
        Settings.SetOnValueChangedCallback("VoidChimesVmTimerBgColor", ApplyVmTimerAppearance)
        ShownIf(Settings.CreateColorSwatch(category, vmBgColorSetting,
            "計時器後方背景填滿的顏色。"), VmTimerShown)
        settingRefs.vmTimerBgColor = vmBgColorSetting

        settingRefs.vmTimerBgAlpha = AddPercentSlider(
            "VoidChimesVmTimerBgAlpha", "vmTimerBgAlpha", "背景不透明度", 0.8,
            "背景填滿的不透明度。0% 為完全透明，100% 為完全不透明。",
            ApplyVmTimerAppearance, nil, nil, VmTimerShown)

        local vmTextColorSetting = Settings.RegisterAddOnSetting(category, "VoidChimesVmTimerTextColor", "vmTimerTextColor", VoidChimesDB, type(""), "文字顏色", "ffb380ff")
        Settings.SetOnValueChangedCallback("VoidChimesVmTimerTextColor", ApplyVmTimerText)
        ShownIf(Settings.CreateColorSwatch(category, vmTextColorSetting,
            "計時器文字的顏色。"), VmTimerShown)
        settingRefs.vmTimerTextColor = vmTextColorSetting

        settingRefs.vmTimerTextAlpha = AddPercentSlider(
            "VoidChimesVmTimerTextAlpha", "vmTimerTextAlpha", "文字不透明度", 1.0,
            "計時器文字的不透明度。0% 為完全透明，100% 為完全不透明。",
            ApplyVmTimerText, nil, nil, VmTimerShown)

        local vmTextOutlineSetting = Settings.RegisterAddOnSetting(category, "VoidChimesVmTimerTextOutline", "vmTimerTextOutline", VoidChimesDB, type(true), "文字外框", false)
        Settings.SetOnValueChangedCallback("VoidChimesVmTimerTextOutline", ApplyVmTimerText)
        ShownIf(Settings.CreateCheckbox(category, vmTextOutlineSetting,
            "在計時器文字周圍加上黑色外框，讓它在雜亂背景上更易閱讀。"), VmTimerShown)
        settingRefs.vmTimerTextOutline = vmTextOutlineSetting

        local vmShowIconSetting = Settings.RegisterAddOnSetting(category, "VoidChimesVmTimerShowIcon", "vmTimerShowIcon", VoidChimesDB, type(true), "顯示圖示", false)
        Settings.SetOnValueChangedCallback("VoidChimesVmTimerShowIcon", ApplyVmTimerIcon)
        ShownIf(Settings.CreateCheckbox(category, vmShowIconSetting,
            "在計時器旁顯示圖示。"), VmTimerShown)
        settingRefs.vmTimerShowIcon = vmShowIconSetting

        local vmIconRightSetting = Settings.RegisterAddOnSetting(category, "VoidChimesVmTimerIconRight", "vmTimerIconRight", VoidChimesDB, type(true), "圖示置於右側", false)
        Settings.SetOnValueChangedCallback("VoidChimesVmTimerIconRight", ApplyVmTimerIcon)
        ShownIf(Settings.CreateCheckbox(category, vmIconRightSetting,
            "將圖示放在計時器右側，而非左側。"), VmTimerShown)
        settingRefs.vmTimerIconRight = vmIconRightSetting

        settingRefs.vmTimerScale = AddPercentSlider(
            "VoidChimesVmTimerScale", "vmTimerScale", "計時器縮放", 1.0,
            "調整虛無惡魔化身計時器的大小。100% 為預設大小。",
            ApplyVmTimerAppearance, 0.5, 2.5, VmTimerShown)

        local vmResetBtn = CreateSettingsButtonInitializer(
            "重設計時器外觀",
            "重設",
            ResetVmTimerAppearance,
            "將虛無惡魔化身計時器的位置、顏色、縮放、文字與圖示設定重設為預設值。",
            true)
        vmResetBtn:AddShownPredicate(VmTimerShown)
        layout:AddInitializer(vmResetBtn)

        local vmMatchBtn = CreateSettingsButtonInitializer(
            "比照崩陷之星計數器",
            "複製",
            CopyCounterStyleToTimer,
            "將崩陷之星計數器的外觀 (邊框、背景、文字、圖示、縮放) 複製到虛無惡魔化身計時器。位置維持不變。",
            true)
        vmMatchBtn:AddShownPredicate(VmTimerShown)
        layout:AddInitializer(vmMatchBtn)

        Settings.RegisterAddOnCategory(category)
        settingsCategory = category
    end)
    if not ok then
        print(ADDON_COLOR .. "Void Chimes|r 設定註冊失敗：" .. tostring(err))
    end
end

---------------------------------------------------------------------------
-- Advanced sub-panel: custom theme builder + LibSharedMedia cue pickers
--
-- Lives apart from the main panel so the everyday controls stay clean; this is
-- where users plug in their own / third-party sounds. A custom canvas frame
-- (the Settings vertical layout can't host a dynamic add/remove list).
---------------------------------------------------------------------------

-- Substring filter shared by every sound dropdown, driven by the Advanced
-- panel's search box. Lowercased; "" means show everything.
local soundFilter = ""

-- A WowStyle1 dropdown listing LibSharedMedia sounds — ours first, a divider,
-- then everyone else's, narrowed by soundFilter. getValue/setValue bind it to a
-- db field. The collapsed button text auto-tracks the selected radio; call
-- :GenerateMenu() to refresh it after the underlying value changes.
local function MakeSoundDropdown(parent, width, getValue, setValue)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(width)
    dd:SetDefaultText("(無)")
    dd:SetupMenu(function(_, root)
        -- The LSM list can be hundreds of sounds; cap the menu height so it
        -- scrolls on screen instead of growing past the top/bottom of the display.
        root:SetScrollMode(math.max(160, math.min(420, (UIParent:GetHeight() or 600) * 0.55)))
        root:CreateRadio("(無)", function() return (getValue() or "") == "" end, function()
            setValue("")
        end)
        local filter = soundFilter or ""
        local addedOurs, addedDivider = false, false
        for _, name in ipairs(SortedLSMSounds()) do
            -- Keep the current selection visible even when it doesn't match.
            if filter == "" or name:lower():find(filter, 1, true) or name == getValue() then
                local isOurs = name:sub(1, #LSM_PREFIX) == LSM_PREFIX
                if addedOurs and not isOurs and not addedDivider then
                    root:CreateDivider()
                    addedDivider = true
                end
                if isOurs then addedOurs = true end
                root:CreateRadio(name, function() return getValue() == name end, function()
                    setValue(name)
                end)
            end
        end
    end)
    return dd
end

local advancedRefresh

local function RegisterAdvancedPanel()
    if not settingsCategory then return end
    local ok, err = pcall(function()
        local PAD, ROW_H, DD_W = 16, 25, 280

        local panel = CreateFrame("Frame", "VoidChimesAdvancedPanel", UIParent)
        panel:Hide()
        panel:SetSize(640, 640)

        local function Title(text, anchor, gap)
            local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            if anchor then
                fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 16))
            else
                fs:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
            end
            fs:SetText(text)
            return fs
        end

        local function Desc(text, anchor)
            local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
            fs:SetWidth(580)
            fs:SetJustifyH("LEFT")
            fs:SetText(text)
            return fs
        end

        -- Panel heading + how to get your own sounds into these lists.
        local panelTitle = Title("自訂音效")
        local helpDesc = Desc("若要使用自己的聲音：請將 .ogg/.mp3 檔案放入媒體插件 (例如 SharedMediaAdditional)，再完全重新啟動 WoW — 全新檔案無法只靠 /reload 載入。", panelTitle)

        -- Filter: narrows every sound dropdown below (shared soundFilter).
        local searchLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        searchLabel:SetPoint("TOPLEFT", helpDesc, "BOTTOMLEFT", 0, -12)
        searchLabel:SetText("篩選聲音：")
        local searchBox = CreateFrame("EditBox", "VoidChimesSoundSearch", panel, "SearchBoxTemplate")
        searchBox:SetSize(260, 20)
        searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
        if searchBox.Instructions then searchBox.Instructions:SetText("輸入文字以篩選") end
        searchBox:HookScript("OnTextChanged", function(self)
            soundFilter = (self:GetText() or ""):lower()
        end)

        local themeTitle = Title("自訂主題", searchLabel, 18)
        local themeDesc = Desc("當主題設為「自訂 (你的音符)」時，每顆崩陷之星對應一個聲音。你的虛無鐘聲內建聲音會列在最前面。", themeTitle)

        local rows = {}
        for i = 1, CUSTOM_MAX do
            local row = CreateFrame("Frame", nil, panel)
            row:SetSize(560, ROW_H)
            if i == 1 then
                row:SetPoint("TOPLEFT", themeDesc, "BOTTOMLEFT", 0, -10)
            else
                row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
            end

            local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            label:SetPoint("LEFT", row, "LEFT", 0, 0)
            label:SetWidth(28)
            label:SetJustifyH("LEFT")
            label:SetText(i .. ".")

            local dd = MakeSoundDropdown(row, DD_W,
                function() return db.customTheme[i] end,
                function(name) db.customTheme[i] = name end)
            dd:SetPoint("LEFT", label, "RIGHT", 4, 0)

            local rm = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            rm:SetSize(26, 26)
            rm:SetPoint("LEFT", dd, "RIGHT", 4, 0)
            rm:SetScript("OnClick", function()
                table.remove(db.customTheme, i)
                advancedRefresh()
            end)

            row.dd = dd
            rows[i] = row
            row:Hide()
        end

        local emptyText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        emptyText:SetPoint("TOPLEFT", themeDesc, "BOTTOMLEFT", 4, -14)
        emptyText:SetText("尚未設定任何音符 — 請點擊「新增音符」。")

        local addBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        addBtn:SetSize(110, 22)
        addBtn:SetPoint("TOPLEFT", rows[CUSTOM_MAX], "BOTTOMLEFT", 0, -10)
        addBtn:SetText("新增音符")
        addBtn:SetScript("OnClick", function()
            if #db.customTheme < CUSTOM_MAX then
                table.insert(db.customTheme, "")
                advancedRefresh()
            end
        end)

        local previewBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        previewBtn:SetSize(110, 22)
        previewBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        previewBtn:SetText("試聽")
        previewBtn:SetScript("OnClick", PreviewCustomTheme)

        local cueTitle = Title("自訂提示音", addBtn, 18)
        local cueDesc = Desc("當主面板上對應的提示音 (結束音效／虛無射線等) 設為「自訂」時播放。此處的試聽會直接播放挑選的聲音。", cueTitle)

        -- Audition the custom-picked sound itself, regardless of what the main
        -- panel's cue dropdown is currently set to.
        local function PreviewCustomCue(name, label)
            local file = CustomSoundFile(name)
            if file then
                PlaySoundFile(file, SoundChannel())
            else
                print(ADDON_COLOR .. "Void Chimes|r " .. label .. " — 請先挑選一個聲音。")
            end
        end

        local fallLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fallLabel:SetPoint("TOPLEFT", cueDesc, "BOTTOMLEFT", 0, -12)
        fallLabel:SetWidth(110)
        fallLabel:SetJustifyH("LEFT")
        fallLabel:SetText("結束音效")
        local fallDD = MakeSoundDropdown(panel, DD_W,
            function() return db.fallOffCustom end,
            function(name) db.fallOffCustom = name end)
        fallDD:SetPoint("LEFT", fallLabel, "RIGHT", 4, 0)
        local fallPrev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        fallPrev:SetSize(90, 22)
        fallPrev:SetPoint("LEFT", fallDD, "RIGHT", 6, 0)
        fallPrev:SetText("試聽")
        fallPrev:SetScript("OnClick", function() PreviewCustomCue(db.fallOffCustom, "自訂結束音效") end)

        local rayLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        rayLabel:SetPoint("TOPLEFT", fallLabel, "BOTTOMLEFT", 0, -16)
        rayLabel:SetWidth(110)
        rayLabel:SetJustifyH("LEFT")
        rayLabel:SetText("虛無射線")
        local rayDD = MakeSoundDropdown(panel, DD_W,
            function() return db.voidRayReadyCustom end,
            function(name) db.voidRayReadyCustom = name end)
        rayDD:SetPoint("LEFT", rayLabel, "RIGHT", 4, 0)
        local rayPrev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        rayPrev:SetSize(90, 22)
        rayPrev:SetPoint("LEFT", rayDD, "RIGHT", 6, 0)
        rayPrev:SetText("試聽")
        rayPrev:SetScript("OnClick", function() PreviewCustomCue(db.voidRayReadyCustom, "自訂虛無射線音效") end)

        local darkLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        darkLabel:SetPoint("TOPLEFT", rayLabel, "BOTTOMLEFT", 0, -16)
        darkLabel:SetWidth(110)
        darkLabel:SetJustifyH("LEFT")
        darkLabel:SetText("黑暗")
        local darkDD = MakeSoundDropdown(panel, DD_W,
            function() return db.darknessCustom end,
            function(name) db.darknessCustom = name end)
        darkDD:SetPoint("LEFT", darkLabel, "RIGHT", 4, 0)
        local darkPrev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        darkPrev:SetSize(90, 22)
        darkPrev:SetPoint("LEFT", darkDD, "RIGHT", 6, 0)
        darkPrev:SetText("試聽")
        darkPrev:SetScript("OnClick", function() PreviewCustomCue(db.darknessCustom, "自訂黑暗音效") end)

        local vmReadyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        vmReadyLabel:SetPoint("TOPLEFT", darkLabel, "BOTTOMLEFT", 0, -16)
        vmReadyLabel:SetWidth(110)
        vmReadyLabel:SetJustifyH("LEFT")
        vmReadyLabel:SetText("虛無惡魔化身")
        local vmReadyDD = MakeSoundDropdown(panel, DD_W,
            function() return db.voidMetaReadyCustom end,
            function(name) db.voidMetaReadyCustom = name end)
        vmReadyDD:SetPoint("LEFT", vmReadyLabel, "RIGHT", 4, 0)
        local vmReadyPrev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        vmReadyPrev:SetSize(90, 22)
        vmReadyPrev:SetPoint("LEFT", vmReadyDD, "RIGHT", 6, 0)
        vmReadyPrev:SetText("試聽")
        vmReadyPrev:SetScript("OnClick", function() PreviewCustomCue(db.voidMetaReadyCustom, "自訂虛無惡魔化身音效") end)

        advancedRefresh = function()
            if not db or not db.customTheme then return end
            local count = #db.customTheme
            for i = 1, CUSTOM_MAX do
                if i <= count then
                    rows[i]:Show()
                    rows[i].dd:GenerateMenu()
                else
                    rows[i]:Hide()
                end
            end
            emptyText:SetShown(count == 0)
            if count >= CUSTOM_MAX then addBtn:Disable() else addBtn:Enable() end
            fallDD:GenerateMenu()
            rayDD:GenerateMenu()
            darkDD:GenerateMenu()
            vmReadyDD:GenerateMenu()
        end

        panel:SetScript("OnShow", advancedRefresh)

        advancedCategory = Settings.RegisterCanvasLayoutSubcategory(settingsCategory, panel, "進階")
    end)
    if not ok then
        print(ADDON_COLOR .. "Void Chimes|r 進階面板註冊失敗：" .. tostring(err))
    end
end

---------------------------------------------------------------------------
-- Addon Compartment (burger menu)
---------------------------------------------------------------------------
function VoidChimes_OnAddonCompartmentClick()
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

function VoidChimes_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Void Chimes v" .. GetVersion(), 1, 1, 1)
    GameTooltip:AddLine("點擊以開啟設定", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function VoidChimes_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Minimap button (LibDataBroker + LibDBIcon)
---------------------------------------------------------------------------
local function RegisterMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not LDBIcon then return end

    local dataObj = LDB:NewDataObject(addonName, {
        type = "launcher",
        icon = ICON_PATH,
        OnClick = function(_, button)
            if button == "LeftButton" then
                if settingsCategory then
                    Settings.OpenToCategory(settingsCategory:GetID())
                else
                    print(ADDON_COLOR .. "Void Chimes|r 設定尚未就緒 — 請於 /reload 後輸入 /vc settings")
                end
            elseif button == "RightButton" then
                SetSettingValue("enabled", not db.enabled)
                local status = db.enabled and "|cff00ff00已啟用|r" or "|cffff0000已停用|r"
                print(ADDON_COLOR .. "Void Chimes|r " .. status)
            end
        end,
        OnTooltipShow = function(tip)
            tip:AddLine("Void Chimes v" .. GetVersion(), 1, 1, 1)
            tip:AddLine("主題：" .. SCALE_LABELS[db.scale], 0.7, 0.7, 0.7)
            tip:AddLine("狀態：" .. (db.enabled and "|cff00ff00已啟用|r" or "|cffff0000已停用|r"), 0.7, 0.7, 0.7)
            tip:AddLine("左鍵開啟設定", 0.7, 0.7, 0.7)
            tip:AddLine("右鍵切換開啟／關閉", 0.7, 0.7, 0.7)
        end,
    })
    LDBIcon:Register(addonName, dataObj, db.minimap)
    ns.LDBIcon = LDBIcon
end

---------------------------------------------------------------------------
-- Core event handling
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")

---------------------------------------------------------------------------
-- Spec gating (Devourer Demon Hunter only, spec index 3)
---------------------------------------------------------------------------
local DEVOURER_SPEC_INDEX = 3
local isDevourer = false

local function IsDevourer()
    local _, classToken = UnitClass("player")
    if classToken ~= "DEMONHUNTER" then return false end
    return GetSpecialization() == DEVOURER_SPEC_INDEX
end

local function EnableTracking()
    isDevourer = true
    -- UNIT_SPELLCAST_SUCCEEDED is registered for all Demon Hunters at load (it
    -- drives the Darkness cue on every spec), so it isn't toggled here.
    f:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    f:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    f:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    f:RegisterUnitEvent("UNIT_AURA", "player")
    f:RegisterEvent("SPELL_UPDATE_USABLE")
    f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    RefreshAllCooldowns()
    -- Silent re-sync of latches to current state so the first transition check
    -- after load doesn't fire a spurious cue.
    voidRayWasReady = (not voidRayCDFrame:IsShown()) and (C_Spell.IsSpellUsable(VOID_RAY) and true or false)
    voidRayCasting = false
    voidMetaWasReady = (C_Spell.IsSpellUsable(VOID_META) and true or false) and not wasInMeta
    voidMetaLastFired = 0
    UpdateCounterVisibility()
    UpdateVmTimerVisibility()
end

local function DisableTracking()
    isDevourer = false
    wasInMeta = false
    starCount = 0
    UpdateCounter()
    -- Keep UNIT_SPELLCAST_SUCCEEDED registered: the Darkness cue still needs it
    -- on non-Devourer specs. Only the Devourer-specific events are dropped here.
    f:UnregisterEvent("UNIT_SPELLCAST_START")
    f:UnregisterEvent("UNIT_SPELLCAST_STOP")
    f:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    f:UnregisterEvent("UNIT_AURA")
    f:UnregisterEvent("SPELL_UPDATE_USABLE")
    f:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
    voidRayCDFrame:Clear()
    voidRayWasReady = false
    voidRayCasting = false
    voidMetaWasReady = false
    if db and db.counterPreview then
        SetSettingValue("counterPreview", false, function()
            UpdateCounter()
            UpdateCounterVisibility()
            UpdateVmTimer()
            UpdateVmTimerVisibility()
        end)
    end
    counterFrame:Hide()
    vmStartTime = nil
    vmTimerFrame:Hide()
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end

        InitDB()
        db.counterPreview = false
        RestoreCounterPos()
        RestoreVmTimerPos()
        ApplyCounterAppearance()
        ApplyVmTimerAppearance()
        UpdateCounter()
        UpdateVmTimer()
        RegisterSettings()
        RegisterAdvancedPanel()
        RegisterMinimapButton()

        f:RegisterEvent("PLAYER_REGEN_DISABLED")

        local _, classToken = UnitClass("player")
        if classToken ~= "DEMONHUNTER" then
            f:UnregisterEvent("ADDON_LOADED")
            return
        end

        -- The Darkness cue works on every Demon Hunter spec, so listen for casts
        -- regardless of spec. The rest of the addon (Collapsing Star, Void Ray,
        -- counter, VM timer) is Devourer-only and gated by Enable/DisableTracking.
        f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

        -- Spec isn't available yet during ADDON_LOADED, check on PLAYER_ENTERING_WORLD
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

        f:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_REGEN_DISABLED" then
        if db and db.counterPreview then
            SetSettingValue("counterPreview", false, function()
                UpdateCounter()
                UpdateCounterVisibility()
                UpdateVmTimer()
                UpdateVmTimerVisibility()
            end)
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if IsDevourer() then
            if not isDevourer then
                EnableTracking()
                if event == "PLAYER_ENTERING_WORLD" then
                    print(ADDON_COLOR .. "Void Chimes v" .. GetVersion() .. "|r 已載入"
                        .. (settingsCategory and "" or " |cffff0000(設定失敗)|r"))
                end
            end
        else
            if isDevourer then DisableTracking() end
        end

    elseif event == "UNIT_SPELLCAST_START" then
        local unit, castOrSpell, spellID = ...
        if type(castOrSpell) == "number" then spellID = castOrSpell end
        if unit == "player" and spellID == VOID_RAY then
            voidRayCasting = true
            if debugMode then print(ADDON_COLOR .. "Void Chimes debug|r VOID_RAY cast START") end
        end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit, castOrSpell, spellID = ...
        if type(castOrSpell) == "number" then spellID = castOrSpell end
        if unit == "player" and spellID == VOID_RAY then
            voidRayCasting = false
            if debugMode then print(ADDON_COLOR .. "Void Chimes debug|r VOID_RAY cast STOP") end
            CheckVoidRayReady()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castOrSpell, spellID = ...
        -- WoW 12.0 may pass (unit, spellID) or (unit, castGUID, spellID)
        if type(castOrSpell) == "number" then
            spellID = castOrSpell
        end
        if unit ~= "player" then return end
        if debugMode then
            print(ADDON_COLOR .. "Void Chimes debug|r CAST spellID=" .. tostring(spellID) .. " wasInMeta=" .. tostring(wasInMeta))
        end

        if spellID == VOID_RAY then
            voidRayCasting = false
            RefreshCooldown(VOID_RAY, voidRayCDFrame)
            CheckVoidRayReady()
        end

        if spellID == DARKNESS then
            PlayDarknessSound()
        end

        -- Any cast can spend/generate souls or Fury, changing VM usability.
        CheckVoidMetaReady()

        if spellID ~= COLLAPSING_STAR then return end

        -- Counter (works regardless of sound enabled)
        if wasInMeta then
            starCount = starCount + 1
            UpdateCounter()
        end

        -- Sound (note matches the star count, capped at scale length)
        if not db.enabled then return end
        if not C_UnitAuras.GetPlayerAuraBySpellID(VOID_META_BUFF) then return end

        local len = ThemeLength(db.scale)
        if len == 0 then return end
        local noteIdx = math.min(starCount, len)
        PlayNote(db.scale, noteIdx)

    elseif event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if debugMode then HandleDebugAuraUpdate(unit, updateInfo) end
        local inMeta = C_UnitAuras.GetPlayerAuraBySpellID(VOID_META_BUFF) ~= nil
        if debugMode then
            local changed = (wasInMeta ~= inMeta)
            if changed then
                print(ADDON_COLOR .. "Void Chimes debug|r META " .. (inMeta and "ENTERED" or "DROPPED") .. " (buffID=" .. VOID_META_BUFF .. ")")
            end
        end
        local wasIn = wasInMeta
        wasInMeta = inMeta
        if wasIn and not inMeta then
            PlayFallOffSound()
            -- VM exit: Void Ray reverts to its Fury-gated, no-CD profile.
            -- Refresh the shadow widget so it reflects the post-VM state,
            -- then resync the latch.
            RefreshAllCooldowns()
            CheckVoidRayReady()
            if db.counterResetOnMetaEnd then
                starCount = 0
                UpdateCounter()
            end
            UpdateCounterVisibility()
            vmStartTime = nil
            UpdateVmTimerVisibility()
        elseif not wasIn and inMeta then
            starCount = 0
            UpdateCounter()
            UpdateCounterVisibility()
            vmStartTime = GetTime()
            UpdateVmTimer()
            UpdateVmTimerVisibility()
            -- VM entry waives Void Ray's Fury cost. Refresh the widget first so
            -- the predicate sees the post-modifier state, then check — a
            -- false→true transition here fires the cue (intended: Void Ray
            -- genuinely became castable).
            RefreshAllCooldowns()
            CheckVoidRayReady()
        end
        -- Souls are aura/stack tracked, so soul gains surface here; re-check VM
        -- readiness after wasInMeta is up to date.
        CheckVoidMetaReady()

    elseif event == "SPELL_UPDATE_USABLE" then
        CheckVoidRayReady()
        CheckVoidMetaReady()

    elseif event == "SPELL_UPDATE_COOLDOWN" then
        RefreshAllCooldowns()
        CheckVoidRayReady()
    end
end)

local function SetDebugMode(on)
    debugMode = on
    if not on then wipe(auraSeen) end
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_VOIDCHIMES1 = "/voidchimes"
SLASH_VOIDCHIMES2 = "/vc"
SlashCmdList["VOIDCHIMES"] = function(msg)
    local arg = strtrim(msg):lower()
    if arg == "minor" or arg == "major" or arg == "pyke" or arg == "counting" or arg == "custom" then
        SetSettingValue("scaleIndex", ScaleIndexFor(arg), function()
            db.scale = arg
        end)
        print(ADDON_COLOR .. "Void Chimes|r 主題已設為 |cffffffff" .. SCALE_LABELS[arg] .. "|r")
    elseif arg == "on" or arg == "enable" then
        SetSettingValue("enabled", true)
        print(ADDON_COLOR .. "Void Chimes|r 已啟用")
    elseif arg == "off" or arg == "disable" then
        SetSettingValue("enabled", false)
        print(ADDON_COLOR .. "Void Chimes|r 已停用")
    elseif arg == "minimap" then
        SetSettingValue("showMinimapButton", not db.showMinimapButton, ApplyMinimapVisibility)
        print(ADDON_COLOR .. "Void Chimes|r 小地圖按鈕" .. (db.showMinimapButton and "已顯示" or "已隱藏"))
    elseif arg == "debug" then
        SetDebugMode(not debugMode)
        print(ADDON_COLOR .. "Void Chimes|r 除錯 " .. (debugMode and "|cff00ff00開啟|r — 記錄施放、光環 (新增/刷新/移除) 與狂怒變化" or "|cffff0000關閉|r"))
    elseif arg == "counter" then
        SetSettingValue("showCounter", not db.showCounter, UpdateCounterVisibility)
        print(ADDON_COLOR .. "Void Chimes|r 崩陷之星計數器" .. (db.showCounter and "已顯示" or "已隱藏"))
    elseif arg == "vmtimer" then
        SetSettingValue("showVmTimer", not db.showVmTimer, UpdateVmTimerVisibility)
        print(ADDON_COLOR .. "Void Chimes|r 虛無惡魔化身計時器" .. (db.showVmTimer and "已顯示" or "已隱藏"))
    elseif arg == "test" or arg == "preview" then
        PreviewTheme()
    elseif arg == "falloff" then
        PreviewFallOff()
    elseif arg == "voidray" then
        PreviewVoidRayReady()
    elseif arg == "darkness" then
        PreviewDarkness()
    elseif arg == "voidmeta" then
        PreviewVoidMetaReady()
    elseif arg == "reset" then
        ResetCounterAppearance()
        print(ADDON_COLOR .. "Void Chimes|r 計數器外觀已重設為預設值")
    elseif arg == "settings" or arg == "config" then
        if settingsCategory then
            Settings.OpenToCategory(settingsCategory:GetID())
        end
    else
        print(ADDON_COLOR .. "Void Chimes v" .. GetVersion() .. "|r")
        print("  主題：|cffffffff" .. SCALE_LABELS[db.scale] .. "|r")
        print("  狀態：|cffffffff" .. (db.enabled and "已啟用" or "已停用") .. "|r")
        print("  /vc minor|major|pyke|counting|custom - 切換主題")
        print("  /vc on|off - 開關聲音")
        print("  /vc test - 試聽目前主題")
        print("  /vc falloff - 試聽結束音效")
        print("  /vc voidray - 試聽虛無射線音效")
        print("  /vc darkness - 試聽黑暗音效")
        print("  /vc voidmeta - 試聽虛無惡魔化身音效")
        print("  /vc counter - 切換崩陷之星計數器")
        print("  /vc vmtimer - 切換虛無惡魔化身計時器")
        print("  /vc reset - 重設計數器位置與外觀")
        print("  /vc minimap - 切換小地圖按鈕")
        print("  /vc settings - 開啟設定面板")
    end
end
