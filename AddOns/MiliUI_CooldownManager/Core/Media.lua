------------------------------------------------------------
-- 媒體：字型／材質的 token → 路徑、像素對齊的小工具
--
-- 設定裡存的是 **token**（LibSharedMedia 的名稱，或我們自己的保留字），不是路徑：
--   字型  "DEFAULT"  ＝ 跟著客戶端語系的內建字型
--   材質  "solid"    ＝ 純白貼圖（HUD 皮的純色底／1px 邊都用它）
-- 其餘名稱去問 LibSharedMedia（本插件內嵌）；查不到一律退回預設，
-- 不會回 nil —— FontString 沒字型就 SetText 是硬錯誤，而且會中斷整支初始化。
------------------------------------------------------------
local _, ns = ...

ns.Media = {}
local M = ns.Media

M.WHITE8X8 = "Interface\\BUTTONS\\WHITE8X8"

-- 在地化字型（寫死 FRIZQT__ 在中文客戶端會變方框）
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

-- 字型 token → 路徑
function M.Font(token)
    if not token or token == "DEFAULT" then return DEFAULT_FONT end
    local lsm = LSM()
    if lsm then
        local ok, path = pcall(lsm.Fetch, lsm, "font", token, true)
        if ok and path then return path end
    end
    return DEFAULT_FONT
end

-- 各段文字自己的字型：own 是 "INHERIT"／nil／"" ＝ 跟隨通用字型（general，主題／條的 font）
M.INHERIT = "INHERIT"
function M.ElementFont(own, general)
    if type(own) == "string" and own ~= "" and own ~= M.INHERIT then return own end
    return general
end

------------------------------------------------------------
-- 套組共用的長條材質「MiliUI Satin」：Media/miliui_satin.png 是技能 miliui-satin-texture 的腳本畫的
-- （上緣高光往下壓到平台的純灰階漸層，完全自己做、不帶別人的檔；五支插件各帶一份、md5 相同）。專注目標施法條的預設材質。
-- 登記名加前綴「MiliUI」：LSM 撞名會被靜默拒絕。解析時先認自己的名字再問 LSM，所以 LSM 還不認得新檔也畫得出來。
-- ⚠ LSM 登記會問 C_UIFileAsset.IsKnownFile：新檔案要整個重開遊戲才認得，/reload 不夠
------------------------------------------------------------
M.BAR_TEXTURE = "Interface\\AddOns\\MiliUI_CooldownManager\\Media\\miliui_satin.png"
M.BAR_TEXTURE_NAME = "MiliUI Satin"

-- 「MiliUI Ombre」（漸染）：長條左端是更濃的顏色、右端是原色。圖（Media/miliui_ombre.png，技能 miliui-satin-texture 的
-- ombre.py 畫的）只有直向明暗；橫向那道漸層是上色時給兩個顏色（M.PaintBar，見下面「漸染」那一段）。
-- 接法同 Satin：自帶檔、登記 LSM、名字直接解到自己的檔。不是動畫材質（不進 M.FX）
M.OMBRE_TEXTURE = "Interface\\AddOns\\MiliUI_CooldownManager\\Media\\miliui_ombre.png"
M.OMBRE_TEXTURE_NAME = "MiliUI Ombre"

-- 動畫材質（2026-11-04 彩虹、11-06 宇宙星辰／閃電／熔岩／火焰、11-10 櫻花／青海波／天燈／客家花布／老花磚／珍珠奶茶／極光，
-- 同日第三批 紅葉／螢火蟲／錦鯉水波／夜市霓虹／藍白拖、11-11 台灣藍鵲；
-- 玩家問「施法條能不能多點皮膚」）。貼圖全部是腳本算的、不帶別人的檔：彩虹是技能 miliui-cdm-rainbow-texture、
-- 其餘是 miliui-cdm-castbar-fx（fx.py 第一批四款、fx_themes.py 第二批七款與第三批六款）。
--   tex     靜態那張：當 StatusBar 填充（進度前進時逐段露出），也是登記進 LSM 的那張 ⇒ 本插件所有長條的材質下拉都選得到
--   layers  施法條效果層的畫法（Modules/Castbar.lua「效果層」；玩家施法條與專注目標施法條都做，後者借 ns.Castbar.Fx），由下往上：
--     kind = "scroll"  整條寬、REPEAT 平鋪，貼圖座標動畫橫向捲，period 秒捲完一輪（貼圖兩端要接得起來）；
--                      blend（預設一般混色，"ADD" ＝ 黑底貼圖加亮）、alpha、twinkle = { lo, period }（alpha 在 lo～原值之間來回）；
--                      vy ＝ 同一輪裡直向捲幾個貼圖高（整數；正＝往下飄、負＝往上升；貼圖上下也要接得起來）。
--                      橫直共用一個動畫 ⇒ 直向只能是整數圈，不然循環接不起來
--     kind = "flip"    序列圖 cols × rows 共 frames 格，time 秒播完一輪、之後看不見 pause 秒（0 ＝ 連續循環）；
--                      overflow ＝ 往條的上緣外多畫幾倍條高（火舌竄出去；裁切框跟著加高）
-- 顏色烤在圖裡 ⇒ 選到時施法條的底色自動當白（不然被施法色染髒），蓄力／斷法就緒／不可打斷／打斷照舊乘上去。
-- ⚠ 序列圖的格數與排列跟產圖腳本綁在一起，改一邊要改另一邊。
local MEDIA = "Interface\\AddOns\\MiliUI_CooldownManager\\Media\\"
M.FX = {
    ["MiliUI Rainbow"] = { tex = MEDIA .. "miliui_rainbow.png", layers = {
        { kind = "scroll", tex = MEDIA .. "miliui_rainbow_flow.png", period = 3 },
    } },
    ["MiliUI Rainbow Soft"] = { tex = MEDIA .. "miliui_rainbow_soft.png", layers = {
        { kind = "scroll", tex = MEDIA .. "miliui_rainbow_soft_flow.png", period = 3 },
    } },
    -- 宇宙星辰：星雲底慢慢捲、小星點快一點、亮星再快一點並且明暗閃爍（三層視差）
    ["MiliUI Cosmos"] = { tex = MEDIA .. "fx-cosmos-base.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-cosmos-base.png", period = 16 },
        { kind = "scroll", tex = MEDIA .. "fx-cosmos-stars-a.png", period = 10, blend = "ADD" },
        { kind = "scroll", tex = MEDIA .. "fx-cosmos-stars-b.png", period = 6, blend = "ADD", twinkle = { lo = 0.45, period = 1.4 } },
    } },
    -- 閃電：電能底捲動，上面八格電弧 0.4 秒打一道、停 0.4 秒
    ["MiliUI Lightning"] = { tex = MEDIA .. "fx-lightning-base.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-lightning-base.png", period = 2.5 },
        { kind = "flip", tex = MEDIA .. "fx-lightning-bolts.png", cols = 2, rows = 4, frames = 8, time = 0.4, pause = 0.4, blend = "ADD" },
    } },
    -- 熔岩：暗紅底上兩層火紋用不同速度橫著流
    ["MiliUI Lava"] = { tex = MEDIA .. "fx-lava-base.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-lava-base.png", period = 6 },
        { kind = "scroll", tex = MEDIA .. "fx-lava-wisp-a.png", period = 2.4, blend = "ADD", alpha = 0.85 },
        { kind = "scroll", tex = MEDIA .. "fx-lava-wisp-b.png", period = 1.5, blend = "ADD", alpha = 0.7 },
    } },
    -- 火焰：餘燼底上十六格可循環的火舌（每格下 2/3 是條身、上 1/3 竄出條外）
    ["MiliUI Flame"] = { tex = MEDIA .. "fx-flame-base.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-flame-base.png", period = 6 },
        { kind = "flip", tex = MEDIA .. "fx-flame-tongues.png", cols = 4, rows = 4, frames = 16, time = 16 / 14, pause = 0, overflow = 0.5 },
    } },
    -- 櫻花：玫瑰粉的柔焦底上兩層花瓣斜斜飄落（遠的小而慢、近的大而快）
    ["MiliUI Sakura"] = { tex = MEDIA .. "fx-sakura-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-sakura-base.png", period = 22 },
        { kind = "scroll", tex = MEDIA .. "fx-sakura-petals-a.png", period = 15, vy = 2 },
        { kind = "scroll", tex = MEDIA .. "fx-sakura-petals-b.png", period = 8, vy = 2 },
    } },
    -- 青海波：靛藍底的波紋慢慢流動，一道斜向波光掃過
    ["MiliUI Seigaiha"] = { tex = MEDIA .. "fx-seigaiha-base.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-seigaiha-base.png", period = 26 },
        { kind = "scroll", tex = MEDIA .. "fx-sheen.png", period = 4.5, blend = "ADD", alpha = 0.55 },
    } },
    -- 天燈：夜空裡遠近兩層暖橘色的天燈緩緩上升
    ["MiliUI Sky Lantern"] = { tex = MEDIA .. "fx-lantern-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-lantern-sky.png", period = 30 },
        { kind = "scroll", tex = MEDIA .. "fx-lantern-far.png", period = 40, vy = -3, blend = "ADD" },
        { kind = "scroll", tex = MEDIA .. "fx-lantern-near.png", period = 22, vy = -3, blend = "ADD" },
    } },
    -- 客家花布：大紅底的牡丹花布慢慢捲過，帶一點反光
    ["MiliUI Hakka Floral"] = { tex = MEDIA .. "fx-hakka-base.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-hakka-base.png", period = 24 },
        { kind = "scroll", tex = MEDIA .. "fx-sheen.png", period = 6, blend = "ADD", alpha = 0.4 },
    } },
    -- 老花磚：彩釉花磚慢慢捲過，釉面一道反光
    ["MiliUI Majolica Tile"] = { tex = MEDIA .. "fx-tile-base.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-tile-base.png", period = 20 },
        { kind = "scroll", tex = MEDIA .. "fx-sheen.png", period = 4, blend = "ADD", alpha = 0.4 },
    } },
    -- 珍珠奶茶：奶茶底加黑糖虎紋、底部一排珍珠滾過、小氣泡往上冒
    ["MiliUI Bubble Tea"] = { tex = MEDIA .. "fx-boba-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-boba-base.png", period = 18 },
        { kind = "scroll", tex = MEDIA .. "fx-boba-pearls.png", period = 12 },
        { kind = "scroll", tex = MEDIA .. "fx-boba-bubbles.png", period = 30, vy = -6, blend = "ADD", alpha = 0.8 },
    } },
    -- 極光：夜空裡兩道光幕用不同速度流動
    ["MiliUI Aurora"] = { tex = MEDIA .. "fx-aurora-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-aurora-sky.png", period = 40 },
        { kind = "scroll", tex = MEDIA .. "fx-aurora-b.png", period = 14, blend = "ADD", alpha = 0.85 },
        { kind = "scroll", tex = MEDIA .. "fx-aurora-a.png", period = 9, blend = "ADD" },
    } },
    -- 紅葉：暖金光斑的深褐底上兩層楓葉斜斜飄落（櫻花的秋天版）
    ["MiliUI Momiji"] = { tex = MEDIA .. "fx-momiji-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-momiji-base.png", period = 22 },
        { kind = "scroll", tex = MEDIA .. "fx-momiji-leaves-a.png", period = 16, vy = 2 },
        { kind = "scroll", tex = MEDIA .. "fx-momiji-leaves-b.png", period = 9, vy = 2 },
    } },
    -- 螢火蟲：草叢剪影的夜色上三層螢火蟲，明滅的節奏與飄的方向各不相同（同一層的會一起明滅，所以分三層錯開）
    ["MiliUI Fireflies"] = { tex = MEDIA .. "fx-firefly-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-firefly-night.png", period = 34 },
        { kind = "scroll", tex = MEDIA .. "fx-firefly-a.png", period = 26, blend = "ADD", twinkle = { lo = 0.2, period = 1.7 } },
        { kind = "scroll", tex = MEDIA .. "fx-firefly-b.png", period = 19, vy = -1, blend = "ADD", alpha = 0.9, twinkle = { lo = 0.1, period = 2.3 } },
        { kind = "scroll", tex = MEDIA .. "fx-firefly-c.png", period = 40, vy = 2, blend = "ADD", twinkle = { lo = 0.25, period = 1.1 } },
    } },
    -- 錦鯉水波：池水上兩層光網用不同速度流動，錦鯉游得比水快（魚頭朝填充方向；反向填充時魚會倒著游）
    ["MiliUI Koi Pond"] = { tex = MEDIA .. "fx-koi-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-koi-water.png", period = 24 },
        { kind = "scroll", tex = MEDIA .. "fx-koi-caustic-a.png", period = 13, blend = "ADD", alpha = 0.8 },
        { kind = "scroll", tex = MEDIA .. "fx-koi-fish.png", period = 10 },
        { kind = "scroll", tex = MEDIA .. "fx-koi-caustic-b.png", period = 8, blend = "ADD", alpha = 0.7 },
    } },
    -- 夜市霓虹：暗牆上八塊霓虹招牌（一半會閃）、頂上一串小燈泡；四層同速，招牌才會釘在牆上
    ["MiliUI Night Market"] = { tex = MEDIA .. "fx-neon-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-neon-wall.png", period = 26 },
        { kind = "scroll", tex = MEDIA .. "fx-neon-signs-a.png", period = 26, blend = "ADD" },
        { kind = "scroll", tex = MEDIA .. "fx-neon-signs-b.png", period = 26, blend = "ADD", twinkle = { lo = 0.55, period = 0.45 } },
        { kind = "scroll", tex = MEDIA .. "fx-neon-bulbs.png", period = 26, blend = "ADD", twinkle = { lo = 0.35, period = 0.6 } },
    } },
    -- 藍白拖：磨石子地上一排藍白拖慢慢捲過
    ["MiliUI Flip Flops"] = { tex = MEDIA .. "fx-slipper-base.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-slipper-base.png", period = 22 },
    } },
    -- 台灣藍鵲：一列藍鵲飛過晨霧裡的山。天空＋遠山 → 中山 → 鳥 → 近山，越近捲越快；鳥夾在中山與近山之間 ⇒ 會被近山的稜線擋住一點
    -- （鳥頭朝填充方向；反向填充時鳥會倒著飛，同錦鯉）
    ["MiliUI Blue Magpie"] = { tex = MEDIA .. "fx-magpie-static.png", layers = {
        { kind = "scroll", tex = MEDIA .. "fx-magpie-sky.png", period = 44 },
        { kind = "scroll", tex = MEDIA .. "fx-magpie-ridge-mid.png", period = 26 },
        { kind = "scroll", tex = MEDIA .. "fx-magpie-birds.png", period = 9 },
        { kind = "scroll", tex = MEDIA .. "fx-magpie-ridge-near.png", period = 15 },
    } },
}
M.FX_ORDER = { "MiliUI Rainbow", "MiliUI Rainbow Soft", "MiliUI Cosmos", "MiliUI Lightning", "MiliUI Lava", "MiliUI Flame",
               "MiliUI Sakura", "MiliUI Seigaiha", "MiliUI Sky Lantern", "MiliUI Hakka Floral", "MiliUI Majolica Tile",
               "MiliUI Bubble Tea", "MiliUI Aurora",
               "MiliUI Momiji", "MiliUI Fireflies", "MiliUI Koi Pond", "MiliUI Night Market", "MiliUI Flip Flops",
               "MiliUI Blue Magpie" }

-- 這支自己帶檔的材質：登記名 → 存檔值（這支存的就是登記名）。材質下拉拿它餵 ns.MiliMedia.TextureItems 的 always：
-- LSM 清單裡沒有（新檔還沒重開遊戲）也照列。顯示名與順序在 Libs/MiliUIMedia.lua 的名冊，新材質兩邊都要加
M.OWN_TEXTURES = { [M.BAR_TEXTURE_NAME] = M.BAR_TEXTURE_NAME, [M.OMBRE_TEXTURE_NAME] = M.OMBRE_TEXTURE_NAME }
for _, name in ipairs(M.FX_ORDER) do M.OWN_TEXTURES[name] = name end

-- token 是不是動畫材質（純函式）
function M.IsFx(token)
    return type(token) == "string" and M.FX[token] ~= nil
end

-- 動畫材質的效果層清單（不是動畫材質 ＝ nil）
function M.FxLayers(token)
    local fx = M.IsFx(token) and M.FX[token]
    return fx and fx.layers or nil
end

local lsmDone = false
function M.RegisterSharedMedia()
    if lsmDone then return end
    local lsm = LSM()
    if not lsm then return end
    lsmDone = true
    pcall(lsm.Register, lsm, "statusbar", M.BAR_TEXTURE_NAME, M.BAR_TEXTURE)
    pcall(lsm.Register, lsm, "statusbar", M.OMBRE_TEXTURE_NAME, M.OMBRE_TEXTURE)
    for _, name in ipairs(M.FX_ORDER) do
        pcall(lsm.Register, lsm, "statusbar", name, M.FX[name].tex)
    end
end
M.RegisterSharedMedia()

-- 材質 token → 路徑（statusbar 類）
function M.Texture(token)
    if not token or token == "solid" then return M.WHITE8X8 end
    if token == M.BAR_TEXTURE_NAME then return M.BAR_TEXTURE end
    if token == M.OMBRE_TEXTURE_NAME then return M.OMBRE_TEXTURE end
    if M.FX[token] then return M.FX[token].tex end
    local lsm = LSM()
    if lsm then
        local ok, path = pcall(lsm.Fetch, lsm, "statusbar", token, true)
        if ok and path then return path end
    end
    return M.WHITE8X8
end

------------------------------------------------------------
-- 漸染（MiliUI Ombre）：長條填充左端是更濃的顏色、右端是原色
--
-- 材質圖只能把顏色整體乘暗、做不出「變濃」，所以橫向那道漸層是這裡給兩個顏色（Texture:SetGradient）：
-- 左＝每個分量取 2.6 次方（分量越小壓越多 ⇒ 變濃而不是變黑）、右＝每個分量 ×0.88，alpha 兩端相同
-- （數字跟 MiliUI_UnitFrames 的 M.PaintBar 同一組）。白色怎麼取次方都是白色 ⇒ 純白的條只有右端暗一點。
--
-- 這支插件的材質是每個模組／每條各自設定的 ⇒ 判定吃**那條長條自己的材質設定值**（token），沒有全域開關。
--   M.IsOmbre(token)                    token 是不是漸染（純函式）
--   M.PaintBar(tex, token, r, g, b, a)  填充貼圖上色的統一出口：漸染畫雙色漸層，否則就是 SetVertexColor
--   M.OmbrePair(r, g, b, a)             先建好的一對色物件（引擎寫的光環條：initializeFrame 裡不能 CreateColor，只查表）
--
-- ⚠ 漸層掛在填充貼圖的四個角上：條縮短時漸層跟著擠，最亮的永遠是填充的右端。
-- ⚠ 顏色分量可能是秘密值（曲線挑出來的顏色、斷法就緒染色）：不能比較也不能算術 ⇒ 先過 ns.IsSecret，是秘密就退成原本的單色。
-- ⚠ 一格一張貼圖的分段條（點數型、充能分段、一顆光環一格）與直向的條不接：漸層會變成每格各一道／方向不對。
-- SetVertexColor 與 SetGradient 的關係沒查證（同 Core/Decorate_Bars.lua「漸層填充」的說明）⇒ 兩種模型都對的寫法：
-- 畫漸層前先 SetVertexColor 白；畫過漸層的貼圖退回單色時先 SetGradient 白→白。沒畫過漸層的貼圖只有一個 SetVertexColor，跟以前完全一樣。
------------------------------------------------------------
local OMBRE_GAMMA = 2.6
local OMBRE_RIGHT = 0.88

function M.IsOmbre(token)
    return token == M.OMBRE_TEXTURE_NAME
end

-- 材質路徑是不是漸染那張（引擎寫的光環條只拿得到解好的路徑；路徑就是那條自己的材質設定解出來的）
function M.IsOmbrePath(path)
    return path == M.OMBRE_TEXTURE
end

-- 每張貼圖一對色物件，重複使用（資源條的事件很密，不要每次 CreateColor）；[3] ＝ 這張貼圖現在畫著漸層
local ombreColors = setmetatable({}, { __mode = "k" })
local ombreWhite

local function Secret(v)
    local f = ns.IsSecret
    return f ~= nil and f(v) and true or false
end

function M.PaintBar(tex, token, r, g, b, a)
    if not tex then return end
    local pair = ombreColors[tex]
    -- 秘密值先擋，再做別的比較
    if token ~= M.OMBRE_TEXTURE_NAME or not tex.SetGradient or not CreateColor
        or Secret(r) or Secret(g) or Secret(b) or Secret(a)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        if pair and pair[3] then
            pair[3] = false
            ombreWhite = ombreWhite or CreateColor(1, 1, 1, 1)
            pcall(tex.SetGradient, tex, "HORIZONTAL", ombreWhite, ombreWhite)
        end
        tex:SetVertexColor(r, g, b, a)
        return false
    end
    a = tonumber(a) or 1
    if not pair then
        pair = { CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 1), false }
        ombreColors[tex] = pair
    end
    -- 負的分量取小數次方是 NaN：先夾到 0
    if r < 0 then r = 0 end
    if g < 0 then g = 0 end
    if b < 0 then b = 0 end
    pair[1]:SetRGBA(r ^ OMBRE_GAMMA, g ^ OMBRE_GAMMA, b ^ OMBRE_GAMMA, a)
    pair[2]:SetRGBA(r * OMBRE_RIGHT, g * OMBRE_RIGHT, b * OMBRE_RIGHT, a)
    tex:SetVertexColor(1, 1, 1, 1)
    if not pcall(tex.SetGradient, tex, "HORIZONTAL", pair[1], pair[2]) then
        tex:SetVertexColor(r, g, b, a)
        return false
    end
    pair[3] = true
    return true
end

-- 先建好的一對色物件（依顏色快取、不重配）：{ c1, c2, sig = 快取鍵 }；分量不是明文數字或沒有 CreateColor ⇒ nil。
-- 給「樣式只能在 initializeFrame 裡烘」的光環條用：容器建立之前（正常插件路徑）叫，initializeFrame 裡只查表
local ombrePairs = {}
function M.OmbrePair(r, g, b, a)
    if not CreateColor or Secret(r) or Secret(g) or Secret(b) or Secret(a) then return nil end
    r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 1
    if not (r and g and b) then return nil end
    if r < 0 then r = 0 end
    if g < 0 then g = 0 end
    if b < 0 then b = 0 end
    local sig = ("ombre:%.3f,%.3f,%.3f,%.3f"):format(r, g, b, a)
    local hit = ombrePairs[sig]
    if not hit then
        hit = { CreateColor(r ^ OMBRE_GAMMA, g ^ OMBRE_GAMMA, b ^ OMBRE_GAMMA, a),
                CreateColor(r * OMBRE_RIGHT, g * OMBRE_RIGHT, b * OMBRE_RIGHT, a), sig = sig }
        ombrePairs[sig] = hit
    end
    return hit
end

-- 描邊旗標：主題「文字」的描邊下拉五個值。單色（MONOCHROME）＝關掉反鋸齒，像素字體要它才銳利
M.OUTLINES = {
    [""] = true, OUTLINE = true, THICKOUTLINE = true,
    ["MONOCHROME,OUTLINE"] = true, ["MONOCHROME,THICKOUTLINE"] = true,
}
-- 不認得的（nil、舊存檔亂值）一律 OUTLINE（預設值）
function M.Outline(v)
    return M.OUTLINES[v] and v or "OUTLINE"
end
-- 沒有條層設定的面板（資源條、自訂格子、施法條）跟主題的描邊
function M.ThemeOutline()
    return M.Outline(ns.Setting(nil, "outline"))
end

-- 套字型：fs, size, flags（"OUTLINE" 等）, token
function M.SetFont(fs, size, flags, token)
    fs:SetFont(M.Font(token), size or 12, flags or "")
end

-- 疊在圖示／長條上的小字：字級先乘 UIParent 縮放、區域本身忽略父層縮放 →
-- 字形直接落在實體像素格上。小字級不這樣做會糊成一團。
function M.SetPixelFont(fs, size, flags, token)
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    fs:SetFont(M.Font(token), (size or 12) * scale, flags or "")
    if fs.SetIgnoreParentScale then fs:SetIgnoreParentScale(true) end
end

-- 邊框實際佔掉的厚度（版面單位）。
-- ⚠ 內容內縮一定要用這個、不能直接用設定裡的像素數：backdrop 的 edgeSize 走 P.Pixel
-- （把 N 個實體像素換算回版面單位），UI 縮放 ≠ 1 時兩者不相等，邊框內緣與內容外緣
-- 會露出一圈次像素縫。
function M.BorderInset(size)
    size = size or 1
    if size <= 0 then return 0 end
    return ns.P.Pixel(size)
end

-- 關掉引擎的像素貼齊（SetSnapToPixelGrid／SetTexelSnappingBias）。
-- 貼齊開著時，引擎在畫的那一刻把**每張貼圖自己的**頂點各自四捨五入到最近的實體像素；1px 的邊、格距、圖示
-- 只要四捨五入的方向跟隔壁那張不一樣，就變 0px（缺邊）／2px，或圖示跟邊框差一格。
-- 2026-10-16 回報：UI 縮放 0.64／預設高 36 缺邊、0.71／高 35 偏移、高 34 正常，而 /mcdm px 每條邊都在整數像素上
-- —— 稽核量的是框的幾何，引擎最後怎麼畫它看不到。Ayije_CDM／ElvUI／Cell 都是這一招。
-- 自己畫的細線、邊框、圖示貼圖一律過這支；StatusBar 傳進來就關它的填充貼圖。
-- 同一張只做一次（弱鍵表，不寫暴雪貼圖的欄位）；暴雪的貼圖可能受限，pcall 包住、失敗下次再試。
local noSnapDone = setmetatable({}, { __mode = "k" })
local function NoSnapRaw(t)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
end
function ns.NoSnap(tex)
    if type(tex) ~= "table" then return tex end
    local t = tex
    if not t.SetSnapToPixelGrid and t.GetStatusBarTexture then t = t:GetStatusBarTexture() end
    if type(t) == "table" and t.SetSnapToPixelGrid and not noSnapDone[t] and pcall(NoSnapRaw, t) then
        noSnapDone[t] = true
    end
    return tex
end
M.NoSnap = ns.NoSnap

-- BackdropTemplate 的九張貼圖（SetBackdrop 之後才存在）一起關。自己 SetBackdrop 帶 edgeSize 的框，套完叫一次
local BACKDROP_PIECES = {
    "Center", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
}
function ns.NoSnapBackdrop(frame)
    if type(frame) ~= "table" then return frame end
    for _, k in ipairs(BACKDROP_PIECES) do ns.NoSnap(frame[k]) end
    return frame
end

-- 邊框材質 token → 路徑；"solid"（或查不到）回 nil ＝ 用四條純色細條畫
-- （LibSharedMedia 的 border 類是 backdrop 的 edgeFile，要走 backdrop 畫，見 Decorate）
function M.Border(token)
    if not token or token == "solid" then return nil end
    local lsm = LSM()
    if lsm then
        local ok, path = pcall(lsm.Fetch, lsm, "border", token, true)
        if ok and path then return path end
    end
    return nil
end

-- LibSharedMedia 某一類的名稱清單（排序好）。拿不到 LSM 回空表。
-- 設定頁的下拉要做成函式、開頁那一刻才求值：別的插件可能比我們晚註冊材質。
function M.List(kind)
    local lsm = LSM()
    local out = {}
    if not lsm then return out end
    local ok, list = pcall(lsm.List, lsm, kind)
    if ok and type(list) == "table" then
        for _, name in ipairs(list) do
            if type(name) == "string" then out[#out + 1] = name end
        end
    end
    table.sort(out)
    return out
end
