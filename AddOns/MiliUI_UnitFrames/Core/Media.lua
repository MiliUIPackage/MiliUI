------------------------------------------------------------
-- 媒體：字型（在地化）、材質、1px 邊框工具
------------------------------------------------------------
local _, ns = ...

local MEDIA_PATH = "Interface\\AddOns\\MiliUI_UnitFrames\\Media\\"

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

------------------------------------------------------------
-- 內建材質：檔案自己帶、註冊也自己做
--
-- 以前只是把路徑寫死指到自己的 Media/，但「tuktex」這個 token 在 LibSharedMedia
-- 裡是**別的插件**註冊的——那個插件一移除或改名，任何用 token 查表的地方就撲空。
-- 現在：解析一律先查自己的表，查不到才去問 LSM；同時把自己的材質登記進 LSM，
-- 讓別的插件的材質選單也看得到。兩個方向都不再依賴外人。
------------------------------------------------------------
M.TEXTURES = {
    tuktex = MEDIA_PATH .. "tuktex",
}

-- 血條疊加層用的貼圖，四個檔案原封不動從 Cell/Media 複製過來
-- （吸收盾／溢盾光暈／治療吸收全部照 Cell 的樣式，不再用暴雪團隊框那張）
M.SHIELD_TEXTURE      = MEDIA_PATH .. "shield"
M.OVERSHIELD_TEXTURE  = MEDIA_PATH .. "overshield"
M.OVERSHIELD_R_TEXTURE = MEDIA_PATH .. "overshield_reversed"
M.OVERABSORB_TEXTURE  = MEDIA_PATH .. "overabsorb"
M.DEFAULT_TEXTURE = M.TEXTURES.tuktex

-- 登記到 LSM 用的顯示名。加前綴是因為 LSM **撞名會被拒絕**——別人若已經註冊過
-- 「TukTex」，我們沒加前綴就會登記失敗，而且失敗是靜默的
local LSM_NAME = "MiliUI TukTex"

local lsmDone = false
function M.RegisterSharedMedia()
    if lsmDone then return end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return end        -- 沒裝就算了，我們本來就不靠它
    lsmDone = true
    for _, def in ipairs({
        { "statusbar", LSM_NAME, M.TEXTURES.tuktex },
    }) do
        pcall(LSM.Register, LSM, def[1], def[2], def[3])
    end
end
M.RegisterSharedMedia()               -- LSM 若比我們晚載入，Units.lua 會在登入時再叫一次

-- statusbar 材質 token → 路徑
function M.BarTexture(token)
    if not token then return M.DEFAULT_TEXTURE end
    local own = M.TEXTURES[token]
    if own then return own end
    if token == LSM_NAME then return M.TEXTURES.tuktex end   -- 別人選了我們登記的名字
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch("statusbar", token, true)
        if path then return path end
    end
    return M.DEFAULT_TEXTURE
end

-- 套字型：fs, size, flags（"OUTLINE" 等）
function M.SetFont(fs, size, flags, fontToken)
    fs:SetFont(M.Font(fontToken), size or 12, flags or "")
end

-- 疊在長條上的小字用：字級先乘 UIParent 縮放、區域本身忽略父層縮放 →
-- 字形直接落在實體像素格上。小字級（9-10）不這樣做會糊成一團
function M.SetPixelFont(fs, size, flags, fontToken)
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    fs:SetFont(M.Font(fontToken), (size or 12) * scale, flags or "")
    if fs.SetIgnoreParentScale then fs:SetIgnoreParentScale(true) end
end

-- 不可打斷盾牌貼圖。內建四款高解析 PNG（取自 Platynator 的 DPI144 資產，
-- 複製進本插件 Media 才不會被上游更新洗掉），外加暴雪內建 atlas。
M.SHIELD_STYLES = {
    { text = "盾牌（暴雪風高解析）", value = "blizzard" },
    { text = "盾牌（漸層）",         value = "gradient" },
    { text = "盾牌（柔和）",         value = "soft" },
    { text = "盾牌（厚實）",         value = "gw2" },
    { text = "暴雪內建（名條用）",   value = "atlas" },
}
local SHIELD_FILES = {
    blizzard = MEDIA_PATH .. "shield-blizzard.png",
    gradient = MEDIA_PATH .. "shield-gradient.png",
    soft     = MEDIA_PATH .. "shield-soft.png",
    gw2      = MEDIA_PATH .. "shield-gw2.png",
}
function M.SetShieldTexture(tex, style)
    style = style or "blizzard"
    if style == "atlas" then
        tex:SetTexture(nil)
        tex:SetAtlas("nameplates-InterruptShield")
        return
    end
    tex:SetTexture(SHIELD_FILES[style] or SHIELD_FILES.blizzard)
end

-- SetJustifyV 只吃 TOP/MIDDLE/BOTTOM；舊設定值慣用 "CENTER"，統一重映射
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
    frame:SetBackdrop({ edgeFile = M.WHITE8X8, edgeSize = M.BorderInset(size) })
    local c = borderColor or (ns.db and ns.db.global.borderColor) or { r = 0, g = 0, b = 0, a = 1 }
    frame:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
end

-- 邊框實際佔掉的厚度（版面單位）。
-- ⚠ 內容內縮一定要用這個、不能直接用 borderSize：backdrop 的 edgeSize 走 P.Scale
-- （把 N 個實體像素換算回版面單位），在 Retina／UI 縮放 > 1 的機器上 P.Scale(1) < 1，
-- 內容卻內縮整整 1 → 邊框內緣和內容外緣對不上，中間露出一圈次像素縫（實測：Mac 上
-- 血條四周有一條若隱若現的細縫）。兩邊都用這個值就永遠貼齊。
function M.BorderInset(borderSize)
    local size = borderSize or (ns.db and ns.db.global.borderSize) or 1
    if size <= 0 then return 0 end
    return ns.P.Scale(size)
end
