------------------------------------------------------------
-- 媒體：在地化字型、LSM 字型清單、描邊選項
------------------------------------------------------------
local _, ns = ...

ns.Media = {}
local M = ns.Media

M.WHITE8X8 = "Interface\\BUTTONS\\WHITE8X8"

-- 剛好 n 個實體像素的 UI 單位，基準是**框自己的**有效縮放（P.Pixel 照 UIParent）：
-- 時間軸會 SetScale(display.scale)、預覽縮放到放得下、首領警告跟暴雪框的大小，照 UIParent 算就不是整數像素。
-- ⚠ 要在排版／顯示時呼叫（登入當下縮放還沒定，見 .claude/notes/wow-1px-border-rules.md）
function M.Pixel(frame, n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    if n <= 0 then return 0 end
    -- 警告框錨在暴雪框上：保險起見讀不到或秘密就退回 P.Pixel
    local ok, scale = pcall(frame.GetEffectiveScale, frame)
    scale = ok and ns.Secret.PlainNumber(scale)
    if not (scale and scale > 0) then return ns.P.Pixel(n) end
    return n * PixelUtil.GetPixelToUIUnitFactor() / scale
end

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
