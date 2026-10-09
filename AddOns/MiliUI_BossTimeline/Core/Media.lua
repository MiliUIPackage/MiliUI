------------------------------------------------------------
-- 媒體：在地化字型、LSM 字型清單、描邊選項
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

-- 設定頁的字型下拉清單。⚠ 要等 LSM 註冊完才算得準，所以做成函式讓 spec 現算
function M.FontItems()
    local items = { { text = ns.L["Default"], value = "default" } }
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("font")) do
            items[#items + 1] = { text = name, value = name }
        end
    end
    return items
end

-- 描邊：存檔存的是 SetFont 的 flags 字串本身，"" = 不描邊
-- 單色（MONOCHROME）＝關掉反鋸齒，像素字體要它才銳利
function M.OutlineItems()
    local L = ns.L
    return {
        { text = L["None"],          value = "" },
        { text = L["Outline"],       value = "OUTLINE" },
        { text = L["Thick outline"], value = "THICKOUTLINE" },
        { text = L["Monochrome outline"],       value = "MONOCHROME,OUTLINE" },
        { text = L["Monochrome thick outline"], value = "MONOCHROME,THICKOUTLINE" },
    }
end

------------------------------------------------------------
-- 音效：LibSharedMedia 的 sound 清單（套組帶的 SharedMedia 會註冊一大批）
-- 存檔存名稱；nil／"" = 不播
------------------------------------------------------------
function M.Sound(name)
    if not name or name == "" then return end
    local lsm = LSM()
    if lsm then return lsm:Fetch("sound", name, true) end
end

function M.SoundItems()
    local items = { { text = ns.L["None"], value = "" } }
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("sound")) do
            if name ~= "None" then items[#items + 1] = { text = name, value = name } end
        end
    end
    return items
end

------------------------------------------------------------
-- 計時條材質（照 MiliUI_CrusadingStrikes 的挑法：SharedMedia 的 normTex → DBM 的 → 白貼圖）
------------------------------------------------------------
local autoTexture
local function AutoTexture()
    if autoTexture then return autoTexture end
    if C_AddOns.IsAddOnLoaded("SharedMedia") then
        autoTexture = "Interface\\AddOns\\SharedMedia\\statusbar\\normTex"
    elseif C_AddOns.IsAddOnLoaded("DBM-StatusBarTimers") then
        autoTexture = "Interface\\AddOns\\DBM-StatusBarTimers\\textures\\default.blp"
    else
        autoTexture = M.WHITE8X8
    end
    return autoTexture
end

function M.BarTexture(name)
    if not name or name == "default" then return AutoTexture() end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("statusbar", name, true)
        if path then return path end
    end
    return AutoTexture()
end

function M.TextureItems()
    local items = { { text = ns.L["Default"], value = "default" } }
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("statusbar")) do
            items[#items + 1] = { text = name, value = name }
        end
    end
    return items
end
