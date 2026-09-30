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

-- 材質 token → 路徑（statusbar 類）
function M.Texture(token)
    if not token or token == "solid" then return M.WHITE8X8 end
    local lsm = LSM()
    if lsm then
        local ok, path = pcall(lsm.Fetch, lsm, "statusbar", token, true)
        if ok and path then return path end
    end
    return M.WHITE8X8
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
-- ⚠ 內容內縮一定要用這個、不能直接用設定裡的像素數：backdrop 的 edgeSize 走 P.Scale
-- （把 N 個實體像素換算回版面單位），UI 縮放 ≠ 1 時兩者不相等，邊框內緣與內容外緣
-- 會露出一圈次像素縫。
function M.BorderInset(size)
    size = size or 1
    if size <= 0 then return 0 end
    return ns.P.Scale(size)
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
