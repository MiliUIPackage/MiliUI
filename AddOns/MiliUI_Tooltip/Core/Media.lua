------------------------------------------------------------
-- 媒體：在地化字型、背景材質、血條材質（LibSharedMedia 可選整合）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

-- 在地化字型（FontString 寫死 FRIZQT__ 在 zhTW 會變方框）
local LOCALE_FONTS = {
    zhTW = "Fonts\\blei00d.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    koKR = "Fonts\\2002.TTF",
}
local DEFAULT_FONT = LOCALE_FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF"

ns.Media = {}
local M = ns.Media

M.WHITE8X8 = "Interface\\BUTTONS\\WHITE8X8"

-- 關掉引擎的像素貼齊（SetSnapToPixelGrid／SetTexelSnappingBias）。
-- 貼齊開著時，引擎在畫的那一刻把**每張貼圖自己的**頂點各自四捨五入到最近的實體像素；
-- 跟隨游標的提示停在任意小數座標上，1px 的邊只要兩側四捨五入到同一格就整條變 0px
-- （2026-10-19 玩家回報：邊框粗細 1 時左邊偶爾不見）。MiliUI_CooldownManager 的 ns.NoSnap 同一招。
-- 只用在自己建的貼圖上
function M.NoSnap(tex)
    if tex and tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
    return tex
end

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- token → 字型路徑；"DEFAULT" = 在地化字型
function M.Font(token)
    if not token or token == "DEFAULT" or token == "default" then return DEFAULT_FONT end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("font", token, true)
        if path then return path end
    end
    return DEFAULT_FONT
end

-- 背景材質（token → 路徑）。solid = 白貼圖配背景色，是套組預設。
M.BACKGROUNDS = {
    solid   = M.WHITE8X8,
    gradual = "Interface\\Buttons\\GreyscaleRamp64",
    dark    = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    alpha   = "Interface\\Tooltips\\UI-Tooltip-Background",
    rock    = "Interface\\FrameGeneral\\UI-Background-Rock",
    marble  = "Interface\\FrameGeneral\\UI-Background-Marble",
}

function M.Background(token)
    if type(token) ~= "string" or token == "" then return M.WHITE8X8 end
    if M.BACKGROUNDS[token] then return M.BACKGROUNDS[token] end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("background", token, true)
        if path then return path end
    end
    return token   -- 自訂路徑原樣放行
end

function M.BackgroundItems()
    local items = {
        { text = L["Solid"],    value = "solid" },
        { text = L["Gradient"], value = "gradual" },
        { text = L["Dark parchment"], value = "dark" },
        { text = L["Translucent"],    value = "alpha" },
        { text = L["Rock"],     value = "rock" },
        { text = L["Marble"],   value = "marble" },
    }
    return items
end

------------------------------------------------------------
-- 血條材質：自帶套組自製的 MiliUI Satin（Media/miliui_satin.png，跟 MiliUI_UnitFrames 同一張、同一套做法；
-- 2026-10-16 取代 TukTex，舊 token "tuktex" 當別名、v2 值閘遷移）
-- 解析先查自己的表、查不到才問 LSM；同時把自己的材質登記進 LSM，
-- 讓別的插件的材質選單也看得到。兩個方向都不依賴外人。
------------------------------------------------------------
local MEDIA_PATH = "Interface\\AddOns\\MiliUI_Tooltip\\Media\\"

M.TEXTURES = {
    satin  = MEDIA_PATH .. "miliui_satin.png",
    tuktex = MEDIA_PATH .. "miliui_satin.png",   -- 舊 token 別名
    ombre  = MEDIA_PATH .. "miliui_ombre.png",   -- MiliUI Ombre（漸染）：這張是左暗右亮的灰階底，「左濃右原色」是疊層（M.PaintBar）
}

-- 登記到 LSM 的顯示名。⚠ LSM 撞名會被靜默拒絕——MiliUI_UnitFrames 也用這個名字
-- 登記同一張圖，誰先到誰贏，兩邊檔案相同所以無所謂；自己解析不走這個名字。
local LSM_NAME = "MiliUI Satin"
local OMBRE_NAME = "MiliUI Ombre"

local lsmDone = false
function M.RegisterSharedMedia()
    if lsmDone then return end
    local lsm = LSM()
    if not lsm then return end
    lsmDone = true
    pcall(lsm.Register, lsm, "statusbar", LSM_NAME, M.TEXTURES.satin)
    -- ⚠ 別的插件從 LSM 選到漸染只會拿到那張直向明暗的圖，橫向漸層要它自己接雙色上色才有
    pcall(lsm.Register, lsm, "statusbar", OMBRE_NAME, M.TEXTURES.ombre)
end
M.RegisterSharedMedia()

function M.BarTexture(token)
    if type(token) ~= "string" or token == "" or token == "solid" then return M.WHITE8X8 end
    if M.TEXTURES[token] then return M.TEXTURES[token] end
    if token == LSM_NAME then return M.TEXTURES.satin end
    if token == OMBRE_NAME then return M.TEXTURES.ombre end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("statusbar", token, true)
        if path then return path end
    end
    return token
end

------------------------------------------------------------
-- 漸染（MiliUI Ombre）：長條左端是更濃的顏色、右端是原色
--
-- **用材質疊出來，不算顏色**：疊層（四張貼圖＋一張跟著填充走的遮罩）在共用的 Libs/MiliUIMedia.lua（MM.OmbrePaint），
-- 這裡只負責「這條是不是漸染」與把條交過去。顏色只是傳給貼圖 ⇒ 秘密分量照樣能用；
-- 漸層固定在整條上，條縮短只是右邊被裁掉。直向的條不疊（MM.OmbrePaint 回 false ⇒ 照舊單色）。
-- miliui_ombre.png 本身是左暗右亮的灰階漸層（登記進 LibSharedMedia 的就是它），疊層蓋在它上面。
------------------------------------------------------------
-- token 省略＝讀血條材質設定（statusbar.texture）
function M.IsOmbre(token)
    if token == nil then token = ns.db and ns.db.statusbar and ns.db.statusbar.texture end
    return token == "ombre" or token == OMBRE_NAME
end

-- 長條填充貼圖的上色統一走這支：選了漸染就交給疊層，否則照舊 SetVertexColor（順手把疊層收掉）。
-- 只用在自己建的 StatusBar 上（疊層是掛在條底下的子框）。
function M.PaintBar(tex, r, g, b, a)
    if not tex then return end
    local MM = ns.MiliMedia
    local bar = MM and MM.OmbrePaint and tex.GetParent and tex:GetParent()
    if bar then
        if M.IsOmbre() and MM.OmbrePaint(bar, r, g, b, a) then return end
        MM.OmbreClear(bar)
    end
    tex:SetVertexColor(r, g, b, a)
end

function M.BarTextureItems()
    M.RegisterSharedMedia()   -- LSM 若比我們晚載入，開選單時再補登一次
    -- 米利的材質排最上面、中文客戶端顯示「米利UI: 緞面」（名冊、譯名、順序在 Libs/MiliUIMedia.lua，全套組同一套規則）
    -- → 純色 → LSM 的。自己帶檔的兩張存 token "satin"／"ombre"，LSM 清單裡的同名項由名冊併成同一項
    local lsm = LSM()
    local items, rest = ns.MiliMedia.TextureItems(lsm and lsm:List("statusbar") or nil, { [LSM_NAME] = "satin", [OMBRE_NAME] = "ombre" }, nil, M.BarTexture)
    items[#items + 1] = { text = L["Solid"], value = "solid" }
    for i = 1, #rest do items[#items + 1] = rest[i] end
    return items
end

function M.FontItems()
    local items = { { text = L["Default (follows client language)"], value = "default" } }
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("font")) do
            items[#items + 1] = { text = name, value = name }
        end
    end
    return items
end
