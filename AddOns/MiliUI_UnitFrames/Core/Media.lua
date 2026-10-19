------------------------------------------------------------
-- 媒體：字型（在地化）、材質、1px 邊框工具
------------------------------------------------------------
local _, ns = ...

local L = ns.L

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
-- 「satin」＝套組自製的長條材質 MiliUI Satin（Media/miliui_satin.png，技能 miliui-satin-texture 的腳本畫的，
-- 五支插件各帶一份同一張圖；2026-10-16 取代原本自帶的 TukTex）。解析一律先查自己的表，查不到才去問 LSM；
-- 同時把自己的材質登記進 LSM，讓別的插件的材質選單也看得到。兩個方向都不依賴外人。
-- 舊 token "tuktex" 當別名（v20 值閘遷移會把存檔改成 "satin"，別名是給匯入的舊字串與遷移跑到之前用的）。
------------------------------------------------------------
M.TEXTURES = {
    satin  = MEDIA_PATH .. "miliui_satin.png",
    tuktex = MEDIA_PATH .. "miliui_satin.png",   -- 舊 token 別名
}

-- 血條疊加層用的貼圖，四個檔案原封不動從 Cell/Media 複製過來
-- （吸收盾／溢盾光暈／治療吸收全部照 Cell 的樣式，不再用暴雪團隊框那張）
M.SHIELD_TEXTURE      = MEDIA_PATH .. "shield"
M.OVERSHIELD_TEXTURE  = MEDIA_PATH .. "overshield"
M.OVERSHIELD_R_TEXTURE = MEDIA_PATH .. "overshield_reversed"
M.DEFAULT_TEXTURE = M.TEXTURES.satin

-- 登記到 LSM 用的顯示名。加前綴是因為 LSM **撞名會被拒絕**，而且失敗是靜默的；
-- 套組其他插件也登記同一個名字＝同一張圖，誰先到都一樣
local LSM_NAME = "MiliUI Satin"

local lsmDone = false
function M.RegisterSharedMedia()
    if lsmDone then return end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return end        -- 沒裝就算了，我們本來就不靠它
    lsmDone = true
    for _, def in ipairs({
        { "statusbar", LSM_NAME, M.TEXTURES.satin },
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
    if token == LSM_NAME then return M.TEXTURES.satin end   -- 別人選了我們登記的名字
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch("statusbar", token, true)
        if path then return path end
    end
    return M.DEFAULT_TEXTURE
end

------------------------------------------------------------
-- 設定面板的下拉選單項
--
-- ⚠ 一定要是**函式**、不能是檔案層的常數表：LibSharedMedia 可能比我們晚載入，
-- 而且別的插件會一路註冊到 PLAYER_LOGIN 之後。表單引擎支援 items 傳函式
-- （見 Options/Controls.lua），開分頁那一刻才求值才列得全。
------------------------------------------------------------
-- 自己的材質永遠排第一（不靠 LSM 也要有東西可選）；LSM 的接在後面。
-- 跳過 LSM_NAME —— 那是我們自己登記出去的同一個檔，兩個名字指同一張圖只會讓人困惑。
function M.BarTextureItems()
    local items = { { text = L["Built-in (Satin)"], value = "satin" } }
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local ok, list = pcall(LSM.List, LSM, "statusbar")
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                if name ~= LSM_NAME and not M.TEXTURES[name] then
                    items[#items + 1] = { text = name, value = name }
                end
            end
        end
    end
    return items
end

function M.FontItems()
    local items = { { text = L["Default (follows client language)"], value = "DEFAULT" } }
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local ok, list = pcall(LSM.List, LSM, "font")
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                items[#items + 1] = { text = name, value = name }
            end
        end
    end
    return items
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
    { text = L["Shield (Blizzard HD)"], value = "blizzard" },
    { text = L["Shield (Gradient)"],         value = "gradient" },
    { text = L["Shield (Soft)"],         value = "soft" },
    { text = L["Shield (Bold)"],         value = "gw2" },
    { text = L["Blizzard Built-in (Nameplate)"],   value = "atlas" },
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
    M.NoSnapBackdrop(frame)
    local c = borderColor or (ns.db and ns.db.global.borderColor) or { r = 0, g = 0, b = 0, a = 1 }
    frame:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
end

-- 邊框實際佔掉的厚度（版面單位）。
-- ⚠ 內容內縮一定要用這個、不能直接用 borderSize：backdrop 的 edgeSize 走 P.Pixel
-- （把 N 個實體像素換算回版面單位），在 Retina／UI 縮放 > 1 的機器上 P.Pixel(1) < 1，
-- 內容卻內縮整整 1 → 邊框內緣和內容外緣對不上，中間露出一圈次像素縫（實測：Mac 上
-- 血條四周有一條若隱若現的細縫）。兩邊都用這個值就永遠貼齊。
function M.BorderInset(borderSize)
    local size = borderSize or (ns.db and ns.db.global.borderSize) or 1
    if size <= 0 then return 0 end
    return ns.P.Pixel(size)
end

-- 關像素貼齊（共用層 P.NoSnap）：框停在小數座標時引擎會把每張貼圖各自捨入，1px 邊
-- 整條變 0 或 2、底／填充跟邊差一格。邊框、跟邊相接的底／填充／圖示、StatusBar 一律過這支；
-- 只用在自己建的物件上。規則：.claude/notes/wow-1px-border-rules.md
function M.NoSnap(obj) return ns.P.NoSnap(obj) end
-- BackdropTemplate 的九張貼圖（SetBackdrop 之後才存在）
function M.NoSnapBackdrop(frame) return ns.P.NoSnapBackdrop(frame) end
