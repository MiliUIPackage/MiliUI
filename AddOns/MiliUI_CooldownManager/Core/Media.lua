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

-- 動畫材質（2026-11-04 彩虹、11-06 宇宙星辰／閃電／熔岩／火焰；玩家問「施法條能不能多點皮膚」）。
-- 貼圖全部是腳本算的、不帶別人的檔：彩虹是技能 miliui-cdm-rainbow-texture、其餘四款是 miliui-cdm-castbar-fx。
--   tex     靜態那張：當 StatusBar 填充（進度前進時逐段露出），也是登記進 LSM 的那張 ⇒ 本插件所有長條的材質下拉都選得到
--   layers  施法條效果層的畫法（Modules/Castbar.lua「效果層」；玩家施法條與專注目標施法條都做，後者借 ns.Castbar.Fx），由下往上：
--     kind = "scroll"  整條寬、REPEAT 平鋪，貼圖座標動畫橫向捲，period 秒捲完一輪（貼圖兩端要接得起來）；
--                      blend（預設一般混色，"ADD" ＝ 黑底貼圖加亮）、alpha、twinkle = { lo, period }（alpha 在 lo～原值之間來回）
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
}
M.FX_ORDER = { "MiliUI Rainbow", "MiliUI Rainbow Soft", "MiliUI Cosmos", "MiliUI Lightning", "MiliUI Lava", "MiliUI Flame" }

-- 這支自己帶檔的材質：登記名 → 存檔值（這支存的就是登記名）。材質下拉拿它餵 ns.MiliMedia.TextureItems 的 always：
-- LSM 清單裡沒有（新檔還沒重開遊戲）也照列。顯示名與順序在 Libs/MiliUIMedia.lua 的名冊，新材質兩邊都要加
M.OWN_TEXTURES = { [M.BAR_TEXTURE_NAME] = M.BAR_TEXTURE_NAME }
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
    for _, name in ipairs(M.FX_ORDER) do
        pcall(lsm.Register, lsm, "statusbar", name, M.FX[name].tex)
    end
end
M.RegisterSharedMedia()

-- 材質 token → 路徑（statusbar 類）
function M.Texture(token)
    if not token or token == "solid" then return M.WHITE8X8 end
    if token == M.BAR_TEXTURE_NAME then return M.BAR_TEXTURE end
    if M.FX[token] then return M.FX[token].tex end
    local lsm = LSM()
    if lsm then
        local ok, path = pcall(lsm.Fetch, lsm, "statusbar", token, true)
        if ok and path then return path end
    end
    return M.WHITE8X8
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
