------------------------------------------------------------
-- 媒體：字型（在地化）、材質、1px 邊框工具
------------------------------------------------------------
local _, ns = ...

local MEDIA_PATH = "Interface\\AddOns\\MiliUI_Unit_Frame\\Media\\"

-- 在地化字型（FontString 寫死 FRIZQT__ 在 zhTW 會變方框，抄 BloodlustMusic）
local LOCALE_FONTS = {
    zhTW = "Fonts\\blei00d.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    koKR = "Fonts\\2002.TTF",
}
local DEFAULT_FONT = LOCALE_FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF"

ns.Media = {}
local M = ns.Media

M.WHITE8X8 = "Interface\\BUTTONS\\WHITE8X8"

-- token → 實際路徑；"DEFAULT" = 在地化字型。之後可接 LSM。
function M.Font(token)
    if not token or token == "DEFAULT" then return DEFAULT_FONT end
    -- LibSharedMedia 可選整合（有裝其他插件帶 LSM 才會有）
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch("font", token, true)
        if path then return path end
    end
    return DEFAULT_FONT
end

-- statusbar 材質 token → 路徑
function M.BarTexture(token)
    if not token or token == "tuktex" then return MEDIA_PATH .. "tuktex" end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch("statusbar", token, true)
        if path then return path end
    end
    return MEDIA_PATH .. "tuktex"
end

-- 套字型：fs, size, flags（"OUTLINE" 等）
function M.SetFont(fs, size, flags, fontToken)
    fs:SetFont(M.Font(fontToken), size or 12, flags or "")
end

-- SetJustifyV 只吃 TOP/MIDDLE/BOTTOM；Stuf 時代的設定值慣用 "CENTER"，統一重映射
-- （不映射會直接 Lua error，而且炸在 build 迴圈裡）
function M.JustifyV(v)
    if v == "CENTER" then return "MIDDLE" end
    return v or "TOP"
end

-- 1px 細邊框：backdrop 純白貼圖上黑色。edgeOnly 時不填背景。
-- borderSize 讀 global 設定（預設 1）。
function M.ApplyBorder(frame, borderColor, borderSize)
    local size = borderSize or (ns.db and ns.db.global.borderSize) or 1
    if size <= 0 then
        if frame.SetBackdrop then frame:SetBackdrop(nil) end
        return
    end
    frame:SetBackdrop({ edgeFile = M.WHITE8X8, edgeSize = ns.P.Scale(size) })
    local c = borderColor or (ns.db and ns.db.global.borderColor) or { r = 0, g = 0, b = 0, a = 1 }
    frame:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
end
