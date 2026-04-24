--------------------------------------------------------------------------------
-- GameplayCVars
-- 每次載入（PLAYER_LOGIN）時強制套用使用者指定的 CVar 值，
-- 覆蓋遊戲內建選項或其他插件寫入的值。
--
-- 目前支援：
--   deselectOnClick — 點擊地板是否清除目標
--
-- 三種模式：
--   "ignore"  — 不強制，沿用遊戲設定
--   "on"      — 強制設為 1
--   "off"     — 強制設為 0
--------------------------------------------------------------------------------

local MODE_IGNORE = "ignore"
local MODE_ON     = "on"
local MODE_OFF    = "off"

-- 支援的 CVar 清單（未來可擴充）
local CVARS = {
    deselectOnClick = { default = MODE_IGNORE },
}

-- 本次 session 登入時 CVar 的原值。切到「不強制」時還原成這個值，
-- 讓三種模式切換都能立即生效。
local originalValues = {}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.cvarEnforce then MiliUI_DB.cvarEnforce = {} end
    return MiliUI_DB.cvarEnforce
end

local function IsValidMode(mode)
    return mode == MODE_IGNORE or mode == MODE_ON or mode == MODE_OFF
end

local function GetMode(cvar)
    local entry = CVARS[cvar]
    if not entry then return MODE_IGNORE end
    local db = GetDB()
    local mode = db[cvar]
    if not IsValidMode(mode) then
        mode = entry.default
    end
    return mode
end

local function CaptureOriginal(cvar)
    if originalValues[cvar] == nil then
        originalValues[cvar] = GetCVar(cvar)
    end
end

local function ApplyCVar(cvar)
    CaptureOriginal(cvar)
    local mode = GetMode(cvar)
    if mode == MODE_ON then
        SetCVar(cvar, 1)
    elseif mode == MODE_OFF then
        SetCVar(cvar, 0)
    else
        -- IGNORE：還原到本次登入時的原值，讓切換即時生效
        local orig = originalValues[cvar]
        if orig ~= nil then
            SetCVar(cvar, orig)
        end
    end
end

local function SetMode(cvar, mode)
    if not CVARS[cvar] then return end
    if not IsValidMode(mode) then return end
    local db = GetDB()
    db[cvar] = mode
    ApplyCVar(cvar)
end

local function ApplyAll()
    for cvar in pairs(CVARS) do
        ApplyCVar(cvar)
    end
end

-- 暴露 API 給 Settings.lua 使用
MiliUI_CVarEnforce = {
    GetMode   = GetMode,
    SetMode   = SetMode,
    ApplyCVar = ApplyCVar,
    ApplyAll  = ApplyAll,
    MODES = {
        IGNORE = MODE_IGNORE,
        ON     = MODE_ON,
        OFF    = MODE_OFF,
    },
}

-- 每次載入時強制套用一次
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ApplyAll()
end)
