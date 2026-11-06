------------------------------------------------------------
-- 媒體：在地化字型、長條材質
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
-- 長條材質
--
-- name = nil / "default" → 套組的自動挑選（有 SharedMedia 用它的 normTex，其次
-- DBM 的計時條材質，都沒有就用白貼圖）。這條 4px 高的條看不出材質差異，但既然
-- 玩家可能把它調到 10px，還是把 LSM 的清單開出來當選項。
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

-- 設定頁的材質下拉清單。⚠ 要等 LSM 註冊完才算得準，所以做成函式讓 spec 現算
function M.TextureItems()
    -- 預設 → 米利的材質（別的插件登記進 LSM 的；中文客戶端顯示「米利UI: 緞面」，
    -- 名冊、譯名、順序在 Libs/MiliUIMedia.lua，全套組同一套規則）→ 其餘 LSM
    local items = { { text = ns.L["Default"], value = "default" } }
    local lsm = LSM()
    local own, rest = ns.MiliMedia.TextureItems(lsm and lsm:List("statusbar") or nil)
    for i = 1, #own do items[#items + 1] = own[i] end
    for i = 1, #rest do items[#items + 1] = rest[i] end
    return items
end
