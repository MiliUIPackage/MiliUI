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
-- 名冊那半是純資料＋純函式、不依賴 LibSharedMedia（清單由消費者自己問完再傳進來）；
-- 唯一會碰框的是檔尾的「漸染」疊層（MM.OmbrePaint），只在消費者把自己的 StatusBar 交進來時才動它。
------------------------------------------------------------
local ADDON, ns = ...

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
    { name = "MiliUI Ombre",        zhTW = "漸染",         zhCN = "渐染" },
    { name = "MiliUI Rainbow",      zhTW = "彩虹",         zhCN = "彩虹" },
    { name = "MiliUI Rainbow Soft", zhTW = "彩虹（柔和）", zhCN = "彩虹（柔和）" },
    { name = "MiliUI Cosmos",       zhTW = "宇宙星辰",     zhCN = "宇宙星辰" },
    { name = "MiliUI Lightning",    zhTW = "閃電",         zhCN = "闪电" },
    { name = "MiliUI Lava",         zhTW = "熔岩",         zhCN = "熔岩" },
    { name = "MiliUI Flame",        zhTW = "火焰",         zhCN = "火焰" },
    { name = "MiliUI Sakura",       zhTW = "櫻花",         zhCN = "樱花" },
    { name = "MiliUI Seigaiha",     zhTW = "青海波",       zhCN = "青海波" },
    { name = "MiliUI Sky Lantern",  zhTW = "天燈",         zhCN = "天灯" },
    { name = "MiliUI Hakka Floral", zhTW = "客家花布",     zhCN = "客家花布" },
    { name = "MiliUI Majolica Tile", zhTW = "老花磚",      zhCN = "老花砖" },
    { name = "MiliUI Bubble Tea",   zhTW = "珍珠奶茶",     zhCN = "珍珠奶茶" },
    { name = "MiliUI Aurora",       zhTW = "極光",         zhCN = "极光" },
    { name = "MiliUI Momiji",       zhTW = "紅葉",         zhCN = "红叶" },
    { name = "MiliUI Fireflies",    zhTW = "螢火蟲",       zhCN = "萤火虫" },
    { name = "MiliUI Koi Pond",     zhTW = "錦鯉水波",     zhCN = "锦鲤水波" },
    { name = "MiliUI Night Market", zhTW = "夜市霓虹",     zhCN = "夜市霓虹" },
    { name = "MiliUI Flip Flops",   zhTW = "藍白拖",       zhCN = "蓝白拖" },
    { name = "MiliUI Blue Magpie",  zhTW = "台灣藍鵲",     zhCN = "台湾蓝鹊" },
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

------------------------------------------------------------
-- 漸染（MiliUI Ombre）：長條左端是更濃的顏色、右端是原色——**用材質疊出來，不算顏色**
--
-- 一張圖乘上顏色只能整體變暗，做不出「變濃」；變濃＝顏色自己再乘自己。所以選了漸染的 StatusBar 會在填充上面多疊四張貼圖
-- （2026-11-13 使用者在探針裡挑的濃度）：
--   1. 底：純色（取 miliui_ombre.png 最右一行＝只有直向明暗），上條的顏色
--   2. 3. 兩層純白、上條的顏色、混合模式 MOD（相乘）⇒ 顏色的三次方
--   4. 頂：miliui_ombre_ramp.png（左端 10% 不透明 → 右端全不透明），上條的顏色 ⇒ 左邊透出底下濃的、右邊蓋回原色
-- 四張都鋪滿**整條**、掛在條自己身上（緊貼在填充貼圖的上一個子層），再用一張錨在填充貼圖上的遮罩切掉沒血的那段
-- ⇒ 漸層固定在整條上，扣血只是右邊被裁掉；條上的文字（OVERLAY）與別的框都還在它上面。
-- （試過在條上蓋一個裁切子框：子框會蓋住條自己身上所有東西。2026-11-13 探針確認 MOD 層吃遮罩、不會漏到空的那段。）
-- 顏色只是傳給貼圖（SetVertexColor），不做算術 ⇒ 秘密分量照樣能用。
--
-- miliui_ombre.png 本身（登記進 LibSharedMedia 的那張、下拉預覽鋪的也是它）是「左暗右亮」的灰階漸層：
-- 疊層蓋在它上面所以平常看不到，套組以外的插件選到它、或疊層建不起來時，至少還是一道橫向漸層。
--
-- 兩張圖每支插件自己帶（Media/miliui_ombre.png、Media/miliui_ombre_ramp.png，技能 miliui-satin-texture 的 ombre.py 畫的）。
-- 直向的條不疊（回 false，呼叫端照舊上色）。
------------------------------------------------------------
MM.OMBRE_NAME = "MiliUI Ombre"

local OMBRE_BASE = "Interface\\AddOns\\" .. tostring(ADDON) .. "\\Media\\miliui_ombre.png"
local OMBRE_RAMP = "Interface\\AddOns\\" .. tostring(ADDON) .. "\\Media\\miliui_ombre_ramp.png"
local WHITE8X8 = "Interface\\BUTTONS\\WHITE8X8"

function MM.IsOmbre(name)
    return name == MM.OMBRE_NAME
end

-- StatusBar → 它的疊層（弱鍵：條被丟掉就跟著走；不在條上寫欄位）
local ombreStacks = setmetatable({}, { __mode = "k" })

local function OmbreBuild(bar, fill)
    local mask = bar:CreateMaskTexture()
    mask:SetTexture(WHITE8X8, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    local layer, sub = fill:GetDrawLayer()
    layer, sub = layer or "ARTWORK", sub or 0
    local st = { mask = mask }
    for i = 1, 4 do
        local n = sub + i
        if n > 7 then n = 7 end
        local t = bar:CreateTexture(nil, layer, nil, n)
        t:SetAllPoints(bar)
        if i == 1 then
            t:SetTexture(OMBRE_BASE)
            t:SetTexCoord(0.98, 1, 0, 1)      -- 最右一行：只剩直向明暗
        elseif i == 4 then
            t:SetTexture(OMBRE_RAMP)
        else
            t:SetTexture(WHITE8X8)
            t:SetBlendMode("MOD")
        end
        t:AddMaskTexture(mask)
        st[i] = t
    end
    ombreStacks[bar] = st
    return st
end

-- 把 bar（消費者自己的 StatusBar）的填充畫成漸染。r/g/b/a 可以是秘密值。
-- 回 true＝畫了；false＝沒畫（直向條、還沒有填充貼圖），呼叫端照舊上色。
function MM.OmbrePaint(bar, r, g, b, a)
    local fill = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not fill then return false end
    if bar.GetOrientation and bar:GetOrientation() == "VERTICAL" then
        MM.OmbreClear(bar)
        return false
    end
    local st = ombreStacks[bar]
    if not st then st = OmbreBuild(bar, fill) end
    if st.fill ~= fill then                    -- 換過材質：填充貼圖可能是新的一顆
        st.fill = fill
        st.mask:ClearAllPoints()
        st.mask:SetAllPoints(fill)
    end
    fill:SetVertexColor(r, g, b, a)
    for i = 1, 4 do st[i]:SetVertexColor(r, g, b, a) end
    if not st.on then
        st.on = true
        for i = 1, 4 do st[i]:Show() end
    end
    return true
end

-- 這條不再是漸染（換材質、轉成直向…）：把疊層收起來。沒疊過就什麼都不做。
function MM.OmbreClear(bar)
    local st = bar and ombreStacks[bar]
    if st and st.on then
        st.on = false
        for i = 1, 4 do st[i]:Hide() end
    end
end

