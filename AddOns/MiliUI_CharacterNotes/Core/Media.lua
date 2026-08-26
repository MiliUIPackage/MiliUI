------------------------------------------------------------
-- 媒體：在地化字型、字型清單、強調色、職業標籤
--
-- 零資產檔：字型走暴雪內建路徑，有裝 LibSharedMedia 就多開放玩家自己的字型
-- 給筆記內文用。
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
-- 分身標籤：職業圖示 ＋ 職業色名稱
--
-- 資料來源是自己的 SavedVariables（登入時記下的 meta），不是即時 Unit API，
-- 所以不會踩到 12.1 的身分限制；但 SV 是玩家可以手改的檔案，查表前還是擋一次。
------------------------------------------------------------
local CLASS_ICON_TEX = "Interface\\TargetingFrame\\UI-Classes-Circles"

function M.ClassIconMarkup(classFile, size)
    size = size or 14
    if type(classFile) ~= "string" or ns.issecret(classFile) then return "" end
    local c = CLASS_ICON_TCOORDS[classFile]
    if not c then return "" end
    local function px(v) return math.floor(v * 256 + 0.5) end
    return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t",
        CLASS_ICON_TEX, size, size, px(c[1]), px(c[2]), px(c[3]), px(c[4]))
end

function M.ClassColoredName(name, classFile)
    name = name or "?"
    if type(classFile) ~= "string" or ns.issecret(classFile) then return name end
    local col = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
             or RAID_CLASS_COLORS[classFile]
    if not col then return name end
    return string.format("|cff%02x%02x%02x%s|r",
        col.r * 255, col.g * 255, col.b * 255, name)
end

-- meta = { name, realm, class }。showRealm 只有同名跨服分身才給 true
function M.CharLabel(meta, size, showRealm)
    if type(meta) ~= "table" then return "?" end
    local icon = M.ClassIconMarkup(meta.class, size)
    local name = M.ClassColoredName(meta.name, meta.class)
    local label = (icon ~= "") and (icon .. " " .. name) or name
    if showRealm and type(meta.realm) == "string" and meta.realm ~= "" then
        label = label .. "|cff808080-" .. meta.realm .. "|r"
    end
    return label
end

------------------------------------------------------------
-- 筆記本體的字型物件
--
-- 玩家可以自己挑字型與字級，而筆記的區塊列是**回收再用**的，逐格 SetFont 一來要
-- 記得每一格都設到、二來設定改了還得整批重跑。改用字型物件：設定改一次、
-- 所有掛著它的 FontString 一起變。
--
-- ⚠ 名字要帶插件前綴。CreateFont 撞名會回傳既有物件而不是新的，兩個插件共用
--   同一個名字就會互相蓋掉字級（而且不報錯）。
------------------------------------------------------------
local fontBody  = CreateFont("MiliUINote_Body")
local fontHead  = CreateFont("MiliUINote_Head")
local fontDim   = CreateFont("MiliUINote_Dim")

M.fontBody, M.fontHead, M.fontDim = fontBody, fontHead, fontDim

-- DB 還沒載入時先給一組能看的預設，免得檔案層就有人拿去用而拿到 nil 字型
fontBody:SetFont(DEFAULT_FONT, 12, "")
fontBody:SetTextColor(0.92, 0.92, 0.92)
fontHead:SetFont(DEFAULT_FONT, 13, "")
fontHead:SetTextColor(1, 1, 1)
fontDim:SetFont(DEFAULT_FONT, 11, "")
fontDim:SetTextColor(0.6, 0.6, 0.6)

function M.UpdateFonts()
    local s = ns.db and ns.db.settings
    local path = M.Font(s and s.font)
    local size = (s and s.fontSize) or 12
    fontBody:SetFont(path, size, "")
    fontHead:SetFont(path, size + 1, "")
    fontDim:SetFont(path, math.max(9, size - 1), "")
end
