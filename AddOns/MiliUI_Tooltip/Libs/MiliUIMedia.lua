------------------------------------------------------------
-- MiliUIMedia：套組自製材質的名冊——登記名、各語系的顯示名、下拉裡的順序
--
-- 全套組的長條材質下拉都照同一套規則（2026-11-06 使用者拍板）：
--   * **登記名**（LibSharedMedia 的 key＝存檔值＝英文顯示名）：`MiliUI <英文名>`，純 ASCII、
--     **永遠不翻**——它是存檔與匯入字串裡的值，也是別家插件材質選單看到的名字，翻了舊存檔就找不到圖。
--   * **顯示名**（只在我們自己的下拉裡）：中文客戶端是 `米利UI: <譯名>`（半形冒號＋一個空白，
--     繁簡各一份譯名）；其他語系照登記名原樣顯示。變體用全形括號接在後面：`米利UI: 彩虹（柔和）`。
--   * **順序**：米利的材質照下面名冊的順序排在最上面；「跟隨…／預設」這種不是材質的項目留在它們前面，
--     「純色」這類保留項接在它們後面，其餘 LibSharedMedia 的照原順序排在最後。
--   * **選單本身要看得到材質**（2026-11-06 使用者指定，照 Cell 的樣式）：每一項帶 `texture`（圖檔路徑），共用層的下拉
--     （MiliUIWidgets 的 W.CreateDropdown）會把那一列鋪上那張圖、收合的本體也鋪選中的那張。做法＝叫 MM.TextureItems
--     時把自己的「存檔值 → 圖檔路徑」解析函式傳進第四個參數；保留項（純色、預設、跟隨…）是消費者自己接的，不帶圖。
--
-- 新增一款材質：在 TEXTURES 加一列（順序＝下拉裡的順序），跑 `python3 .claude/scripts/sync-widgets.py`。
-- 譯名只寫在這裡——**不要**進各插件的語系檔，那樣六支會各翻各的。
--
-- 這是 vendor 複製：每支插件帶一份、各跑各的（只掛 `ns.MiliMedia`、沒有全域），玩家只裝其中一支也能用。
-- 唯一 source 在 MiliUI/Libs/MiliUIMedia/，本體只放 source 不載入。
-- 純資料＋純函式：不碰任何框、不依賴 LibSharedMedia（清單由消費者自己問完再傳進來）。
------------------------------------------------------------
local _, ns = ...

local MM = {}
ns.MiliMedia = MM

-- 顯示名的前綴（沒列到的語系＝照登記名原樣顯示）
local PREFIX = {
    zhTW = "米利UI: ",
    zhCN = "米利UI: ",
}

-- 名冊：順序＝下拉裡的順序。第一款是套組所有長條的預設材質
local TEXTURES = {
    { name = "MiliUI Satin",        zhTW = "緞面",         zhCN = "缎面" },
    { name = "MiliUI Rainbow",      zhTW = "彩虹",         zhCN = "彩虹" },
    { name = "MiliUI Rainbow Soft", zhTW = "彩虹（柔和）", zhCN = "彩虹（柔和）" },
    { name = "MiliUI Cosmos",       zhTW = "宇宙星辰",     zhCN = "宇宙星辰" },
    { name = "MiliUI Lightning",    zhTW = "閃電",         zhCN = "闪电" },
    { name = "MiliUI Lava",         zhTW = "熔岩",         zhCN = "熔岩" },
    { name = "MiliUI Flame",        zhTW = "火焰",         zhCN = "火焰" },
}
MM.TEXTURES = TEXTURES

local BY_NAME = {}
for i, def in ipairs(TEXTURES) do BY_NAME[def.name] = i end

local function ClientLocale()
    return type(GetLocale) == "function" and GetLocale() or "enUS"
end

-- name 是不是套組自製的材質（登記名）
function MM.IsOwnTexture(name)
    return type(name) == "string" and BY_NAME[name] ~= nil
end

-- 登記名 → 這個客戶端的顯示名；不是自製的（或這個語系沒譯名）回登記名本身
function MM.TextureLabel(name, locale)
    local i = type(name) == "string" and BY_NAME[name]
    if not i then return name end
    locale = locale or ClientLocale()
    local prefix, text = PREFIX[locale], TEXTURES[i][locale]
    if prefix and text then return prefix .. text end
    return name
end

-- LibSharedMedia 的名稱清單 → 兩段下拉項 `own, rest`（都是 { text =, value =, texture = } 的陣列）：
--   own   米利的材質，照名冊順序、顯示名在地化
--   rest  其餘的，照傳進來的順序、原名
-- 消費者自己把保留項（純色、預設…）接在中間或前面。
--
-- always（可省）：`{ [登記名] = value }`——這支插件**自己帶檔**的材質。清單裡沒有也照列
-- （LibSharedMedia 沒裝、或新檔還沒重開遊戲所以登記不進去），value 用表裡給的（存 token 不存登記名的插件用）。
-- 沒列在 always 的自製材質只有清單裡真的有才出現（別的插件登記的），value 就是登記名。
--
-- resolve（可省，**新的材質下拉一律要傳**）：`function(value) → 圖檔路徑`，消費者自己那支「存檔值 → 路徑」
-- （各插件 Core/Media.lua 的 BarTexture／Texture）。每一項的 texture 就是它的回傳值，下拉拿來畫預覽；
-- 沒傳、丟錯、回的不是字串或數字 ＝ 那一項沒有預覽。
function MM.TextureItems(list, always, locale, resolve)
    local function Preview(value)
        if type(resolve) ~= "function" then return nil end
        local ok, path = pcall(resolve, value)
        if ok and (type(path) == "string" or type(path) == "number") then return path end
        return nil
    end
    local present = {}
    if type(list) == "table" then
        for _, name in ipairs(list) do
            if type(name) == "string" then present[name] = true end
        end
    end
    local own, rest = {}, {}
    for _, def in ipairs(TEXTURES) do
        local value = type(always) == "table" and always[def.name] or nil
        if value == nil and present[def.name] then value = def.name end
        if value ~= nil then
            own[#own + 1] = { text = MM.TextureLabel(def.name, locale), value = value, texture = Preview(value) }
        end
    end
    if type(list) == "table" then
        for _, name in ipairs(list) do
            if type(name) == "string" and not BY_NAME[name] then
                rest[#rest + 1] = { text = name, value = name, texture = Preview(name) }
            end
        end
    end
    return own, rest
end
