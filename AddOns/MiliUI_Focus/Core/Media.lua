------------------------------------------------------------
-- 媒體：在地化字型、施法條材質、音效播放
------------------------------------------------------------
local _, ns = ...

ns.Media = {}
local M = ns.Media

M.WHITE8X8 = "Interface\\BUTTONS\\WHITE8X8"

-- 在地化字型：FontString 寫死 FRIZQT__ 在 zhTW / zhCN / koKR 會變成方框
local LOCALE_FONTS = {
    zhTW = "Fonts\\blei00d.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    koKR = "Fonts\\2002.TTF",
}
local DEFAULT_FONT = LOCALE_FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF"

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end
M.LSM = LSM

-- token → 字型路徑；nil / "default" = 在地化字型
function M.Font(token)
    if not token or token == "default" or token == "DEFAULT" then return DEFAULT_FONT end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("font", token, true)
        if path then return path end
    end
    return DEFAULT_FONT
end

------------------------------------------------------------
-- 施法條材質：沿用套組原本的自動挑選（有 SharedMedia 用它的 normTex，
-- 其次 DBM 的計時條材質，都沒有就用白貼圖）。這裡不做成選項——
-- 一條 22px 高的施法條看不出材質差異，多一個下拉只是多一個要維護的東西。
------------------------------------------------------------
local barTexture
function M.BarTexture()
    if barTexture then return barTexture end
    if C_AddOns.IsAddOnLoaded("SharedMedia") then
        barTexture = "Interface\\AddOns\\SharedMedia\\statusbar\\normTex"
    elseif C_AddOns.IsAddOnLoaded("DBM-StatusBarTimers") then
        barTexture = "Interface\\AddOns\\DBM-StatusBarTimers\\textures\\default.blp"
    else
        barTexture = M.WHITE8X8
    end
    return barTexture
end

------------------------------------------------------------
-- 音效：數字 = 暴雪 SoundKit ID，字串 = LibSharedMedia 註冊名
------------------------------------------------------------
function M.PlaySoundValue(sound)
    if not sound then return end
    local num = tonumber(sound)
    if num then
        PlaySound(num, "Master")
    elseif type(sound) == "string" then
        local lsm = LSM()
        if lsm then
            local path = lsm:Fetch("sound", sound, true)
            if path then PlaySoundFile(path, "Master") end
        end
    end
end
