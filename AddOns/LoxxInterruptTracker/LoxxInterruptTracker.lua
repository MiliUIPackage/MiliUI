--[[
    Loxx Interrupt Tracker v1.8.3 - Midnight 12.0.x

    Maintained by Loxxar.

    - Addon-to-addon sync (SendAddonMessage)
    - ShimmerTracker pattern for player CD (taint-safe)
    - ElvUI auto-detection (font, texture)
    - Simplified config (/loxx)
    - Corner drag-to-resize
    - SavedVariables

    Main chunk: ONLY plain CreateFrame("Frame") + RegisterEvent.
]]

local ADDON_NAME = "LoxxInterruptTracker"
local MSG_PREFIX = "LOXX"
local LOXX_VERSION = "1.9.6"
local LOXX_DB_VERSION = 2   -- bump when SavedVars schema changes

------------------------------------------------------------
-- Spell data (multiple possible interrupts per class/spec)
------------------------------------------------------------
local ALL_INTERRUPTS = {
    [6552]   = { name = "Pummel",            cd = 15, icon = 132938 },
    [1766]   = { name = "Kick",              cd = 15, icon = 132219 },
    [2139]   = { name = "Counterspell",      cd = 24, icon = 135856 },
    [57994]  = { name = "Wind Shear",        cd = 12, icon = 136018 },
    [106839] = { name = "Skull Bash",        cd = 15, icon = 236946 },
    [78675]  = { name = "Solar Beam",        cd = 60, icon = 236748 },
    [47528]  = { name = "Mind Freeze",       cd = 15, icon = 237527 },
    [96231]  = { name = "Rebuke",            cd = 15, icon = 523893 },
    [183752] = { name = "Disrupt",           cd = 15, icon = 1305153 },
    [116705] = { name = "Spear Hand Strike", cd = 15, icon = 608940 },
    [15487]  = { name = "Silence",           cd = 45, icon = 458230 },
    [147362] = { name = "Counter Shot",      cd = 24, icon = 249170 },
    [187707] = { name = "Muzzle",            cd = 15, icon = 1376045 },
    [19647]  = { name = "Spell Lock",        cd = 24, icon = 136174 },
    [132409] = { name = "Spell Lock",        cd = 24, icon = 136174 },
    [119914] = { name = "Axe Toss",          cd = 30, icon = "Interface\\Icons\\ability_warrior_titansgrip" },
    [1276467] = { name = "Fel Ravager",      cd = 25, icon = "Interface\\Icons\\spell_shadow_summonfelhunter" },
    [351338] = { name = "Quell",             cd = 20, icon = 4622469 },
}

-- Which spells to check per class (order matters: first found wins)
local CLASS_INTERRUPT_LIST = {
    WARRIOR     = { 6552 },
    ROGUE       = { 1766 },
    MAGE        = { 2139 },
    SHAMAN      = { 57994 },
    DRUID       = { 106839, 78675 },           -- Skull Bash (feral/guardian), Solar Beam (balance)
    DEATHKNIGHT = { 47528 },
    PALADIN     = { 96231 },
    DEMONHUNTER = { 183752 },
    MONK        = { 116705 },
    PRIEST      = { 15487 },                    -- Silence (shadow only)
    HUNTER      = { 147362, 187707 },           -- Counter Shot (BM/MM), Muzzle (survival)
    WARLOCK     = { 19647, 132409, 119914 },
    EVOKER      = { 351338 },
}

local CLASS_COLORS = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    ROGUE       = { 1.00, 0.96, 0.41 },
    MAGE        = { 0.41, 0.80, 0.94 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    DRUID       = { 1.00, 0.49, 0.04 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
    MONK        = { 0.00, 1.00, 0.59 },
    PRIEST      = { 1.00, 1.00, 1.00 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    WARLOCK     = { 0.58, 0.51, 0.79 },
    EVOKER      = { 0.20, 0.58, 0.50 },
}

------------------------------------------------------------
-- Defaults
------------------------------------------------------------
local DEFAULTS = {
    frameWidth  = 220,
    barHeight   = 28,
    locked      = false,
    showTitle   = true,
    growUp      = false,
    alpha       = 0.9,
    nameFontSize  = 14,   -- player name font size (2–32)
    readyFontSize = 14,   -- cooldown timer font size (2–32)
    readyTextSize = 14,   -- "READY" label font size (2–32)
    showReady   = true,
    showInDungeon   = true,
    showInOpenWorld = false,
    showInArena     = false,
    soundOnReady    = false,
    soundID         = 8960,   -- default: Ready Check ding
    showTooltip     = true,   -- show spell/CD tooltip on bar hover
}

------------------------------------------------------------
-- Sound list (~30 WoW sounds for the "Sound on Ready" dropdown)
-- Each entry: { name = "Display Name", id = numericSoundID }
-- IDs resolved from SOUNDKIT at runtime; numeric fallback if needed.
------------------------------------------------------------
local function SK(key, fallback)
    return (SOUNDKIT and SOUNDKIT[key]) or fallback
end
local SOUND_LIST = {
    { name = "Sound1", id = SK("AUCTION_WINDOW_OPEN",            3087)  },
    { name = "Sound2", id = SK("PVP_THROUGH_QUEUE_READY_CHECK", 12867)  },
}

------------------------------------------------------------
-- State
------------------------------------------------------------
local db
local myClass, myName, mySpellID
local myCachedCD
local myBaseCd                  -- real base CD from spellbook (with talents)
local myKickCdEnd = 0           -- clean tracking of our own kick CD
local myIsPetSpell = false      -- is our primary kick a pet spell?
local myExtraKicks = {}         -- extra kicks for own player {spellID → {baseCd, cdEnd}}
local partyAddonUsers = {}
local bars = {}
local wasOnCd = {}            -- tracks CD state per player key for sound transitions
local MAX_BARS        = 40   -- absolute cap (supports up to 40-man raids)
local currentMaxBars  = 7    -- updated dynamically based on group size
local mainFrame, titleText, configFrame, resizeHandle
local updateTicker
local ready = false
local isResizing = false
local lastAnnounce = 0
local testMode = false
local testTicker = nil
local spyMode = false

-- String-keyed version for laundered (still-tainted) spellID lookups
local ALL_INTERRUPTS_STR = {}
for id, data in pairs(ALL_INTERRUPTS) do
    ALL_INTERRUPTS_STR[tostring(id)] = data
end

-- String-keyed versions of talent tables.
-- C_Traits.GetDefinitionInfo returns defInfo.spellID as a secret value in WoW 12.0+,
-- which can't be used as a numeric table key. Fallback: convert to string.
local CD_REDUCTION_TALENTS_STR = {}
local CD_ON_KICK_TALENTS_STR   = {}
local EXTRA_KICK_TALENTS_STR   = {}

-- Class → primary interrupt mapping (for auto-detection when mob gets interrupted)
local CLASS_INTERRUPTS = {
    WARRIOR     = { id = 6552,   cd = 15, name = "Pummel" },
    ROGUE       = { id = 1766,   cd = 15, name = "Kick" },
    MAGE        = { id = 2139,   cd = 24, name = "Counterspell" },
    SHAMAN      = { id = 57994,  cd = 12, name = "Wind Shear" },
    DRUID       = { id = 106839, cd = 15, name = "Skull Bash" },
    DEATHKNIGHT = { id = 47528,  cd = 15, name = "Mind Freeze" },
    PALADIN     = { id = 96231,  cd = 15, name = "Rebuke" },
    DEMONHUNTER = { id = 183752, cd = 15, name = "Disrupt" },
    HUNTER      = { id = 147362, cd = 24, name = "Counter Shot" },
    MONK        = { id = 116705, cd = 15, name = "Spear Hand Strike" },
    WARLOCK     = { id = 19647,  cd = 24, name = "Spell Lock" },
    PRIEST      = { id = 15487,  cd = 45, name = "Silence" },
    EVOKER      = { id = 351338, cd = 20, name = "Quell" },
}

-- SpecID → interrupt override (when spec changes the interrupt or CD)
local SPEC_INTERRUPT_OVERRIDES = {
    [255]  = { id = 187707,  cd = 15, name = "Muzzle" },          -- Survival Hunter
    [264]  = { id = 57994,   cd = 30, name = "Wind Shear" },      -- Restoration Shaman (30s vs 12s for Ele/Enh)
    [266]  = { id = 119914,  cd = 30, name = "Axe Toss", isPet = true, petSpellID = 89766 },  -- Demonology Warlock (Felguard)
}

-- Specs that have NO interrupt (remove from tracker after inspect)
-- Be conservative: only list specs we're SURE have no interrupt
local SPEC_NO_INTERRUPT = {
    [256]  = true, -- Discipline Priest (no Silence)
    [257]  = true, -- Holy Priest (no Silence)
    [105]  = true, -- Restoration Druid (Skull Bash removed in 12.0)
    [65]   = true, -- Holy Paladin (no Rebuke)
    -- [1468] = true, -- Preservation Evoker - verify if Quell removed
    -- [270]  = true, -- Mistweaver Monk - verify if Spear Hand Strike removed
}

-- Talents that PERMANENTLY reduce interrupt cooldowns (scanned via inspect)
local CD_REDUCTION_TALENTS = {
    -- Hunter: Lone Survivor - "Counter Shot and Muzzle CD reduced by 2 sec" (passive)
    [388039] = { affects = 147362, reduction = 2,  name = "Lone Survivor" },
    -- Evoker: Interwoven Threads - "All spell CDs reduced by 10%" (percentage)
    [412713] = { affects = 351338, pctReduction = 10, name = "Interwoven Threads" },
}

-- Talents that reduce CD only on SUCCESSFUL interrupt (applied per-kick, not on baseCd)
local CD_ON_KICK_TALENTS = {
    -- DK: Coldthirst - "Mind Freeze CD reduced by 3 sec on successful interrupt"
    [378848] = { reduction = 3, name = "Coldthirst" },
}

-- Talents that grant an EXTRA interrupt ability (second bar)
local EXTRA_KICK_TALENTS = {
    -- (auto-detected dynamically when a different kick is used)
}

-- Populate string-keyed talent tables (built after numeric tables are defined)
for id, v in pairs(CD_REDUCTION_TALENTS) do CD_REDUCTION_TALENTS_STR[tostring(id)] = v end
for id, v in pairs(CD_ON_KICK_TALENTS)   do CD_ON_KICK_TALENTS_STR[tostring(id)]   = v end
for id, v in pairs(EXTRA_KICK_TALENTS)   do EXTRA_KICK_TALENTS_STR[tostring(id)]   = v end

-- Specs that always have extra kicks
local SPEC_EXTRA_KICKS = {
    [266] = {
        { id = 132409, cd = 24, name = "Fel Ravager / Spell Lock",
          icon = "Interface\\Icons\\spell_shadow_summonfelhunter",
          talentCheck = 1276467 },  -- Check if Grimoire: Fel Ravager talent is known
    },
}

-- Spell aliases: some spells fire different IDs on party vs own client
-- e.g., Fel Ravager summon fires as 1276467 on party but 132409 on own
local SPELL_ALIASES = {
    [1276467] = 132409,  -- Fel Ravager summon → Spell Lock extra kick bar
    [132409]  = 19647,   -- Command Demon: Spell Lock → primary Spell Lock bar (19647)
                         -- Note: Demo Warlock extra kick check still uses original spellID before alias
}

-- Inspect queue
local inspectQueue = {}
local inspectBusy = false
local inspectUnit = nil
local inspectedPlayers = {} -- name → true
local noInterruptPlayers = {} -- name → true (healers etc. with no kick)


local spyCastCount = 0
local partyFrames = {}
local partyPetFrames = {}
-- Pre-create party watcher frames at load time (clean untainted context)
for i = 1, 4 do
    partyFrames[i] = CreateFrame("Frame")
    partyPetFrames[i] = CreateFrame("Frame")
end
local RegisterPartyWatchers
local sniffMode = false

-- Use the game's default font (supports all locales: Latin, Cyrillic, Korean, Chinese)
local FONT_FACE = GameFontNormal and GameFontNormal:GetFont() or STANDARD_TEXT_FONT
local FONT_FLAGS  = "OUTLINE"
local BAR_TEXTURE = "Interface\\BUTTONS\\WHITE8X8"
local FLAT_TEX    = "Interface\\BUTTONS\\WHITE8X8"

-- Locale-specific font fallbacks (if GameFontNormal not available at load time)
local LOCALE_FONTS = {
    ["koKR"] = "Fonts\\2002.TTF",
    ["zhCN"] = "Fonts\\ARKai_T.TTF",
    ["zhTW"] = "Fonts\\blei00d.TTF",
    ["ruRU"] = "Fonts\\FRIZQT___CYR.TTF",
}

------------------------------------------------------------
-- ElvUI detection
------------------------------------------------------------
local function DetectElvUI()
    -- Apply locale font fallback if needed
    local locale = GetLocale()
    if LOCALE_FONTS[locale] and FONT_FACE == STANDARD_TEXT_FONT then
        FONT_FACE = LOCALE_FONTS[locale]
    end
    -- Re-read from GameFontNormal in case it's ready now
    if GameFontNormal then
        local gf = GameFontNormal:GetFont()
        if gf then FONT_FACE = gf end
    end

    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.media then
            if E.media.normFont then FONT_FACE = E.media.normFont end
            if E.media.normTex then BAR_TEXTURE = E.media.normTex end
        end
    end
end

------------------------------------------------------------
-- Communication
------------------------------------------------------------
local function SendLOXX(msg)
    -- Pick the correct channel BEFORE sending to avoid system error messages.
    -- PARTY works outside instances; INSTANCE_CHAT works inside M+/raids.
    local inInstance = IsInInstance()
    local channel = inInstance and "INSTANCE_CHAT" or "PARTY"
    pcall(C_ChatInfo.SendAddonMessage, MSG_PREFIX, msg, channel)
end

local function ReadMyBaseCd()
    if not mySpellID then return end
    local ok, ms = pcall(GetSpellBaseCooldown, mySpellID)
    if ok and ms then
        local clean = tonumber(string.format("%.0f", ms))
        if clean and clean > 0 then
            myBaseCd = clean / 1000
        end
    end
    -- TryCacheCD gives actual observed CD (after all modifiers)
    if myCachedCD and myCachedCD > 1.5 then
        myBaseCd = myCachedCD
    end
end

local function AnnounceJoin()
    if not myClass or not mySpellID then return end
    local now = GetTime()
    if now - lastAnnounce < 3 then return end
    lastAnnounce = now
    ReadMyBaseCd()
    local cd = myBaseCd or ALL_INTERRUPTS[mySpellID].cd
    SendLOXX("加入:" .. myClass .. ":" .. mySpellID .. ":" .. cd)
end

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= MSG_PREFIX then return end
    local shortName = Ambiguate(sender, "short")
    local parts = { strsplit(":", message) }
    local command = parts[1]

    -- PING: don't filter self (for diagnostics)
    if command == "PING" then
        local via = parts[2] or "unknown"
        local self_tag = (shortName == myName) and " |cFFFFFF00(SELF)|r" or ""
        print("|cFF00DDDD[LOXX]|r Received PING from |cFF00FF00" .. shortName .. "|r channel=" .. tostring(channel) .. " tag=" .. via .. self_tag)
        return
    end

    -- All other messages: filter self
    if shortName == myName then return end

    if command == "JOIN" then
        local cls = parts[2]
        local spellID = tonumber(parts[3])
        local baseCd = tonumber(parts[4])
        if cls and CLASS_COLORS[cls] and spellID and ALL_INTERRUPTS[spellID] then
            partyAddonUsers[shortName] = partyAddonUsers[shortName] or {}
            partyAddonUsers[shortName].class = cls
            partyAddonUsers[shortName].spellID = spellID
            partyAddonUsers[shortName].cdEnd = partyAddonUsers[shortName].cdEnd or 0
            if baseCd and baseCd > 0 then
                partyAddonUsers[shortName].baseCd = baseCd
            end
            AnnounceJoin()
        end
    elseif command == "CAST" then
        local cd = tonumber(parts[2])
        if cd and cd > 0 and partyAddonUsers[shortName] then
            partyAddonUsers[shortName].cdEnd = GetTime() + cd
            partyAddonUsers[shortName].baseCd = cd
        end
    elseif command == "PING" then
        local via = parts[2] or "unknown"
        print("|cFF00DDDD[LOXX]|r Received PING from |cFF00FF00" .. shortName .. "|r via channel=" .. tostring(channel) .. " tag=" .. via)
    end
end

local function OnSpellCastSucceeded(unit, castGUID, spellID, isParty, cleanName)
    if isParty and cleanName and spellID then
        local now = GetTime()
        -- Resolve alias (e.g., 1276467 Fel Ravager summon → 132409 Spell Lock)
        local resolvedID = SPELL_ALIASES[spellID] or spellID
        if partyAddonUsers[cleanName] then
            local info = partyAddonUsers[cleanName]
            -- Check if it's an extra kick first (check both original and resolved ID)
            local isExtra = false
            if info.extraKicks then
                for _, ek in ipairs(info.extraKicks) do
                    if resolvedID == ek.spellID or spellID == ek.spellID then
                        ek.cdEnd = now + ek.baseCd
                        isExtra = true
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r " .. cleanName .. " used extra kick " .. ek.name .. " → CD=" .. ek.baseCd .. "s (spellID=" .. spellID .. " resolved=" .. resolvedID .. ")")
                        end
                        break
                    end
                end
            end
            if not isExtra then
                -- If this is a different interrupt than primary, auto-add as extra
                if info.spellID and resolvedID ~= info.spellID and ALL_INTERRUPTS[resolvedID] then
                    if not info.extraKicks then info.extraKicks = {} end
                    -- Check it's not already there
                    local found = false
                    for _, ek in ipairs(info.extraKicks) do
                        if ek.spellID == resolvedID then found = true; break end
                    end
                    if not found then
                        local ekData = ALL_INTERRUPTS[resolvedID]
                        table.insert(info.extraKicks, {
                            spellID = resolvedID,
                            baseCd = ekData.cd,
                            cdEnd = now + ekData.cd,
                            name = ekData.name,
                        })
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r Auto-added extra kick for " .. cleanName .. ": " .. ekData.name .. " CD=" .. ekData.cd .. "s")
                        end
                    else
                        -- Update existing extra kick
                        for _, ek in ipairs(info.extraKicks) do
                            if ek.spellID == resolvedID then
                                ek.cdEnd = now + ek.baseCd
                                break
                            end
                        end
                    end
                else
                    -- Primary kick
                    local baseCd = info.baseCd or (ALL_INTERRUPTS[resolvedID] and ALL_INTERRUPTS[resolvedID].cd) or 15
                    info.cdEnd = now + baseCd
                    info.lastKickTime = now
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r " .. cleanName .. " used kick → CD=" .. baseCd .. "s (pending confirm)")
                    end
                end
            end
        else
            -- Don't auto-register players known to have no interrupt
            if noInterruptPlayers[cleanName] then return end
            local ok, _, cls = pcall(UnitClass, unit)
            if ok and cls and CLASS_COLORS[cls] then
                -- Also check role: skip healers (except shaman)
                local role = UnitGroupRolesAssigned(unit)
                if role == "HEALER" and cls ~= "SHAMAN" then
                    noInterruptPlayers[cleanName] = true
                    return
                end
                partyAddonUsers[cleanName] = {
                    class = cls,
                    spellID = spellID,
                    baseCd = ALL_INTERRUPTS[spellID] and ALL_INTERRUPTS[spellID].cd or 15,
                    cdEnd = now + (ALL_INTERRUPTS[spellID] and ALL_INTERRUPTS[spellID].cd or 15),
                    lastKickTime = now,
                }
            end
        end
        return
    end

    -- Own kicks (player or pet for warlock)
    if unit ~= "player" and unit ~= "pet" then return end
    if not ALL_INTERRUPTS[spellID] then return end

    -- Check if it's an extra kick
    if myExtraKicks[spellID] then
        myExtraKicks[spellID].cdEnd = GetTime() + myExtraKicks[spellID].baseCd
        if spyMode then
            print("|cFF00DDDD[SPY]|r Own extra kick: " .. (myExtraKicks[spellID].name or "?") .. " CD=" .. myExtraKicks[spellID].baseCd)
        end
        return
    end

    -- If this is a DIFFERENT interrupt than our primary, auto-add as extra
    if mySpellID and spellID ~= mySpellID then
        local data = ALL_INTERRUPTS[spellID]
        myExtraKicks[spellID] = { baseCd = data.cd, cdEnd = GetTime() + data.cd }
        if spyMode then
            print("|cFF00DDDD[SPY]|r Auto-added extra kick: " .. data.name .. " CD=" .. data.cd)
        end
        return
    end

    local cd = myCachedCD or myBaseCd or ALL_INTERRUPTS[spellID].cd
    myKickCdEnd = GetTime() + cd
    SendLOXX("CAST:" .. cd)
end

local function TryCacheCD()
    -- C_Spell.GetSpellCooldown is restricted in Midnight.
    -- Base CDs come from the CLASS_INTERRUPTS table; no API call needed.
end

local function CleanPartyList()
    if testMode then return end
    local currentNames = {}
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then currentNames[UnitName(u)] = true end
    end
    for name in pairs(partyAddonUsers) do
        if not currentNames[name] then partyAddonUsers[name] = nil end
    end
    -- Clean inspect caches for people who left
    for name in pairs(noInterruptPlayers) do
        if not currentNames[name] then
            noInterruptPlayers[name] = nil
            inspectedPlayers[name] = nil
        end
    end
    for name in pairs(inspectedPlayers) do
        if not currentNames[name] then inspectedPlayers[name] = nil end
    end
    AnnounceJoin()
end

-- Auto-register party members by class (no addon comms needed!)
-- This is the key to working in M+ where SendAddonMessage is blocked
local HEALER_KEEPS_KICK = {
    SHAMAN  = true, -- Resto Shaman keeps Wind Shear
}

local function AutoRegisterPartyByClass()
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then
            local name = UnitName(u)
            local _, cls = UnitClass(u)
            if name and cls and CLASS_INTERRUPTS[cls] then
                if not partyAddonUsers[name] and not noInterruptPlayers[name] then
                    -- Skip healers from classes that lose their kick as healer
                    local role = UnitGroupRolesAssigned(u)
                    if role == "HEALER" and not HEALER_KEEPS_KICK[cls] then
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r Skipping " .. name .. " (" .. cls .. " HEALER) - no kick expected")
                        end
                    else
                        local kickInfo = CLASS_INTERRUPTS[cls]
                        partyAddonUsers[name] = {
                            class = cls,
                            spellID = kickInfo.id,
                            baseCd = kickInfo.cd,
                            cdEnd = 0,
                        }
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r Auto-registered " .. name .. " (" .. cls .. ") " .. kickInfo.name .. " CD=" .. kickInfo.cd)
                        end
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- Inspect party members for spec + talents (before M+ key)
------------------------------------------------------------
local function ScanInspectTalents(unit)
    local name = UnitName(unit)
    if not name then return end
    local info = partyAddonUsers[name]
    if not info then return end

    -- 1) Get spec → override interrupt if needed, or remove if no interrupt
    local specID = GetInspectSpecialization(unit)
    if specID and specID > 0 then
        -- Remove talent-checked extra kicks (will be re-added if talent found)
        if info.extraKicks and SPEC_EXTRA_KICKS[specID] then
            for _, extraSpec in ipairs(SPEC_EXTRA_KICKS[specID]) do
                if extraSpec.talentCheck then
                    for j = #info.extraKicks, 1, -1 do
                        if info.extraKicks[j].spellID == extraSpec.id then
                            table.remove(info.extraKicks, j)
                            if spyMode then
                                print("|cFF00DDDD[SPY]|r Removed " .. extraSpec.name .. " from " .. name .. " (re-inspecting)")
                            end
                        end
                    end
                end
            end
        end
        -- Check if this spec has NO interrupt
        if SPEC_NO_INTERRUPT[specID] then
            partyAddonUsers[name] = nil
            inspectedPlayers[name] = true
            noInterruptPlayers[name] = true
            if spyMode then
                print("|cFF00DDDD[SPY]|r " .. name .. " has no interrupt (specID=" .. specID .. ") → removed")
            end
            return
        end
        local override = SPEC_INTERRUPT_OVERRIDES[specID]
        if override then
            local applyOverride = true
            -- For pet-based overrides, check if the correct pet is active
            if override.isPet then
                -- Find the pet unit for this party member
                local petUnit = nil
                if unit == "player" then
                    petUnit = "pet"
                else
                    local idx = unit:match("party(%d)")
                    if idx then petUnit = "partypet" .. idx end
                end
                if petUnit and UnitExists(petUnit) then
                    local family = UnitCreatureFamily(petUnit)
                    -- Axe Toss = Felguard only. If Felhunter/Imp/etc, skip override
                    if override.id == 119914 and family and family ~= "Felguard" then
                        applyOverride = false
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r Spec override " .. override.name .. " SKIPPED for " .. name .. " (pet=" .. tostring(family) .. ", not Felguard)")
                        end
                    end
                elseif petUnit and not UnitExists(petUnit) then
                    -- No pet out → skip pet override
                    applyOverride = false
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r Spec override " .. override.name .. " SKIPPED for " .. name .. " (no pet)")
                    end
                end
            end
            if applyOverride then
                info.spellID = override.id
                info.baseCd = override.cd
                if spyMode then
                    print("|cFF00DDDD[SPY]|r Spec override for " .. name .. ": " .. override.name .. " CD=" .. override.cd .. " (specID=" .. specID .. ")")
                end
            else
                -- Fall back to default warlock kick (Spell Lock)
                local fallbackID = 19647
                if ALL_INTERRUPTS[fallbackID] then
                    info.spellID = fallbackID
                    info.baseCd = ALL_INTERRUPTS[fallbackID].cd
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r Fallback for " .. name .. ": Spell Lock CD=" .. info.baseCd)
                    end
                end
            end
        end
        -- Add extra kicks for this spec
        local extraSpecs = SPEC_EXTRA_KICKS[specID]
        if extraSpecs then
            if not info.extraKicks then info.extraKicks = {} end
            for _, extraSpec in ipairs(extraSpecs) do
                -- If talentCheck is set, skip here — will be added during talent tree scan
                if not extraSpec.talentCheck then
                    local found = false
                    for _, ek in ipairs(info.extraKicks) do
                        if ek.spellID == extraSpec.id then found = true; break end
                    end
                    if not found then
                        table.insert(info.extraKicks, {
                            spellID = extraSpec.id,
                            baseCd = extraSpec.cd,
                            cdEnd = 0,
                            name = extraSpec.name,
                            icon = extraSpec.icon,
                        })
                        if spyMode then
                            print("|cFF00FF00[SPY]|r " .. name .. " spec extra kick: " .. extraSpec.name .. " CD=" .. extraSpec.cd .. "s")
                        end
                    end
                elseif spyMode then
                    print("|cFF00DDDD[SPY]|r " .. name .. " extra kick " .. extraSpec.name .. " deferred to talent scan (check " .. extraSpec.talentCheck .. ")")
                end
            end
        end
    end

    -- 2) Scan talent tree for CD-reduction talents
    local configID = -1 -- Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
    local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not ok or not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then
        if spyMode then print("|cFF00DDDD[SPY]|r No trait config for " .. name) end
        return
    end

    local treeID = configInfo.treeIDs[1]
    local ok2, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    if not ok2 or not nodeIDs then
        if spyMode then print("|cFF00DDDD[SPY]|r No tree nodes for " .. name) end
        return
    end

    if spyMode then
        print("|cFF00DDDD[SPY]|r Scanning " .. #nodeIDs .. " talent nodes for " .. name)
    end

    for _, nodeID in ipairs(nodeIDs) do
        local ok3, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok3 and nodeInfo and nodeInfo.activeEntry and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
            local entryID = nodeInfo.activeEntry.entryID
            if entryID then
                local ok4, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
                if ok4 and entryInfo and entryInfo.definitionID then
                    local ok5, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                    if ok5 and defInfo and defInfo.spellID then
                        -- Check passive CD reductions
                        -- In WoW 12.0+, defInfo.spellID may be a secret value that
                        -- can't be used as a numeric table key. Try numeric first,
                        -- then fall back to a string-keyed version of each table.
                        local defSpellID = defInfo.spellID
                        local defSpellStr = nil
                        do
                            local sok, s = pcall(tostring, defSpellID)
                            if sok then defSpellStr = s end
                        end
                        local talent = (pcall(function() return CD_REDUCTION_TALENTS[defSpellID] end) and CD_REDUCTION_TALENTS[defSpellID])
                            or (defSpellStr and CD_REDUCTION_TALENTS_STR[defSpellStr])
                        if talent then
                            local newCd
                            if talent.pctReduction then
                                -- Percentage reduction (e.g., Interwoven Threads: -10%)
                                newCd = info.baseCd * (1 - talent.pctReduction / 100)
                                newCd = math.floor(newCd + 0.5) -- round
                            else
                                -- Flat reduction
                                newCd = info.baseCd - talent.reduction
                            end
                            if newCd < 1 then newCd = 1 end
                            info.baseCd = newCd
                            if spyMode then
                                print("|cFF00FF00[SPY]|r " .. name .. " has |cFFFFFF00" .. talent.name .. "|r → CD adjusted to " .. newCd .. "s")
                            end
                        end
                        -- Check conditional CD reductions (on successful kick)
                        local onKick = (pcall(function() return CD_ON_KICK_TALENTS[defSpellID] end) and CD_ON_KICK_TALENTS[defSpellID])
                            or (defSpellStr and CD_ON_KICK_TALENTS_STR[defSpellStr])
                        if onKick then
                            info.onKickReduction = onKick.reduction
                            if spyMode then
                                print("|cFF00FF00[SPY]|r " .. name .. " has |cFFFFFF00" .. onKick.name .. "|r → -" .. onKick.reduction .. "s on successful kick")
                            end
                        end
                        -- Check extra kick talents (second interrupt ability)
                        local extra = (pcall(function() return EXTRA_KICK_TALENTS[defSpellID] end) and EXTRA_KICK_TALENTS[defSpellID])
                            or (defSpellStr and EXTRA_KICK_TALENTS_STR[defSpellStr])
                        if extra then
                            if not info.extraKicks then info.extraKicks = {} end
                            table.insert(info.extraKicks, {
                                spellID = extra.id,
                                baseCd = extra.cd,
                                cdEnd = 0,
                                name = extra.name,
                            })
                            if spyMode then
                                print("|cFF00FF00[SPY]|r " .. name .. " has |cFFFFFF00" .. extra.name .. "|r → extra kick CD=" .. extra.cd .. "s")
                            end
                        end
                        -- Check SPEC_EXTRA_KICKS with talentCheck (e.g., Grimoire: Fel Ravager)
                        if specID and SPEC_EXTRA_KICKS[specID] then
                            for _, extraSpec in ipairs(SPEC_EXTRA_KICKS[specID]) do
                                local matchesTalent = false
                                if extraSpec.talentCheck then
                                    local ok1, eq1 = pcall(function() return extraSpec.talentCheck == defSpellID end)
                                    if ok1 and eq1 then matchesTalent = true end
                                    if not matchesTalent and defSpellStr then
                                        matchesTalent = (tostring(extraSpec.talentCheck) == defSpellStr)
                                    end
                                end
                                if matchesTalent then
                                    if not info.extraKicks then info.extraKicks = {} end
                                    local found = false
                                    for _, ek in ipairs(info.extraKicks) do
                                        if ek.spellID == extraSpec.id then found = true; break end
                                    end
                                    if not found then
                                        table.insert(info.extraKicks, {
                                            spellID = extraSpec.id,
                                            baseCd = extraSpec.cd,
                                            cdEnd = 0,
                                            name = extraSpec.name,
                                            icon = extraSpec.icon,
                                        })
                                        if spyMode then
                                            print("|cFF00FF00[SPY]|r " .. name .. " has talent " .. (defSpellStr or "?") .. " → extra kick " .. extraSpec.name .. " CD=" .. extraSpec.cd .. "s")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    inspectedPlayers[name] = true
    if spyMode then
        print("|cFF00DDDD[SPY]|r Inspect done for " .. name .. " → " .. (ALL_INTERRUPTS[info.spellID] and ALL_INTERRUPTS[info.spellID].name or "?") .. " CD=" .. info.baseCd)
    end
end

local function ProcessInspectQueue()
    if inspectBusy then return end
    while #inspectQueue > 0 do
        local unit = table.remove(inspectQueue, 1)
        if UnitExists(unit) and UnitIsConnected(unit) then
            local name = UnitName(unit)
            if name and not inspectedPlayers[name] then
                inspectBusy = true
                inspectUnit = unit
                NotifyInspect(unit)
                if spyMode then
                    print("|cFF00DDDD[SPY]|r NotifyInspect(" .. unit .. ") → " .. name)
                end
                return
            end
        end
    end
end

local function QueuePartyInspect()
    inspectQueue = {}
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then
            local name = UnitName(u)
            if name and not inspectedPlayers[name] then
                table.insert(inspectQueue, u)
            end
        end
    end
    ProcessInspectQueue()
end
------------------------------------------------------------
-- Compute bar layout from frame size
------------------------------------------------------------
local function GetBarLayout()
    local fw = db.frameWidth
    local titleH = db.showTitle and 20 or 0
    local barH = math.max(12, db.barHeight)
    local iconS = barH
    local barW = fw - iconS
    barW = math.max(60, barW)
    local fontSize      = math.max(2, db.nameFontSize  or 12)
    local cdFontSize    = math.max(2, db.readyFontSize or 12)
    local readyFontSize = math.max(2, db.readyTextSize or 12)
    return barW, barH, iconS, fontSize, cdFontSize, titleH, readyFontSize
end

------------------------------------------------------------
-- Update currentMaxBars based on group size
------------------------------------------------------------
local function UpdateMaxBars()
    local groupSize = GetNumGroupMembers()
    local inRaid    = IsInRaid()
    local needed
    if not inRaid then
        needed = 7          -- party (5) + buffer for extra kicks
    elseif groupSize <= 10 then
        needed = 12         -- 10-man raid + buffer
    elseif groupSize <= 20 then
        needed = 22         -- 20-man raid + buffer
    else
        needed = 42         -- 40-man raid + buffer
    end
    needed = math.min(needed, MAX_BARS)
    if needed ~= currentMaxBars then
        currentMaxBars = needed
        return true   -- caller should RebuildBars
    end
    return false
end

------------------------------------------------------------
-- Rebuild bars
------------------------------------------------------------
local function RebuildBars()
    UpdateMaxBars()
    for i = 1, MAX_BARS do
        if bars[i] then
            bars[i]:Hide()
            bars[i]:SetParent(nil)
            bars[i] = nil
        end
    end

    local barW, barH, iconS, fontSize, cdFontSize, titleH, readyFontSzBuild = GetBarLayout()

    mainFrame:SetWidth(db.frameWidth)
    mainFrame:SetAlpha(db.alpha)

    if titleText then
        if db.showTitle then titleText:Show() else titleText:Hide() end
    end
    if mainFrame.titleBand then
        if db.showTitle then mainFrame.titleBand:Show() else mainFrame.titleBand:Hide() end
    end
    if mainFrame.titleSep then
        if db.showTitle then mainFrame.titleSep:Show() else mainFrame.titleSep:Hide() end
    end

    for i = 1, currentMaxBars do
        local yOff
        if db.growUp then
            yOff = (i - 1) * (barH + 1)
        else
            yOff = -(titleH + (i - 1) * (barH + 1))
        end

        local f = CreateFrame("Frame", nil, mainFrame)
        f:SetSize(iconS + barW - 6, barH)
        if db.growUp then
            f:SetPoint("BOTTOMLEFT", 3, yOff)
        else
            f:SetPoint("TOPLEFT", 3, yOff)
        end

        -- Icon
        local ico = f:CreateTexture(nil, "ARTWORK")
        ico:SetSize(iconS, barH)
        ico:SetPoint("LEFT", 0, 0)
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f.icon = ico

        -- Bar background (uniform dark, Details-style)
        local barBg = f:CreateTexture(nil, "BACKGROUND")
        barBg:SetPoint("TOPLEFT", iconS, 0)
        barBg:SetPoint("BOTTOMRIGHT", 0, 0)
        barBg:SetTexture(BAR_TEXTURE)
        barBg:SetVertexColor(0.08, 0.08, 0.08, 1)
        f.barBg = barBg

        -- StatusBar
        local sb = CreateFrame("StatusBar", nil, f)
        sb:SetPoint("TOPLEFT", iconS, 0)
        sb:SetPoint("BOTTOMRIGHT", 0, 0)
        sb:SetStatusBarTexture(BAR_TEXTURE)
        sb:SetStatusBarColor(1, 1, 1, 0.85)
        sb:SetMinMaxValues(0, 1)
        sb:SetValue(0)
        sb:SetFrameLevel(f:GetFrameLevel() + 1)
        f.cdBar = sb

        -- Content layer
        local content = CreateFrame("Frame", nil, f)
        content:SetPoint("TOPLEFT", iconS, 0)
        content:SetPoint("BOTTOMRIGHT", 0, 0)
        content:SetFrameLevel(sb:GetFrameLevel() + 1)

        -- Name text
        local nm = content:CreateFontString(nil, "OVERLAY")
        nm:SetFont(FONT_FACE, fontSize, FONT_FLAGS)
        nm:SetPoint("LEFT", 6, 0)
        nm:SetJustifyH("LEFT")
        nm:SetWidth(barW - 50)
        nm:SetWordWrap(false)
        nm:SetShadowOffset(1, -1)
        nm:SetShadowColor(0, 0, 0, 1)
        f.nameText = nm

        -- Party CD text
        local pcd = content:CreateFontString(nil, "OVERLAY")
        pcd:SetFont(FONT_FACE, cdFontSize, FONT_FLAGS)
        pcd:SetPoint("RIGHT", -6, 0)
        pcd:SetShadowOffset(1, -1)
        pcd:SetShadowColor(0, 0, 0, 1)
        f.partyCdText = pcd

        -- Player CD wrapper + text (taint-safe via SetAlphaFromBoolean)
        local wrap = CreateFrame("Frame", nil, content)
        wrap:SetAllPoints()
        wrap:SetFrameLevel(content:GetFrameLevel() + 1)
        local mycd = wrap:CreateFontString(nil, "OVERLAY")
        mycd:SetFont(FONT_FACE, cdFontSize, FONT_FLAGS)
        mycd:SetPoint("RIGHT", -6, 0)
        mycd:SetShadowOffset(1, -1)
        mycd:SetShadowColor(0, 0, 0, 1)
        f.playerCdWrapper = wrap
        f.playerCdText = mycd
        f.cdFontSz    = cdFontSize
        f.readyFontSz = readyFontSzBuild

        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self)
            if not db.showTooltip then return end
            if not self.ttSpellName then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.ttSpellName, 1, 1, 1)
            if self.ttRem and self.ttRem > 0 then
                GameTooltip:AddLine(string.format("CD: %.1fs / %.0fs", self.ttRem, self.ttBaseCd or 0), 1, 0.82, 0)
            else
                GameTooltip:AddLine("就緒", 0, 1, 0)
            end
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function(self)
            if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        end)

        f:Hide()
        bars[i] = f
    end

    if resizeHandle then resizeHandle:Raise() end
end

------------------------------------------------------------
-- Display update
------------------------------------------------------------
local shouldShowByZone = true -- cached visibility state

local function CheckZoneVisibility()
    local _, instanceType = IsInInstance()
    if instanceType == "party" then
        shouldShowByZone = db.showInDungeon
    elseif instanceType == "arena" then
        shouldShowByZone = db.showInArena
    else
        shouldShowByZone = db.showInOpenWorld
    end
    if mainFrame then
        if shouldShowByZone then
            mainFrame:Show()
        else
            mainFrame:Hide()
        end
    end
end

local function UpdateDisplay()
    if not ready or not shouldShowByZone then return end

    local _, barH, _, _, _, titleH = GetBarLayout()
    local now = GetTime()
    local barIdx = 1

    -- ── Helper: render a party-side bar (partyCdText path) ───────
    local function RenderPartyBar(bar, icon, name, col, baseCd, rem, spellName)
        bar:Show()
        bar.icon:SetTexture(icon)
        bar.playerCdText:Hide()
        bar.playerCdWrapper:SetAlpha(1)
        bar.partyCdText:Show()
        bar.nameText:SetText("|cFFFFFFFF" .. name .. "|r")
        bar.cdBar:SetMinMaxValues(0, baseCd)
        -- Tooltip data
        bar.ttSpellName = spellName
        bar.ttBaseCd    = baseCd
        if rem > 0.5 then
            bar.cdBar:SetValue(rem)
            bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.85)
            bar.partyCdText:SetFont(FONT_FACE, bar.cdFontSz,   FONT_FLAGS)
            bar.partyCdText:SetText(string.format("%.0f", rem))
            bar.partyCdText:SetTextColor(1, 1, 1)
            bar.ttRem = rem
        else
            bar.cdBar:SetMinMaxValues(0, 1)
            bar.cdBar:SetValue(1)
            bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.35)
            bar.partyCdText:SetFont(FONT_FACE, bar.readyFontSz, FONT_FLAGS)
            bar.partyCdText:SetText(db.showReady and "就緒" or "")
            bar.partyCdText:SetTextColor(0.2, 1.0, 0.2)
            bar.ttRem = 0
        end
    end

    -- ── 1. PLAYER'S OWN BAR (always first) ───────────────────────
    local mySpellData = mySpellID and ALL_INTERRUPTS[mySpellID]
    if mySpellData then
        local bar = bars[barIdx]
        bar:Show()
        bar.icon:SetTexture(mySpellData.icon)
        local col = CLASS_COLORS[myClass] or { 1, 1, 1 }
        bar.nameText:SetText("|cFFFFFFFF" .. (myName or "?") .. "|r")
        bar.ttSpellName = mySpellData.name
        bar.ttBaseCd    = myBaseCd or mySpellData.cd

        if myKickCdEnd > now then
            local cdRemaining = myKickCdEnd - now
            bar.partyCdText:Hide()
            bar.playerCdText:Show()
            bar.playerCdText:SetFont(FONT_FACE, bar.cdFontSz, FONT_FLAGS)
            bar.playerCdText:SetText(string.format("%.0f", cdRemaining))
            bar.playerCdText:SetTextColor(1, 1, 1)
            bar.cdBar:SetMinMaxValues(0, myBaseCd or mySpellData.cd)
            bar.cdBar:SetValue(cdRemaining)
            bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.85)
            bar.playerCdWrapper:SetAlpha(1)
            wasOnCd["__self__"] = true
            bar.ttRem = cdRemaining
        else
            if wasOnCd["__self__"] and db.soundOnReady then
                PlaySound(db.soundID or 8960, "Master")
            end
            wasOnCd["__self__"] = false
            bar.playerCdText:Hide()
            bar.playerCdWrapper:SetAlpha(1)
            bar.partyCdText:Show()
            bar.partyCdText:SetFont(FONT_FACE, bar.readyFontSz, FONT_FLAGS)
            bar.partyCdText:SetText(db.showReady and "就緒" or "")
            bar.partyCdText:SetTextColor(0.2, 1.0, 0.2)
            bar.cdBar:SetMinMaxValues(0, 1)
            bar.cdBar:SetValue(1)
            bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.35)
            bar.ttRem = 0
        end
        barIdx = barIdx + 1
    end

    -- ── 2. OWN EXTRA KICKS (e.g. Demo: Spell Lock + Fel Ravager) ─
    for ekKey, ekInfo in pairs(myExtraKicks) do
        if barIdx > currentMaxBars then break end
        local ekData = ALL_INTERRUPTS[ekKey]
        local ekIcon = ekInfo.icon or (ekData and ekData.icon)
        if ekIcon or ekData then
            local bar = bars[barIdx]
            bar:Show()
            bar.icon:SetTexture(ekIcon or (ekData and ekData.icon))
            local col = CLASS_COLORS[myClass] or { 1, 1, 1 }
            bar.nameText:SetText("|cFFFFFFFF" .. (myName or "?") .. "|r")
            bar.ttSpellName = ekInfo.name or (ekData and ekData.name) or "?"
            bar.ttBaseCd    = ekInfo.baseCd

            if ekInfo.cdEnd > now then
                local ekRem = ekInfo.cdEnd - now
                bar.partyCdText:Hide()
                bar.playerCdText:Show()
                bar.playerCdText:SetFont(FONT_FACE, bar.cdFontSz, FONT_FLAGS)
                bar.playerCdText:SetText(string.format("%.0f", ekRem))
                bar.playerCdText:SetTextColor(1, 1, 1)
                bar.cdBar:SetMinMaxValues(0, ekInfo.baseCd)
                bar.cdBar:SetValue(ekRem)
                bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.85)
                bar.playerCdWrapper:SetAlpha(1)
                bar.ttRem = ekRem
            else
                bar.playerCdText:Hide()
                bar.playerCdWrapper:SetAlpha(1)
                bar.partyCdText:Show()
                bar.partyCdText:SetFont(FONT_FACE, bar.readyFontSz, FONT_FLAGS)
                bar.partyCdText:SetText(db.showReady and "就緒" or "")
                bar.partyCdText:SetTextColor(0.2, 1.0, 0.2)
                bar.cdBar:SetMinMaxValues(0, 1)
                bar.cdBar:SetValue(1)
                bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.35)
                bar.ttRem = 0
            end
            barIdx = barIdx + 1
        end
    end

    -- ── 3. PARTY BARS — collected then sorted ────────────────────
    -- Sort: READY first; within READY shorter baseCd first (more precious);
    --       within ON CD soonest-ready first.
    local partyEntries = {}
    for name, info in pairs(partyAddonUsers) do
        local ok, data = pcall(function() return info.spellID and ALL_INTERRUPTS[info.spellID] end)
        if ok and data then
            local rem = 0
            if info.cdEnd > now then rem = info.cdEnd - now end
            local baseCd = info.baseCd or data.cd
            table.insert(partyEntries, {
                kind    = "party",
                name    = name, info = info, data = data,
                rem     = rem,  baseCd = baseCd,
                isReady = (rem <= 0.5),
            })
        elseif spyMode and info.spellID then
            print("|cFFFF4400[LOXX]|r Unknown spellID=" .. tostring(info.spellID) .. " for " .. name)
        end

        if info.extraKicks then
            local col = CLASS_COLORS[info.class] or { 1, 1, 1 }
            for _, ek in ipairs(info.extraKicks) do
                local okEk, ekData = pcall(function()
                    return ek.spellID and ALL_INTERRUPTS[ek.spellID]
                end)
                local ekIcon = ek.icon or (okEk and ekData and ekData.icon)
                if ekIcon or (okEk and ekData) then
                    local ekRem = 0
                    if ek.cdEnd > now then ekRem = ek.cdEnd - now end
                    table.insert(partyEntries, {
                        kind    = "partyExtra",
                        name    = name, info = info, ek = ek,
                        ekData  = okEk and ekData, ekIcon = ekIcon,
                        ekRem   = ekRem, baseCd = ek.baseCd,
                        isReady = (ekRem <= 0.5), col = col,
                    })
                end
            end
        end
    end

    table.sort(partyEntries, function(a, b)
        if a.isReady ~= b.isReady then return a.isReady end
        if a.isReady then
            local aB, bB = (a.baseCd or 0), (b.baseCd or 0)
            if aB ~= bB then return aB < bB end
        else
            local aR = (a.kind == "party") and a.rem or a.ekRem
            local bR = (b.kind == "party") and b.rem or b.ekRem
            -- Snap to 0.1s grid: prevents bars from swapping every frame
            -- when two CDs expire nearly simultaneously (common in M+ chains).
            local aSnap = math.floor(aR * 10 + 0.5)
            local bSnap = math.floor(bR * 10 + 0.5)
            if aSnap ~= bSnap then return aSnap < bSnap end
        end
        return (a.name or "") < (b.name or "")  -- stable: alphabetical tiebreak
    end)

    for _, e in ipairs(partyEntries) do
        if barIdx > currentMaxBars then break end
        local bar = bars[barIdx]
        if e.kind == "party" then
            local col = CLASS_COLORS[e.info.class] or { 1, 1, 1 }
            RenderPartyBar(bar, e.data.icon, e.name, col, e.baseCd, e.rem, e.data.name)
            if e.rem <= 0.5 then
                if wasOnCd[e.name] and db.soundOnReady then
                    PlaySound(db.soundID or 8960, "Master")
                end
                wasOnCd[e.name] = false
            else
                wasOnCd[e.name] = true
            end
        else -- partyExtra
            local col = e.col
            local icon = e.ekIcon or (e.ekData and e.ekData.icon)
            local spName = (e.ekData and e.ekData.name) or (e.ek.name) or "?"
            RenderPartyBar(bar, icon, e.name, col, e.baseCd, e.ekRem, spName)
        end
        barIdx = barIdx + 1
    end

    for i = barIdx, currentMaxBars do bars[i]:Hide() end

    -- Auto-fit height to visible bars (skip during resize)
    if not isResizing then
        local numVisible = barIdx - 1
        if numVisible > 0 then
            local x = mainFrame:GetLeft()
            if db.growUp then
                local y = mainFrame:GetBottom()
                mainFrame:ClearAllPoints()
                mainFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            else
                local y = mainFrame:GetTop()
                mainFrame:ClearAllPoints()
                mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
            end
            mainFrame:SetHeight(titleH + numVisible * (barH + 1))
        end
    end
end

------------------------------------------------------------
-- Find my interrupt spell (check all possible for class/spec)
------------------------------------------------------------
local function FindMyInterrupt()
    local oldSpellID = mySpellID
    mySpellID = nil
    myIsPetSpell = false
    -- Preserve existing cdEnd values
    local oldExtraKicks = myExtraKicks
    myExtraKicks = {}

    -- Check if my spec has no interrupt (e.g., Resto Druid, Holy Priest)
    local specIndex = GetSpecialization()
    local specID = nil
    if specIndex then
        specID = GetSpecializationInfo(specIndex)
        if specID and SPEC_NO_INTERRUPT[specID] then
            if spyMode then
                print("|cFF00DDDD[SPY]|r My spec " .. specID .. " has no interrupt")
            end
            mySpellID = nil
            if oldSpellID then myCachedCD = nil; myBaseCd = nil end
            return
        end
    end

    -- Spec override for primary kick (e.g., Demo warlock → Axe Toss)
    if specID and SPEC_INTERRUPT_OVERRIDES[specID] then
        local override = SPEC_INTERRUPT_OVERRIDES[specID]
        -- For pet spells, verify the pet actually has this spell
        if override.isPet then
            local petKnown = false
            local method = "none"

            -- Method 1: IsSpellKnown(id, true) - pet spellbook
            if IsSpellKnown(override.id, true) then
                petKnown = true; method = "IsSpellKnown(pet)"
            end
            -- Method 2: Check actual pet spell ID (89766 = Axe Toss)
            if not petKnown and override.petSpellID and IsSpellKnown(override.petSpellID, true) then
                petKnown = true; method = "IsSpellKnown(petSpell)"
            end
            -- Method 3: IsSpellKnown(id) - player side (Command Demon wrapper)
            if not petKnown and IsSpellKnown(override.id) then
                petKnown = true; method = "IsSpellKnown(player)"
            end
            -- Method 4: IsPlayerSpell
            if not petKnown then
                local ok, result = pcall(IsPlayerSpell, override.id)
                if ok and result then petKnown = true; method = "IsPlayerSpell" end
            end
            -- Method 5: Check if pet exists and has Felguard spells
            if not petKnown and override.petSpellID and UnitExists("pet") then
                local ok, result = pcall(IsPlayerSpell, override.petSpellID)
                if ok and result then petKnown = true; method = "IsPlayerSpell(petSpell)" end
            end

            if spyMode then
                print("|cFF00DDDD[SPY]|r Pet override check: " .. override.name .. " → " .. method .. " petKnown=" .. tostring(petKnown))
            end

            if petKnown then
                mySpellID = override.id
                myBaseCd = override.cd
                myIsPetSpell = true
                if spyMode then
                    print("|cFF00DDDD[SPY]|r My spec override: " .. override.name .. " CD=" .. override.cd .. " (pet detected)")
                end
            else
                if spyMode then
                    local family = UnitExists("pet") and UnitCreatureFamily("pet") or "no pet"
                    print("|cFF00DDDD[SPY]|r Spec override " .. override.name .. " SKIPPED (pet=" .. tostring(family) .. ")")
                end
            end
        else
            mySpellID = override.id
            myBaseCd = override.cd
            myIsPetSpell = false
            if spyMode then
                print("|cFF00DDDD[SPY]|r My spec override: " .. override.name .. " CD=" .. override.cd)
            end
        end
    end

    -- Pre-add extra kicks by spec (only if the talent is actually known)
    if specID and SPEC_EXTRA_KICKS[specID] then
        for _, extra in ipairs(SPEC_EXTRA_KICKS[specID]) do
            -- If talentCheck is set, check that spell instead (e.g., check Grimoire: Fel Ravager talent, not Spell Lock)
            local checkID = extra.talentCheck or extra.id
            local known = IsSpellKnown(checkID) or IsSpellKnown(checkID, true)
            if not known then
                local ok, result = pcall(IsPlayerSpell, checkID)
                if ok and result then known = true end
            end
            if known then
                local oldCdEnd = oldExtraKicks[extra.id] and oldExtraKicks[extra.id].cdEnd or 0
                myExtraKicks[extra.id] = {
                    baseCd = extra.cd,
                    cdEnd = oldCdEnd,
                    name = extra.name,
                    icon = extra.icon,
                    talentCheck = extra.talentCheck,
                }
                if spyMode then
                    print("|cFF00DDDD[SPY]|r My spec extra kick: " .. extra.name .. " CD=" .. extra.cd .. " (talent " .. checkID .. " known)")
                end
            elseif spyMode then
                print("|cFF00DDDD[SPY]|r Spec extra kick " .. extra.name .. " NOT known (talent " .. checkID .. " missing)")
            end
        end
    end

    -- Build set of spell IDs managed by SPEC_EXTRA_KICKS (skip them in auto-detect)
    local specManagedSpells = {}
    if specID and SPEC_EXTRA_KICKS[specID] then
        for _, extra in ipairs(SPEC_EXTRA_KICKS[specID]) do
            specManagedSpells[extra.id] = true
        end
    end

    local spellList = CLASS_INTERRUPT_LIST[myClass]
    if not spellList then return end

    -- Find primary kick (if not set by spec override) and extra kicks
    for _, sid in ipairs(spellList) do
        local known = IsSpellKnown(sid) or IsSpellKnown(sid, true)
        -- Also try IsPlayerSpell for talent-granted abilities
        if not known then
            local ok, result = pcall(IsPlayerSpell, sid)
            if ok and result then known = true end
        end
        if known then
            if not mySpellID then
                mySpellID = sid
            elseif sid ~= mySpellID and not myExtraKicks[sid] and not specManagedSpells[sid] then
                -- Don't add spells managed by SPEC_EXTRA_KICKS (talent check handles those)
                local data = ALL_INTERRUPTS[sid]
                if data then
                    local oldCdEnd = oldExtraKicks[sid] and oldExtraKicks[sid].cdEnd or 0
                    myExtraKicks[sid] = { baseCd = data.cd, cdEnd = oldCdEnd }
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r Found extra kick: " .. data.name .. " CD=" .. data.cd)
                    end
                end
            end
        end
    end

    -- Cache correct icon for pet spells using C_Spell on the actual pet version
    -- 119914 = Command Demon wrapper, 89766 = actual Axe Toss pet spell
    local PET_SPELL_ICONS = {
        [119914] = 89766,  -- Axe Toss: use pet version for correct icon
    }
    if mySpellID and PET_SPELL_ICONS[mySpellID] and ALL_INTERRUPTS[mySpellID] then
        local petSpellID = PET_SPELL_ICONS[mySpellID]
        local ok, tex = pcall(C_Spell.GetSpellTexture, petSpellID)
        if ok and tex then
            ALL_INTERRUPTS[mySpellID].icon = tex
            if spyMode then
                print("|cFF00DDDD[SPY]|r Cached icon for " .. mySpellID .. " from pet spell " .. petSpellID .. " → " .. tostring(tex))
            end
        end
    end

    -- Only reset cached CD if spell changed
    if mySpellID ~= oldSpellID then
        myCachedCD = nil
        if not myBaseCd and mySpellID then ReadMyBaseCd() end
    end

    -- Scan own talents for CD reductions (Interwoven Threads etc.)
    if mySpellID then
        local configID = nil
        if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
            local ok0, cid = pcall(C_ClassTalents.GetActiveConfigID)
            if ok0 and cid then configID = cid end
        end
        if configID then
            local ok1, configInfo = pcall(C_Traits.GetConfigInfo, configID)
            if ok1 and configInfo and configInfo.treeIDs and #configInfo.treeIDs > 0 then
                local treeID = configInfo.treeIDs[1]
                local ok2, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
                if ok2 and nodeIDs then
                    for _, nodeID in ipairs(nodeIDs) do
                        local ok3, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                        if ok3 and nodeInfo and nodeInfo.activeEntry and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
                            local entryID = nodeInfo.activeEntry.entryID
                            if entryID then
                                local ok4, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
                                if ok4 and entryInfo and entryInfo.definitionID then
                                    local ok5, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                                    if ok5 and defInfo and defInfo.spellID then
                                        -- defInfo.spellID may be a secret value in 12.0; try string fallback
                                        local defSpellStr2 = nil
                                        do local sok, s = pcall(tostring, defInfo.spellID); if sok then defSpellStr2 = s end end
                                        local talent = (pcall(function() return CD_REDUCTION_TALENTS[defInfo.spellID] end) and CD_REDUCTION_TALENTS[defInfo.spellID])
                                            or (defSpellStr2 and CD_REDUCTION_TALENTS_STR[defSpellStr2])
                                        if talent and talent.affects == mySpellID then
                                            if talent.pctReduction then
                                                local newCd = (myBaseCd or ALL_INTERRUPTS[mySpellID].cd) * (1 - talent.pctReduction / 100)
                                                myBaseCd = math.floor(newCd + 0.5)
                                            elseif talent.reduction then
                                                myBaseCd = (myBaseCd or ALL_INTERRUPTS[mySpellID].cd) - talent.reduction
                                            end
                                            if myBaseCd < 1 then myBaseCd = 1 end
                                            if spyMode then
                                                print("|cFF00DDDD[SPY]|r Own talent: " .. talent.name .. " → CD=" .. myBaseCd)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- Config panel
------------------------------------------------------------

-- Compatibility helper: create a labeled slider without deprecated templates.
-- Layout:   [Text centered above]
--  [Low]  ====track/thumb====  [High]
local function MakeSlider(name, parent)
    local s = CreateFrame("Slider", name, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetHitRectInsets(0, 0, -10, -10)

    -- Track: native WoW slider background texture (tiled)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    track:SetHorizTile(true)
    track:SetPoint("LEFT",  0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(8)

    -- Thumb: native WoW diamond button
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetSize(32, 32)
    s:SetThumbTexture(thumb)

    -- Left arrow < indicator (native WoW style)
    local leftArr = s:CreateTexture(nil, "ARTWORK")
    leftArr:SetTexture("Interface\\Buttons\\UI-SliderBar-Arrow")
    leftArr:SetSize(10, 10)
    leftArr:SetPoint("RIGHT", s, "LEFT", -3, 0)
    leftArr:SetTexCoord(0, 0.5, 0, 1)

    -- Right arrow > indicator (horizontally flipped)
    local rightArr = s:CreateTexture(nil, "ARTWORK")
    rightArr:SetTexture("Interface\\Buttons\\UI-SliderBar-Arrow")
    rightArr:SetSize(10, 10)
    rightArr:SetPoint("LEFT", s, "RIGHT", 3, 0)
    rightArr:SetTexCoord(1, 0.5, 0, 1)

    -- .Text: current value label, centered above the slider
    local t = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("BOTTOM", s, "TOP", 0, 2)
    t:SetJustifyH("CENTER")
    s.Text = t

    -- .Low: min label, below slider left
    local loLbl = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    loLbl:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
    s.Low = loLbl

    -- .High: max label, below slider right
    local hiLbl = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hiLbl:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
    s.High = hiLbl

    return s
end

local function CreateCheckbox(parent, label, x, y, key)
    -- UICheckButtonTemplate is the 12.0-compatible replacement for the
    -- deprecated InterfaceOptionsCheckButtonTemplate.
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    -- UICheckButtonTemplate uses .text (lowercase), not .Text
    local cbLabel = cb.text or cb.Text
    if cbLabel then cbLabel:SetText(label) end
    cb:SetChecked(db[key])
    cb:SetScript("OnClick", function(self)
        db[key] = self:GetChecked() and true or false
        RebuildBars()
    end)
    return cb
end

local function CreateConfigPanel()
    if configFrame then
        if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end
        return
    end

    local PW, PH = 600, 560
    local MID    = 300   -- x divider between left and right columns

    -- Column layout constants
    local L_X1   = 14   -- left column section label x
    local L_CBX1 = 20   -- left col checkbox column 1
    local L_CBX2 = 152  -- left col checkbox column 2
    local SL_XL  = 52   -- left col slider x
    local SL_W   = 210  -- left col slider width
    local R_X1   = 314  -- right column section label x
    local R_CBX1 = 314  -- right col checkbox column 1
    local R_CBX2 = 446  -- right col checkbox column 2

    -- Standard Blizzard dialog frame (native WoW style — no custom backgrounds)
    configFrame = CreateFrame("Frame", "LoxxConfigFrame", UIParent, "BasicFrameTemplate")
    configFrame:SetSize(PW, PH)
    configFrame:SetPoint("CENTER")
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop",  configFrame.StopMovingOrSizing)
    configFrame:SetClampedToScreen(true)
    -- Hide native template title; replaced by a bigger custom header cartouche.
    if configFrame.TitleText then configFrame.TitleText:SetText("") end

    -- Header cartouche: dark gold band (y=-22 → y=-74, 52px tall)
    local hdr = configFrame:CreateTexture(nil, "BACKGROUND", nil, 2)
    hdr:SetTexture(FLAT_TEX)
    hdr:SetVertexColor(0.12, 0.09, 0.02, 1)
    hdr:SetPoint("TOPLEFT",  0, -22)
    hdr:SetPoint("TOPRIGHT", 0, -22)
    hdr:SetHeight(52)

    local hdrLineTop = configFrame:CreateTexture(nil, "BORDER")
    hdrLineTop:SetTexture(FLAT_TEX)
    hdrLineTop:SetVertexColor(0.87, 0.73, 0.37, 0.75)
    hdrLineTop:SetPoint("TOPLEFT",  0, -22)
    hdrLineTop:SetPoint("TOPRIGHT", 0, -22)
    hdrLineTop:SetHeight(1)

    local hdrLineBot = configFrame:CreateTexture(nil, "BORDER")
    hdrLineBot:SetTexture(FLAT_TEX)
    hdrLineBot:SetVertexColor(0.87, 0.73, 0.37, 0.75)
    hdrLineBot:SetPoint("TOPLEFT",  0, -74)
    hdrLineBot:SetPoint("TOPRIGHT", 0, -74)
    hdrLineBot:SetHeight(1)

    local hdrTitle = configFrame:CreateFontString(nil, "OVERLAY")
    hdrTitle:SetFont(FONT_FACE, 28, FONT_FLAGS)
    hdrTitle:SetShadowOffset(2, -2)
    hdrTitle:SetShadowColor(0, 0, 0, 1)
    hdrTitle:SetPoint("TOP", 0, -34)
    hdrTitle:SetJustifyH("CENTER")
    hdrTitle:SetText("|cFFFFD100Loxx 斷法追蹤器|r")

    -- Left-column section label: gold text + thin gold rule to divider
    local function SectionLabelL(text, yOff)
        local lbl = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", L_X1, yOff)
        lbl:SetText("|cFFFFD100" .. text .. "|r")
        local rule = configFrame:CreateTexture(nil, "ARTWORK")
        rule:SetTexture(FLAT_TEX)
        rule:SetVertexColor(0.87, 0.73, 0.37, 0.35)
        rule:SetPoint("LEFT",  lbl, "RIGHT", 6, 0)
        rule:SetPoint("RIGHT", configFrame, "LEFT", MID - 10, 0)
        rule:SetHeight(1)
    end

    -- Right-column section label: gold text + thin gold rule to frame edge
    local function SectionLabelR(text, yOff)
        local lbl = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", R_X1, yOff)
        lbl:SetText("|cFFFFD100" .. text .. "|r")
        local rule = configFrame:CreateTexture(nil, "ARTWORK")
        rule:SetTexture(FLAT_TEX)
        rule:SetVertexColor(0.87, 0.73, 0.37, 0.35)
        rule:SetPoint("LEFT",  lbl, "RIGHT", 6, 0)
        rule:SetPoint("RIGHT", configFrame, "RIGHT", -14, 0)
        rule:SetHeight(1)
    end

    -- Full-width thin separator
    local function Sep(yOff)
        local rule = configFrame:CreateTexture(nil, "ARTWORK")
        rule:SetTexture(FLAT_TEX)
        rule:SetVertexColor(0.45, 0.38, 0.22, 0.4)
        rule:SetPoint("TOPLEFT",  8, yOff)
        rule:SetPoint("TOPRIGHT", -8, yOff)
        rule:SetHeight(1)
    end

    -- Vertical divider between the two columns
    local div = configFrame:CreateTexture(nil, "ARTWORK")
    div:SetTexture(FLAT_TEX)
    div:SetVertexColor(0.45, 0.38, 0.22, 0.5)
    div:SetPoint("TOPLEFT",    configFrame, "TOPLEFT", MID,     -76)
    div:SetPoint("BOTTOMLEFT", configFrame, "TOPLEFT", MID,     -456)
    div:SetWidth(2)
    local div2 = configFrame:CreateTexture(nil, "ARTWORK")
    div2:SetTexture(FLAT_TEX)
    div2:SetVertexColor(0.45, 0.38, 0.22, 0.5)
    div2:SetPoint("TOPLEFT",    configFrame, "TOPLEFT", MID + 1, -76)
    div2:SetPoint("BOTTOMLEFT", configFrame, "TOPLEFT", MID + 1, -456)
    div2:SetWidth(1)

    -- ── LEFT COLUMN ──────────────────────────────────────────────

    -- DISPLAY
    local yL = -82
    SectionLabelL("顯示", yL)

    yL = yL - 22
    local alphaSlider = MakeSlider("LOXX_Slider_alpha", configFrame)
    alphaSlider:SetPoint("TOPLEFT", SL_XL, yL)
    alphaSlider:SetSize(SL_W, 26)
    alphaSlider:SetMinMaxValues(0.3, 1.0)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetValue(db.alpha)
    alphaSlider.Text:SetText("透明度: " .. string.format("%.0f%%", db.alpha * 100))
    alphaSlider.Low:SetText("30%")
    alphaSlider.High:SetText("100%")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        db.alpha = value
        self.Text:SetText("透明度: " .. string.format("%.0f%%", value * 100))
        if mainFrame then mainFrame:SetAlpha(value) end
    end)

    -- OPTIONS
    yL = yL - 48
    SectionLabelL("選項", yL)

    yL = yL - 24
    CreateCheckbox(configFrame, "顯示標題",    L_CBX1, yL, "showTitle")
    CreateCheckbox(configFrame, "往上增長",   L_CBX2, yL, "growUp")

    yL = yL - 28
    CreateCheckbox(configFrame, "鎖定位置", L_CBX1, yL, "locked")
    CreateCheckbox(configFrame, "顯示就緒",    L_CBX2, yL, "showReady")

    -- FONT SIZES (range 2–32)
    yL = yL - 40
    SectionLabelL("字體大小", yL)

    yL = yL - 22
    local initNameFont = math.max(2, db.nameFontSize or 12)
    local nameSlider = MakeSlider("LOXX_Slider_nameFont", configFrame)
    nameSlider:SetPoint("TOPLEFT", SL_XL, yL)
    nameSlider:SetSize(SL_W, 26)
    nameSlider:SetMinMaxValues(2, 32)
    nameSlider:SetValueStep(1)
    nameSlider:SetObeyStepOnDrag(true)
    nameSlider:SetValue(initNameFont)
    nameSlider.Text:SetText("名字大小: " .. tostring(initNameFont))
    nameSlider.Low:SetText("2")
    nameSlider.High:SetText("32")
    nameSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.nameFontSize = value
        self.Text:SetText("名字大小: " .. tostring(value))
        RebuildBars()
    end)

    yL = yL - 48
    local initCdFont = math.max(2, db.readyFontSize or 12)
    local cdSlider = MakeSlider("LOXX_Slider_cdFont", configFrame)
    cdSlider:SetPoint("TOPLEFT", SL_XL, yL)
    cdSlider:SetSize(SL_W, 26)
    cdSlider:SetMinMaxValues(2, 32)
    cdSlider:SetValueStep(1)
    cdSlider:SetObeyStepOnDrag(true)
    cdSlider:SetValue(initCdFont)
    cdSlider.Text:SetText("冷卻大小: " .. tostring(initCdFont))
    cdSlider.Low:SetText("2")
    cdSlider.High:SetText("32")
    cdSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.readyFontSize = value
        self.Text:SetText("冷卻大小: " .. tostring(value))
        RebuildBars()
    end)

    yL = yL - 48
    local initReadyFont = math.max(2, db.readyTextSize or 12)
    local readySlider = MakeSlider("LOXX_Slider_readyFont", configFrame)
    readySlider:SetPoint("TOPLEFT", SL_XL, yL)
    readySlider:SetSize(SL_W, 26)
    readySlider:SetMinMaxValues(2, 32)
    readySlider:SetValueStep(1)
    readySlider:SetObeyStepOnDrag(true)
    readySlider:SetValue(initReadyFont)
    readySlider.Text:SetText("就緒大小: " .. tostring(initReadyFont))
    readySlider.Low:SetText("2")
    readySlider.High:SetText("32")
    readySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.readyTextSize = value
        self.Text:SetText("就緒大小: " .. tostring(value))
        RebuildBars()
    end)

    -- ── RIGHT COLUMN ─────────────────────────────────────────────

    local function VisCheck(parent, label, x, y, key)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        local cbLabel = cb.text or cb.Text
        if cbLabel then cbLabel:SetText(label) end
        cb:SetChecked(db[key])
        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            CheckZoneVisibility()
        end)
        return cb
    end

    -- SHOW IN
    local yR = -82
    SectionLabelR("顯示在", yR)

    yR = yR - 24
    VisCheck(configFrame, "地下城",   R_CBX1, yR, "showInDungeon")
    VisCheck(configFrame, "競技場",      R_CBX2, yR, "showInArena")

    yR = yR - 28
    VisCheck(configFrame, "開放世界", R_CBX1, yR, "showInOpenWorld")

    -- SOUND
    yR = yR - 40
    SectionLabelR("音效", yR)

    yR = yR - 24
    local soundCb = CreateCheckbox(configFrame, "就緒時播放音效", R_CBX1, yR, "soundOnReady")
    local soundLbl = soundCb.text or soundCb.Text
    if soundLbl then soundLbl:SetTextColor(1, 0.82, 0) end

    -- Sound selector: checkboxes with mutual exclusion.
    -- Replaces deprecated UIDropDownMenuTemplate which causes taint in Midnight 12.0.
    local soundBtns = {}
    for i, sound in ipairs(SOUND_LIST) do
        yR = yR - 26
        local rb = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
        rb:SetPoint("TOPLEFT", R_CBX1, yR)
        local rbLabel = rb.text or rb.Text
        if rbLabel then rbLabel:SetText(sound.name) end
        rb.soundID = sound.id
        rb:SetChecked(db.soundID == sound.id)
        rb:SetScript("OnClick", function(self)
            db.soundID = self.soundID
            PlaySound(self.soundID, "Master")
            for _, other in ipairs(soundBtns) do
                other:SetChecked(other == self)
            end
        end)
        soundBtns[i] = rb
    end

    -- UI
    yR = yR - 40
    SectionLabelR("介面", yR)

    yR = yR - 24
    CreateCheckbox(configFrame, "滑鼠停留顯示提示", R_CBX1, yR, "showTooltip")

    -- ── FOOTER ───────────────────────────────────────────────────
    Sep(-466)

    local resetBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 28)
    resetBtn:SetPoint("BOTTOM", 0, 52)
    resetBtn:SetText("重置回預設")
    resetBtn:SetScript("OnClick", function()
        for k, v in pairs(DEFAULTS) do db[k] = v end
        ApplyAutoScale()
        CheckZoneVisibility()
        configFrame:Hide()
        configFrame = nil
        RebuildBars()
        CreateConfigPanel()
    end)

    local info = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    info:SetPoint("BOTTOM", 0, 30)
    info:SetText("拖拉右下角的拖把以改變追蹤器大小")

    configFrame:Show()
end

------------------------------------------------------------
-- Create main frame + resize handle (from ADDON_LOADED)
------------------------------------------------------------
local function CreateUI()
    mainFrame = CreateFrame("Frame", "LOXXMainFrame", UIParent)
    mainFrame:SetSize(db.frameWidth, 200)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    mainFrame:SetAlpha(db.alpha)
    mainFrame:SetResizable(true)
    mainFrame:SetResizeBounds(80, 40, 600, 2000)

    -- Background
    local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(FLAT_TEX)
    bg:SetVertexColor(0.06, 0.06, 0.06, 0.95)

    local GR, GG, GB = 0.87, 0.73, 0.37  -- kept for titleSep colour

    -- Title header band (warm dark like Details)
    local titleBand = mainFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    titleBand:SetTexture(FLAT_TEX)
    titleBand:SetVertexColor(0.09, 0.07, 0.03, 1)
    titleBand:SetPoint("TOPLEFT", 0, 0)
    titleBand:SetPoint("TOPRIGHT", 0, 0)
    titleBand:SetHeight(20)
    mainFrame.titleBand = titleBand

    -- Gold separator line below title
    local titleSep = mainFrame:CreateTexture(nil, "BORDER")
    titleSep:SetTexture(FLAT_TEX)
    titleSep:SetVertexColor(GR, GG, GB, 0.9)
    titleSep:SetPoint("TOPLEFT", 0, -20)
    titleSep:SetPoint("TOPRIGHT", 0, -20)
    titleSep:SetHeight(1)
    mainFrame.titleSep = titleSep

    -- Title (gold, like Details)
    titleText = mainFrame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(FONT_FACE, 12, FONT_FLAGS)
    titleText:SetPoint("TOPLEFT", 6, -2)
    titleText:SetPoint("TOPRIGHT", -6, -2)
    titleText:SetHeight(16)
    titleText:SetJustifyH("LEFT")
    titleText:SetJustifyV("MIDDLE")
    titleText:SetText("|cFFFFD100斷法|r")
    if not db.showTitle then titleText:Hide() end

    -- Resize handle (bottom-right corner)
    resizeHandle = CreateFrame("Button", nil, mainFrame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", 0, 0)
    resizeHandle:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    resizeHandle:EnableMouse(true)

    -- Grip dots (Windows-style diagonal triangle)
    local dotPositions = {
        {-2, 2}, {-6, 2}, {-10, 2},  -- bottom row
        {-2, 6}, {-6,  6},            -- middle row
        {-2, 10},                      -- top row
    }
    for _, pos in ipairs(dotPositions) do
        local dot = resizeHandle:CreateTexture(nil, "OVERLAY", nil, 1)
        dot:SetTexture(FLAT_TEX)
        dot:SetSize(2, 2)
        dot:SetVertexColor(0.55, 0.55, 0.65, 0.75)
        dot:SetPoint("BOTTOMRIGHT", pos[1], pos[2])
    end

    -- Live bar-width update during drag (no full rebuild needed)
    mainFrame:SetScript("OnSizeChanged", function(self)
        if not isResizing then return end
        local fw = math.max(1, math.floor(self:GetWidth()))
        for i = 1, currentMaxBars do
            if bars[i] then bars[i]:SetWidth(math.max(1, fw - 6)) end
        end
    end)

    resizeHandle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not db.locked then
            -- Normalize to TOPLEFT anchor so StartSizing("BOTTOMRIGHT") pins
            -- the top-left corner regardless of what UpdateDisplay last set.
            local x = mainFrame:GetLeft()
            local y = mainFrame:GetTop()
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
            isResizing = true
            mainFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        isResizing = false
        db.frameWidth = math.floor(mainFrame:GetWidth())
        -- Count visible bars
        local numVisible = 0
        for i = 1, currentMaxBars do
            if bars[i] and bars[i]:IsShown() then numVisible = numVisible + 1 end
        end
        if numVisible < 1 then numVisible = 1 end
        -- Derive bar height from dragged height / actual visible bars
        local titleH = db.showTitle and 20 or 0
        local dragH = mainFrame:GetHeight() - titleH
        local newBarH = math.floor(dragH / numVisible) - 1
        db.barHeight = math.max(12, newBarH)
        RebuildBars()
    end)

    -- Resize cursor feedback (pcall guards against restricted cursor names in Midnight)
    resizeHandle:SetScript("OnEnter", function()
        pcall(SetCursor, "UI-Cursor-SizeRight")
    end)
    resizeHandle:SetScript("OnLeave", function()
        pcall(ResetCursor)
    end)

    mainFrame:Show()
    -- Normalize anchor to TOPLEFT after first render so GetLeft()/GetTop()
    -- return real pixel coords and StartSizing pins the correct corner.
    C_Timer.After(0, function()
        if mainFrame then
            local x = mainFrame:GetLeft()
            local y = mainFrame:GetTop()
            if x and y then
                mainFrame:ClearAllPoints()
                mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
            end
        end
    end)
    RebuildBars()
end

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------
local function SetupSlash()
    SLASH_LOXX1 = "/loxx"
    SlashCmdList["LOXX"] = function(msg)
        local cmd = (msg or ""):lower():trim()
        if cmd == "show" then
            if mainFrame then mainFrame:Show() end
        elseif cmd == "hide" then
            if mainFrame then mainFrame:Hide() end
        elseif cmd == "config" or cmd == "options" or cmd == "settings" then
            CreateConfigPanel()
        elseif cmd == "lock" then
            db.locked = true
            print("|cFF00DDDD[LOXX]|r 已鎖定")
        elseif cmd == "unlock" then
            db.locked = false
            print("|cFF00DDDD[LOXX]|r 已解鎖")
        elseif cmd == "test" then
            if testMode then
                -- Stop test
                testMode = false
                if testTicker then testTicker:Cancel() testTicker = nil end
                partyAddonUsers = {}
                print("|cFF00DDDD[LOXX]|r 測試模式 |cFFFF4444OFF|r")
            else
                -- Start test with fake players
                testMode = true
                partyAddonUsers = {
                    ["Thralldk"] = { class = "DEATHKNIGHT", spellID = 47528, baseCd = 15, cdEnd = 0 },
                    ["Jainalee"] = { class = "MAGE", spellID = 2139, baseCd = 20, cdEnd = 0 },
                    ["Sylvanash"] = { class = "ROGUE", spellID = 1766, baseCd = 15, cdEnd = 0 },
                }
                -- Simulate random kicks
                testTicker = C_Timer.NewTicker(2, function()
                    if not testMode then return end
                    for name, info in pairs(partyAddonUsers) do
                        local now = GetTime()
                        if info.cdEnd < now and math.random() < 0.3 then
                            info.cdEnd = now + info.baseCd
                        end
                    end
                end)
                print("|cFF00DDDD[LOXX]|r 測試模式 |cFF00FF00ON|r - 3個假玩家。 /loxx test 來停止測試。")
            end
        elseif cmd == "ping" then
            print("|cFF00DDDD[LOXX]|r === PING ===")
            print("  IsInInstance: " .. tostring(IsInInstance()))
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, MSG_PREFIX)
            -- Test PARTY
            local ok1, ret1 = pcall(C_ChatInfo.SendAddonMessage, MSG_PREFIX, "PING:PARTY", "PARTY")
            print("  PARTY -> ok=" .. tostring(ok1) .. " ret=" .. tostring(ret1))
            -- Test WHISPER to each party member
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) then
                    local ok, name, realm = pcall(UnitFullName, unit)
                    if ok and name then
                        local target = (realm and realm ~= "") and (name .. "-" .. realm) or name
                        local ok2, ret2 = pcall(C_ChatInfo.SendAddonMessage, MSG_PREFIX, "PING:WHISPER", "WHISPER", target)
                        print("  WHISPER " .. target .. " -> ok=" .. tostring(ok2) .. " ret=" .. tostring(ret2))
                    end
                end
            end
            print("  Waiting for echo...")
        elseif cmd == "spy" then
            if spyMode then
                spyMode = false
                print("|cFF00DDDD[LOXX]|r Spy mode |cFFFF4444OFF|r")
            else
                spyMode = true
                spyCastCount = 0
                print("|cFF00DDDD[LOXX]|r Spy mode |cFF00FF00ON|r")
                -- Check watcher status
                for i = 1, 4 do
                    local unit = "party" .. i
                    local exists = UnitExists(unit)
                    local name = exists and UnitName(unit) or "?"
                    local hasFrame = partyFrames[i] ~= nil
                    local isReg = hasFrame and partyFrames[i]:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED")
                    print("  " .. unit .. ": exists=" .. tostring(exists) .. " name=" .. tostring(name) .. " frame=" .. tostring(hasFrame) .. " registered=" .. tostring(isReg))
                end
                print("  Ask your mate to cast ANY spell")
                -- Force re-register watchers
                RegisterPartyWatchers()
                AutoRegisterPartyByClass()
                inspectedPlayers = {} -- reset to re-inspect
                noInterruptPlayers = {}
                QueuePartyInspect()
                print("  Watchers re-registered! Inspecting talents...")
            end
        elseif cmd == "debug" then
            print("|cFF00DDDD[LOXX]|r v" .. LOXX_VERSION .. " | " .. tostring(myClass) .. " | CD cached: " .. tostring(myCachedCD))
            for name, info in pairs(partyAddonUsers) do
                local rem = info.cdEnd - GetTime()
                if rem < 0 then rem = 0 end
                local spellName = ALL_INTERRUPTS[info.spellID] and ALL_INTERRUPTS[info.spellID].name or "?"
                local inspected = inspectedPlayers[name] and "inspected" or "not inspected"
                print(string.format("  %s (%s) %s CD=%.0f rem=%.1f [%s]", name, info.class, spellName, info.baseCd, rem, inspected))
            end
        elseif cmd == "help" then
            print("|cFF00DDDD[LOXX]|r /loxx (options) | show | hide | lock | unlock | test | spy | debug")
        else
            -- Default: open config
            CreateConfigPanel()
        end
    end
end

------------------------------------------------------------
-- Initialize
------------------------------------------------------------
local function RegisterBlizzardOptions()
    local panel = CreateFrame("Frame")
    panel.name = "斷法追蹤器"

    local yOff = -16

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, yOff)
    title:SetText("|cFF00DDDDLoxx 斷法追蹤器|r")
    yOff = yOff - 30

    -- Helper: create a checkbox (UICheckButtonTemplate is the 12.0-safe replacement)
    local function MakeCheck(label, dbKey, y)
        local cb = CreateFrame("CheckButton", "LOXX_Blizz_" .. dbKey, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        local cbLabel = cb.text or cb.Text
        if cbLabel then cbLabel:SetText(label) end
        cb:SetChecked(db[dbKey])
        cb:SetScript("OnClick", function(self)
            db[dbKey] = self:GetChecked()
            if dbKey == "showTitle" or dbKey == "growUp" or dbKey == "showReady" then
                RebuildBars()
            end
            if dbKey:find("^show") then
                CheckZoneVisibility()
            end
        end)
        return cb
    end

    -- Display section
    local displayHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 16, yOff)
    displayHeader:SetText("|cFFFFFF00Display|r")
    yOff = yOff - 25

    MakeCheck("顯示標題條", "showTitle", yOff)
    yOff = yOff - 28
    MakeCheck("往上增長", "growUp", yOff)
    yOff = yOff - 28
    MakeCheck("鎖定位置", "locked", yOff)
    yOff = yOff - 28
    MakeCheck("顯示就緒文字", "showReady", yOff)
    yOff = yOff - 40

    -- Font sizes section
    local fontHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontHeader:SetPoint("TOPLEFT", 16, yOff)
    fontHeader:SetText("|cFFFFFF00字體大小|r")
    yOff = yOff - 25

    local initBNF = math.max(2, db.nameFontSize or 12)
    local nameSlider = MakeSlider("LOXX_Blizz_NameFont", panel)
    nameSlider:SetPoint("TOPLEFT", 20, yOff)
    nameSlider:SetSize(250, 18)
    nameSlider:SetMinMaxValues(2, 32)
    nameSlider:SetValueStep(1)
    nameSlider:SetObeyStepOnDrag(true)
    nameSlider:SetValue(initBNF)
    nameSlider.Text:SetText("名字大小: " .. tostring(initBNF))
    nameSlider.Low:SetText("2")
    nameSlider.High:SetText("32")
    nameSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.nameFontSize = value
        self.Text:SetText("名字大小: " .. tostring(value))
        RebuildBars()
    end)
    yOff = yOff - 48

    local initBCF = math.max(2, db.readyFontSize or 12)
    local cdSliderB = MakeSlider("LOXX_Blizz_CdFont", panel)
    cdSliderB:SetPoint("TOPLEFT", 20, yOff)
    cdSliderB:SetSize(250, 18)
    cdSliderB:SetMinMaxValues(2, 32)
    cdSliderB:SetValueStep(1)
    cdSliderB:SetObeyStepOnDrag(true)
    cdSliderB:SetValue(initBCF)
    cdSliderB.Text:SetText("冷卻大小: " .. tostring(initBCF))
    cdSliderB.Low:SetText("2")
    cdSliderB.High:SetText("32")
    cdSliderB:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.readyFontSize = value
        self.Text:SetText("冷卻大小: " .. tostring(value))
        RebuildBars()
    end)
    yOff = yOff - 48

    local initBRF = math.max(2, db.readyTextSize or 12)
    local readySliderB = MakeSlider("LOXX_Blizz_ReadyFont", panel)
    readySliderB:SetPoint("TOPLEFT", 20, yOff)
    readySliderB:SetSize(250, 18)
    readySliderB:SetMinMaxValues(2, 32)
    readySliderB:SetValueStep(1)
    readySliderB:SetObeyStepOnDrag(true)
    readySliderB:SetValue(initBRF)
    readySliderB.Text:SetText("就緒大小: " .. tostring(initBRF))
    readySliderB.Low:SetText("2")
    readySliderB.High:SetText("32")
    readySliderB:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.readyTextSize = value
        self.Text:SetText("就緒大小: " .. tostring(value))
        RebuildBars()
    end)
    yOff = yOff - 48

    -- Visibility section
    local visHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visHeader:SetPoint("TOPLEFT", 16, yOff)
    visHeader:SetText("|cFFFFFF00顯示在|r")
    yOff = yOff - 25

    MakeCheck("地下城(傳奇鑰石與英雄)", "showInDungeon", yOff)
    yOff = yOff - 28
    MakeCheck("開放世界", "showInOpenWorld", yOff)
    yOff = yOff - 28
    MakeCheck("競技場", "showInArena", yOff)
    yOff = yOff - 40

    -- Opacity slider
    local opacityLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", 16, yOff)
    opacityLabel:SetText("|cFFFFFF00透明度|r")
    yOff = yOff - 25

    local alphaSlider = MakeSlider("LOXX_Blizz_Alpha", panel)
    alphaSlider:SetPoint("TOPLEFT", 20, yOff)
    alphaSlider:SetSize(250, 18)
    alphaSlider:SetMinMaxValues(0.3, 1.0)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetValue(db.alpha)
    alphaSlider.Text:SetText(string.format("%.0f%%", db.alpha * 100))
    alphaSlider.Low:SetText("30%")
    alphaSlider.High:SetText("100%")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        db.alpha = value
        self.Text:SetText(string.format("%.0f%%", value * 100))
        if mainFrame then mainFrame:SetAlpha(value) end
    end)
    yOff = yOff - 48

    -- Misc section
    local miscHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    miscHeader:SetPoint("TOPLEFT", 16, yOff)
    miscHeader:SetText("|cFFFFFF00雜項|r")
    yOff = yOff - 25

    MakeCheck("滑鼠停留顯示提示", "showTooltip", yOff)

    -- Register with Settings API (TWW 12.0+)
    if Settings and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = "LoxxInterruptTracker"
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- Compute screen-proportional bar dimensions.
-- GetScreenHeight() returns WoW UI units (already normalized by the game's own
-- UIScale slider), so these values are consistent across all resolutions and
-- display densities without any frame-level SetScale() call.
local function ComputeAutoBarDefaults()
    local screenH = GetScreenHeight() or 768
    screenH = math.max(600, screenH)
    -- Target ~3.5% of the WoW UI height per bar row (≈27px at standard 768-unit height)
    local barH = math.floor(screenH * 0.035)
    barH = math.max(16, math.min(50, barH))
    -- Width: ~8× bar height gives a comfortable readable bar
    local fw = math.max(160, math.min(420, barH * 8))
    return barH, fw
end

local function ApplyAutoScale()
    if not mainFrame then return end
    -- Recompute proportional dimensions and apply them.
    -- NOTE: We do NOT call mainFrame:SetScale(). WoW's UIParent already normalises
    -- coordinates across physical resolutions. Applying a frame-level scale on top
    -- of that causes double-scaling and inconsistent font/bar sizing.
    local barH, fw = ComputeAutoBarDefaults()
    db.barHeight  = barH
    db.frameWidth = fw
    RebuildBars()
end

local function Initialize()
    LOXXSavedVars = LOXXSavedVars or {}
    db = LOXXSavedVars

    -- Update DEFAULTS with screen-proportional sizes before filling SavedVars.
    local autoBarH, autoFW = ComputeAutoBarDefaults()
    DEFAULTS.barHeight  = autoBarH
    DEFAULTS.frameWidth = autoFW

    -- SavedVars schema versioning: fill new keys, remove obsolete ones.
    local savedVer = db.dbVersion or 1
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    if savedVer < LOXX_DB_VERSION then
        -- Remove keys that are no longer in DEFAULTS (avoids stale bloat)
        for k in pairs(db) do
            if k ~= "dbVersion" and DEFAULTS[k] == nil then
                db[k] = nil
            end
        end
    end
    db.dbVersion = LOXX_DB_VERSION

    pcall(C_ChatInfo.RegisterAddonMessagePrefix, MSG_PREFIX)

    local _, cls = UnitClass("player")
    myClass = cls
    myName = UnitName("player")

    DetectElvUI()
    CreateUI()
    RegisterBlizzardOptions()
    SetupSlash()
    FindMyInterrupt()

    ready = true

    if updateTicker then updateTicker:Cancel() end
    updateTicker = C_Timer.NewTicker(0.1, UpdateDisplay)

    -- Periodic re-inspect to detect talent changes on party members (every 30s)
    C_Timer.NewTicker(30, function()
        if not IsInGroup() then return end
        -- Reset inspected flags so next QueuePartyInspect re-checks talents
        for name in pairs(inspectedPlayers) do
            inspectedPlayers[name] = nil
        end
        QueuePartyInspect()
    end)

    C_Timer.After(2, AnnounceJoin)
    print("|cFF00DDDD[Loxx 斷法追蹤器]|r v" .. LOXX_VERSION .. " | /loxx")
end

------------------------------------------------------------
-- MAIN CHUNK (DO NOT TOUCH)
------------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("GROUP_ROSTER_UPDATE")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("CHAT_MSG_ADDON")
ef:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
-- SPELL_UPDATE_COOLDOWN removed (restricted in Midnight)
ef:RegisterEvent("SPELLS_CHANGED")
ef:RegisterEvent("PLAYER_REGEN_ENABLED")
ef:RegisterEvent("INSPECT_READY")
ef:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ef:RegisterEvent("UNIT_PET")
ef:RegisterEvent("ROLE_CHANGED_INFORM")
-- COMBAT_LOG_EVENT_UNFILTERED is restricted in Midnight 12.0: Frame:RegisterEvent()
-- is blocked for this event. CD tracking for non-addon players falls back to
-- the existing UNIT_SPELLCAST_SUCCEEDED timestamp-correlation system.

-- Player's own casts: separate frame with unit filter
local playerCastFrame = CreateFrame("Frame")
playerCastFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
playerCastFrame:SetScript("OnEvent", function(_, _, unit, castGUID, spellID)
    -- Debug: log all player/pet casts in spy mode
    if spyMode and unit == "player" then
        local isInterrupt = ALL_INTERRUPTS[spellID] and "YES" or "no"
        local isExtra = myExtraKicks[spellID] and "YES" or "no"
        print("|cFF00DDDD[SPY]|r PLAYER cast spellID=" .. tostring(spellID) .. " interrupt=" .. isInterrupt .. " extra=" .. isExtra)
    end

    if unit == "pet" then
        if spyMode then
            print("|cFF00DDDD[SPY]|r PET cast detected on unit=pet")
        end

        -- Player's own pet: spell ID should be accessible, but wrap in pcall
        -- in case it is also secret on some Midnight builds.
        if spyMode then
            print("|cFF00DDDD[SPY]|r   pet spellID=" .. tostring(spellID) .. " mySpellID=" .. tostring(mySpellID))
        end

        local ok_lookup, data = pcall(function() return ALL_INTERRUPTS[spellID] end)
        if not ok_lookup then data = nil end
        local usedID = spellID

        if data then
            -- Check if it's an extra kick
            local isExtra = false
            for ekID, ekInfo in pairs(myExtraKicks) do
                if usedID == ekID then
                    ekInfo.cdEnd = GetTime() + ekInfo.baseCd
                    isExtra = true
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r   → EXTRA kick: " .. data.name .. " CD=" .. ekInfo.baseCd)
                    end
                    break
                end
            end
            if not isExtra then
                -- Auto-add as extra if different from primary
                if mySpellID and usedID ~= mySpellID then
                    myExtraKicks[usedID] = { baseCd = data.cd, cdEnd = GetTime() + data.cd }
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r   → AUTO-ADDED extra kick: " .. data.name .. " CD=" .. data.cd)
                    end
                else
                    local cd = myCachedCD or myBaseCd or data.cd
                    myKickCdEnd = GetTime() + cd
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r   → PRIMARY kick: " .. data.name .. " CD=" .. cd)
                    end
                end
            end
        elseif spyMode then
            print("|cFF00DDDD[SPY]|r   → not a known interrupt")
        end
    else
        OnSpellCastSucceeded(unit, castGUID, spellID, false)
    end
end)


-- Track recent party casts for correlation (timestamp per player name)
local recentPartyCasts = {}

-- Handler for mob interrupt detection
local function OnMobInterrupted(unit)
    if spyMode then
        print("|cFF00DDDD[SPY-MOB]|r INTERRUPTED on " .. tostring(unit))
    end

    -- A mob was interrupted! Find who kicked via time correlation
    local now = GetTime()
    local bestName = nil
    local bestDelta = 999

    for name, ts in pairs(recentPartyCasts) do
        local delta = now - ts
        if delta > 1.0 then
            recentPartyCasts[name] = nil
        elseif delta < bestDelta then
            bestDelta = delta
            bestName = name
        end
    end

    if bestName and bestDelta < 1.5 then
        if spyMode then
            print("  |cFF00FF00>>> " .. bestName .. " kicked successfully! (delta=" .. string.format("%.3f", bestDelta) .. "s)|r")
        end

        if partyAddonUsers[bestName] then
            local info = partyAddonUsers[bestName]
            -- Set primary kick on cooldown (timestamp correlation confirmed an interrupt)
            -- This is the fallback path when UNIT_SPELLCAST_SUCCEEDED spell ID is secret.
            local baseCd = info.baseCd or 15
            info.cdEnd = now + baseCd
            -- Apply conditional CD reduction on top (e.g., Coldthirst: -3s on successful kick)
            if info.onKickReduction then
                local newCdEnd = info.cdEnd - info.onKickReduction
                if newCdEnd < now then newCdEnd = now end
                info.cdEnd = newCdEnd
                if spyMode then
                    local rem = newCdEnd - now
                    print("  |cFFFFFF00Coldthirst! CD reduced by " .. info.onKickReduction .. "s → " .. string.format("%.0f", rem) .. "s remaining|r")
                end
            end
        else
            -- Auto-register via class
            if not noInterruptPlayers[bestName] then
                for idx = 1, 4 do
                    local u = "party" .. idx
                    if UnitExists(u) and UnitName(u) == bestName then
                        local _, cls = UnitClass(u)
                        local role = UnitGroupRolesAssigned(u)
                        if cls and CLASS_INTERRUPTS[cls] and not (role == "HEALER" and cls ~= "SHAMAN") then
                            local kickInfo = CLASS_INTERRUPTS[cls]
                            partyAddonUsers[bestName] = {
                                class = cls,
                                spellID = kickInfo.id,
                                baseCd = kickInfo.cd,
                                cdEnd = now + kickInfo.cd,
                            }
                            if spyMode then
                                print("  Registered " .. bestName .. " (" .. cls .. ") CD=" .. kickInfo.cd)
                            end
                        end
                        break
                    end
                end
            end
        end
    elseif spyMode then
        print("  No matching party cast (best=" .. tostring(bestName) .. " delta=" .. string.format("%.3f", bestDelta) .. ")")
    end
end

-- Mob interrupt detection: target, focus, boss units (always tracked in instances),
-- and nameplate units (handled below).
local mobInterruptFrame = CreateFrame("Frame")
mobInterruptFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED",
    "target", "focus",
    "boss1", "boss2", "boss3", "boss4", "boss5")
mobInterruptFrame:SetScript("OnEvent", function(self, event, unit)
    OnMobInterrupted(unit)
end)

-- Nameplate interrupt tracking: one frame per nameplate
local nameplateCastFrames = {}
local nameplateFrame = CreateFrame("Frame")
nameplateFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
nameplateFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
nameplateFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if not nameplateCastFrames[unit] then
            nameplateCastFrames[unit] = CreateFrame("Frame")
        end
        local f = nameplateCastFrames[unit]
        f:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
        f:SetScript("OnEvent", function(_, _, eUnit)
            OnMobInterrupted(eUnit)
        end)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if nameplateCastFrames[unit] then
            nameplateCastFrames[unit]:UnregisterAllEvents()
        end
    end
end)

-- Party event frames: OnValueChanged spell detection + time correlation
RegisterPartyWatchers = function()
    for i = 1, 4 do
        local unit = "party" .. i
        partyFrames[i]:UnregisterAllEvents()
        if UnitExists(unit) then
            partyFrames[i]:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", unit)
            partyFrames[i]:SetScript("OnEvent", function(self, event, eUnit, eCastGUID, eSpellID, eCastBarID)
                local cleanUnit = "party" .. i
                local cleanName = UnitName(cleanUnit)

                -- Store timestamp for correlation backup
                if cleanName then
                    recentPartyCasts[cleanName] = GetTime()
                end

                -- In Midnight, eSpellID is a secret value and cannot be used
                -- as a table index. Detection is handled entirely by
                -- UNIT_SPELLCAST_INTERRUPTED correlation (timestamp above).
                if spyMode then
                    print("|cFF00DDDD[SPY]|r SUCCEEDED " .. cleanUnit .. " (" .. tostring(cleanName) .. ") — timestamp stored for correlation")
                end
            end)
        end
    end
    if spyMode then
        local reg = {}
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then table.insert(reg, u .. "=" .. (UnitName(u) or "?")) end
        end
        print("|cFF00DDDD[SPY]|r Watchers: " .. (#reg > 0 and table.concat(reg, ", ") or "none"))
    end

    -- Pet watchers (Warlock Felhunter Spell Lock, Hunter pet, etc.)
    for i = 1, 4 do
        local petUnit = "partypet" .. i
        local ownerUnit = "party" .. i
        partyPetFrames[i]:UnregisterAllEvents()
        if UnitExists(petUnit) then
            partyPetFrames[i]:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", petUnit)
            partyPetFrames[i]:SetScript("OnEvent", function(self, event, eUnit, eCastGUID, eSpellID, eCastBarID)
                local cleanOwner = "party" .. i
                local cleanName = UnitName(cleanOwner)

                -- Store timestamp for correlation
                if cleanName then
                    recentPartyCasts[cleanName] = GetTime()
                end

                -- In Midnight, eSpellID is a secret value for party pets too.
                -- Timestamp stored above is sufficient for correlation.
                if spyMode then
                    print("|cFF00DDDD[SPY]|r PET SUCCEEDED partypet" .. i .. " (owner=" .. tostring(cleanName) .. ") — timestamp stored")
                end
            end)
        end
    end
end

ef:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        Initialize()
    elseif event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
        OnAddonMessage(arg1, arg2, arg3, arg4)
    -- SPELL_UPDATE_COOLDOWN removed (restricted in Midnight)
    elseif event == "SPELLS_CHANGED" then
        FindMyInterrupt()
        AnnounceJoin()
        -- For warlocks: pet spellbook may not be ready yet, retry
        if myClass == "WARLOCK" then
            C_Timer.After(1.5, FindMyInterrupt)
            C_Timer.After(3.0, FindMyInterrupt)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        TryCacheCD()
    elseif event == "INSPECT_READY" then
        if inspectBusy and inspectUnit then
            local ok, err = pcall(ScanInspectTalents, inspectUnit)
            if not ok and spyMode then
                print("|cFFFF0000[SPY]|r Inspect scan error: " .. tostring(err))
            end
            ClearInspectPlayer()
            inspectBusy = false
            inspectUnit = nil
            C_Timer.After(0.5, ProcessInspectQueue)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local changedUnit = arg1
        if changedUnit and changedUnit ~= "player" then
            local name = UnitName(changedUnit)
            if name then
                inspectedPlayers[name] = nil
                noInterruptPlayers[name] = nil
                -- Re-register with class default
                local _, cls = UnitClass(changedUnit)
                if cls and CLASS_INTERRUPTS[cls] then
                    local kickInfo = CLASS_INTERRUPTS[cls]
                    partyAddonUsers[name] = {
                        class = cls,
                        spellID = kickInfo.id,
                        baseCd = kickInfo.cd,
                        cdEnd = 0,
                        onKickReduction = nil,
                    }
                end
                if spyMode then
                    print("|cFF00DDDD[SPY]|r " .. name .. " changed spec → re-inspecting")
                end
                C_Timer.After(1, QueuePartyInspect)
            end
        end
    elseif event == "UNIT_PET" then
        local unit = arg1
        -- Own pet changed → re-detect our kicks (multiple retries as pet spellbook loads slowly)
        if unit == "player" then
            C_Timer.After(0.5, FindMyInterrupt)
            C_Timer.After(1.5, FindMyInterrupt)
            C_Timer.After(3.0, FindMyInterrupt)
            if spyMode then
                C_Timer.After(3.0, function()
                    print("|cFF00DDDD[SPY]|r Pet changed → primary kick: " .. tostring(mySpellID))
                end)
            end
        end
        -- Party pet changed → re-inspect and re-register watchers
        RegisterPartyWatchers()
        if unit and unit:find("^party") then
            local name = UnitName(unit)
            if name then
                inspectedPlayers[name] = nil
                C_Timer.After(1, QueuePartyInspect)
                if spyMode then
                    print("|cFF00DDDD[SPY]|r " .. name .. " pet changed → re-inspecting")
                end
            end
        end
    elseif event == "ROLE_CHANGED_INFORM" then
        -- Roles changed → remove healers without kick
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then
                local name = UnitName(u)
                local _, cls = UnitClass(u)
                local role = UnitGroupRolesAssigned(u)
                if name and role == "HEALER" and cls ~= "SHAMAN" and partyAddonUsers[name] then
                    partyAddonUsers[name] = nil
                    noInterruptPlayers[name] = true
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r Role changed: " .. name .. " is HEALER (" .. cls .. ") → removed")
                    end
                end
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        CleanPartyList()
        RegisterPartyWatchers()
        AutoRegisterPartyByClass()
        -- Rebuild bars if group size changed category (5 → 10 → 20 → 40)
        if UpdateMaxBars() then RebuildBars() end
        -- Queue inspect for new members (1s delay for units to be ready)
        C_Timer.After(1, QueuePartyInspect)
    elseif event == "PLAYER_ENTERING_WORLD" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, MSG_PREFIX)
        CheckZoneVisibility()
        RegisterPartyWatchers()
        AutoRegisterPartyByClass()
        C_Timer.After(1, AutoRegisterPartyByClass)
        C_Timer.After(2, QueuePartyInspect) -- inspect any not-yet-inspected members
        C_Timer.After(3, function()
            FindMyInterrupt()
            AnnounceJoin()
            AutoRegisterPartyByClass()
        end)
    end
end)
