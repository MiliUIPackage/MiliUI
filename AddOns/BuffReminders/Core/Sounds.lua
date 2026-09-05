local _, BR = ...

-- ============================================================================
-- SOUND VALUES
-- ============================================================================
-- One stored string per sound setting, resolved to a value that PlaySoundFile
-- and C_UnitAuras.AddAuraSound both accept. Two namespaces:
--
--   * "blizz:<key>" - a row in Data/AlertSounds.lua, resolved to its file id.
--   * anything else - a LibSharedMedia name. That is the only format the addon
--     ever stored, so saved values from older versions need no migration.

local ipairs = ipairs
local format = string.format

local LSM = LibStub("LibSharedMedia-3.0")
local L = BR.L

local ALERT_PREFIX = "blizz:"
local ALERT_PATTERN = "^blizz:(.+)$"
-- Shared media's silent placeholder. Its value is the number 1, not a file.
local NONE = "None"
-- Dropdown sentinel for "no sound". A real sound name can never collide with it.
local NO_SOUND = "__none"

local LABEL_PREFIX = "CDMSND_"
local CATEGORY_PREFIX = "COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_"

local alertFiles = {}
for _, group in ipairs(BR.ALERT_SOUNDS) do
    for _, sound in ipairs(group.sounds) do
        alertFiles[sound.key] = sound.file
    end
end

---Global string that names one alert sound ("ImpactsLowThud" -> CDMSND_IMPACTS_LOW_THUD).
---scripts/generate-alert-sounds.py fails if a key ever stops following this pattern.
---@param key string
---@return string
local function LabelGlobal(key)
    local spaced = key:gsub("(%d)", "%1_"):gsub("(%l)(%u)", "%1_%2")
    return LABEL_PREFIX .. spaced:upper()
end

local Sounds = {
    NO_SOUND = NO_SOUND,
}

---Playable value for a stored setting.
---@param value string?
---@return string|number|nil sound A file path or a file id
function Sounds.Resolve(value)
    if not value or value == NONE or value == NO_SOUND then
        return nil
    end
    local key = value:match(ALERT_PATTERN)
    if key then
        return alertFiles[key]
    end
    -- Silent fetch: a sound from an addon the player removed resolves to nil
    -- instead of to the shared media default.
    return LSM:Fetch("sound", value, true)
end

---Display name for a stored setting.
---@param value string?
---@return string?
function Sounds.Label(value)
    if not value or value == NO_SOUND then
        return nil
    end
    local key = value:match(ALERT_PATTERN)
    if not key then
        return value
    end
    return _G[LabelGlobal(key)] or key
end

---Dropdown options: no sound, then the shared media names, then the client's own
---alert library by category. The list omits a row this client cannot name, so a
---sound that a patch removes disappears from the list.
---@return table[]
function Sounds.BuildOptions()
    local options = { { label = L["BuffPanel.Sound.None"], value = NO_SOUND } }

    for _, name in ipairs(LSM:List("sound")) do
        if name ~= NONE then
            options[#options + 1] = { label = name, value = name }
        end
    end

    for _, group in ipairs(BR.ALERT_SOUNDS) do
        local categoryText = _G[CATEGORY_PREFIX .. group.category:upper()] or group.category
        for _, sound in ipairs(group.sounds) do
            local text = _G[LabelGlobal(sound.key)]
            if text then
                options[#options + 1] = {
                    label = format("%s: %s", categoryText, text),
                    value = ALERT_PREFIX .. sound.key,
                }
            end
        end
    end

    return options
end

BR.Sounds = Sounds
