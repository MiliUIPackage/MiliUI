------------------------------------------------------------
-- 媒體：在地化字型、字型清單、強調色
--
-- 零資產檔：字型走暴雪內建路徑，有裝 LibSharedMedia 就多開放玩家自己的字型。
-- （抄 MiliUI_CharacterNotes/Core/Media.lua，去掉它的分身標籤那一段）
------------------------------------------------------------
local _, ns = ...

ns.Media = {}
local M = ns.Media

-- 在地化字型：FontString 寫死 FRIZQT__ 在 zhTW / zhCN / koKR 會變成方框
local LOCALE_FONTS = {
    zhTW = "Fonts\\blei00d.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    koKR = "Fonts\\2002.TTF",
}
local DEFAULT_FONT = LOCALE_FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF"
M.DEFAULT_FONT = DEFAULT_FONT

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end
M.LSM = LSM

-- token → 字型路徑；nil / "default" = 在地化字型
--
-- 解出來的路徑記一份。**只快取問到的**，問不到不記 —— 註冊那支字型的插件可能比
-- 我們晚載入，記了 nil 就永遠退成預設字型。
local fontCache = {}

function M.Font(token)
    if not token or token == "" or token == "default" or token == "DEFAULT" then
        return DEFAULT_FONT
    end
    local cached = fontCache[token]
    if cached then return cached end
    -- 舊設定（或別的插件匯入）可能存的是完整路徑而不是 LibSharedMedia 名稱
    if token:find("[\\/]") then return token end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("font", token, true)
        if path then
            fontCache[token] = path
            return path
        end
    end
    return DEFAULT_FONT
end

------------------------------------------------------------
-- 設定面板的字型清單
--
-- ⚠ 一定要是**函式**、不能是檔案層的常數表：LibSharedMedia 可能比我們晚載入，
-- 而且別的插件會一路註冊到 PLAYER_LOGIN 之後。開分頁那一刻才求值才列得全。
------------------------------------------------------------
local BUILTIN_FONTS = {
    { text = "Friz Quadrata", value = "Fonts\\FRIZQT__.TTF" },
    { text = "Arial Narrow",  value = "Fonts\\ARIALN.TTF" },
    { text = "Skurri",        value = "Fonts\\skurri.TTF" },
    { text = "Morpheus",      value = "Fonts\\MORPHEUS.TTF" },
}

function M.FontItems()
    local items = { { text = ns.L["Default font"], value = "" } }
    local lsm = LSM()
    if lsm then
        local ok, list = pcall(lsm.List, lsm, "font")
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                items[#items + 1] = { text = name, value = name }
            end
            return items
        end
    end
    for _, f in ipairs(BUILTIN_FONTS) do
        items[#items + 1] = f
    end
    return items
end

------------------------------------------------------------
-- 強調色 = 玩家職業色（設定介面的邊框與分頁高亮）
--
-- ⚠ classFile 在 12.1 可能是秘密值，查表前一律先擋——
--   RAID_CLASS_COLORS[secret] 會丟 "cannot be indexed with secret keys"。
--   不過 player token 讀職業是安全的，這裡只是保險。
------------------------------------------------------------
local ar, ag, ab = 0.7, 0.7, 0.7
do
    local cls = ns.playerClass
    if cls and cls ~= "" and not ns.issecret(cls) then
        local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[cls]) or RAID_CLASS_COLORS[cls]
        if c then ar, ag, ab = c.r, c.g, c.b end
    end
end

function M.Accent()
    return ar, ag, ab
end

------------------------------------------------------------
-- 清單列的字型物件
--
-- 清單列是**回收再用**的，逐格 SetFont 一來要記得每一格都設到、二來設定改了
-- 還得整批重跑。改用字型物件：設定改一次，所有掛著它的 FontString 一起變。
--
-- ⚠ 名字要帶插件前綴。CreateFont 撞名會回傳既有物件而不是新的。
------------------------------------------------------------
local fontRow = CreateFont("MiliUIShop_Row")
local fontDim = CreateFont("MiliUIShop_Dim")
local fontNum = CreateFont("MiliUIShop_Num")

M.fontRow, M.fontDim, M.fontNum = fontRow, fontDim, fontNum

-- DB 還沒載入時先給一組能看的預設，免得檔案層就有人拿去用而拿到 nil 字型
fontRow:SetFont(DEFAULT_FONT, 12, "")
fontRow:SetTextColor(0.92, 0.92, 0.92)
fontDim:SetFont(DEFAULT_FONT, 11, "")
fontDim:SetTextColor(0.6, 0.6, 0.6)
fontNum:SetFont(DEFAULT_FONT, 12, "")
fontNum:SetTextColor(0.92, 0.92, 0.92)

function M.UpdateFonts()
    local s = ns.db and ns.db.settings
    local path = M.Font(s and s.font)
    local size = (s and s.fontSize) or 12
    fontRow:SetFont(path, size, "")
    fontDim:SetFont(path, math.max(9, size - 1), "")
    fontNum:SetFont(path, size, "")
end
