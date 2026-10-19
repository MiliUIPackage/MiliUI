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

local lsmDone = false
function M.RegisterSharedMedia()
    if lsmDone then return end
    local lsm = LSM()
    if not lsm then return end
    lsmDone = true
    pcall(lsm.Register, lsm, "statusbar", M.BAR_TEXTURE_NAME, M.BAR_TEXTURE)
end
M.RegisterSharedMedia()

-- 材質 token → 路徑（statusbar 類）
function M.Texture(token)
    if not token or token == "solid" then return M.WHITE8X8 end
    if token == M.BAR_TEXTURE_NAME then return M.BAR_TEXTURE end
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
