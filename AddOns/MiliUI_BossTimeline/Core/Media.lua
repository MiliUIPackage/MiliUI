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
function M.OutlineItems()
    local L = ns.L
    return {
        { text = L["None"],          value = "" },
        { text = L["Outline"],       value = "OUTLINE" },
        { text = L["Thick outline"], value = "THICKOUTLINE" },
    }
end
