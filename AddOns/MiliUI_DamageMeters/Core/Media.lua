------------------------------------------------------------
-- 媒體：在地化字型、長條材質、職業色
--
-- 零資產檔：材質只用暴雪內建的 WHITE8X8，字型走暴雪內建路徑，圖示用暴雪的
-- 專精 fileID 與職業 sprite。有裝 LibSharedMedia 就多開放玩家自己的字型／材質。
------------------------------------------------------------
local _, ns = ...

ns.Media = {}
local M = ns.Media

M.WHITE8X8 = "Interface\\Buttons\\WHITE8X8"

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
function M.Font(token)
    if not token or token == "default" or token == "DEFAULT" then return DEFAULT_FONT end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("font", token, true)
        if path then return path end
    end
    return DEFAULT_FONT
end

------------------------------------------------------------
-- 內建材質：檔案自己帶、註冊也自己做（做法與 MiliUI_UnitFrames 一致）
--
-- tuktex 是套組共用的預設長條材質，跟頭像框架用的是同一個檔（md5 相同）。
-- **自己帶一份而不是指到 MiliUI_UnitFrames 的路徑**：這些插件是單體發佈的，
-- 玩家可能只裝這一支，指過去就會是一條空白的條。
--
-- 解析順序一律「先查自己的表、查不到才問 LSM」：token 若只存在於 LSM，
-- 那個註冊它的插件一被移除或改名，這裡就會撲空。
------------------------------------------------------------
local MEDIA_PATH = "Interface\\AddOns\\MiliUI_DamageMeters\\Media\\"

M.TEXTURES = {
    tuktex = MEDIA_PATH .. "tuktex",
}
M.DEFAULT_TEXTURE = M.TEXTURES.tuktex

-- 登記到 LSM 用的顯示名。加前綴是因為 LSM **撞名會被拒絕**，而且失敗是靜默的。
-- 跟 MiliUI_UnitFrames 用同一個名字是刻意的：兩邊是同一張圖，共用一個條目
-- 才不會在別人的材質選單裡出現兩筆長得一樣的東西。誰先載入誰註冊成功，
-- 另一邊靜默失敗——但兩邊解析 token 都走自己的 M.TEXTURES，不受影響。
local LSM_NAME = "MiliUI TukTex"
M.LSM_NAME = LSM_NAME

local lsmDone = false
function M.RegisterSharedMedia()
    if lsmDone then return end
    local lsm = LSM()
    if not lsm then return end        -- 沒裝就算了，我們本來就不靠它
    lsmDone = true
    pcall(lsm.Register, lsm, "statusbar", LSM_NAME, M.TEXTURES.tuktex)
end
M.RegisterSharedMedia()               -- LSM 若比我們晚載入，登入時會再叫一次

-- token → 長條材質路徑
function M.BarTexture(token)
    if not token then return M.DEFAULT_TEXTURE end
    if token == "solid" then return M.WHITE8X8 end
    local own = M.TEXTURES[token]
    if own then return own end
    if token == LSM_NAME then return M.TEXTURES.tuktex end   -- 別人選了我們登記的名字
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("statusbar", token, true)
        if path then return path end
    end
    return M.DEFAULT_TEXTURE
end

------------------------------------------------------------
-- 設定面板的材質／字型清單
--
-- ⚠ 一定要是**函式**、不能是檔案層的常數表：LibSharedMedia 可能比我們晚載入，
-- 而且別的插件會一路註冊到 PLAYER_LOGIN 之後。開分頁那一刻才求值才列得全。
------------------------------------------------------------
-- 自己的材質永遠排第一（不靠 LSM 也要有東西可選）；LSM 的接在後面。
-- 跳過 LSM_NAME —— 那是我們自己登記出去的同一個檔，兩個名字指同一張圖只會讓人困惑。
function M.BarTextureItems()
    local items = {
        { text = ns.L["Built-in (TukTex)"], value = "tuktex" },
        { text = ns.L["Solid"],             value = "solid" },
    }
    local lsm = LSM()
    if lsm then
        local ok, list = pcall(lsm.List, lsm, "statusbar")
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                if name ~= LSM_NAME and not M.TEXTURES[name] then
                    items[#items + 1] = { text = name, value = name }
                end
            end
        end
    end
    return items
end

function M.FontItems()
    local items = { { text = ns.L["Default (localized)"], value = "default" } }
    local lsm = LSM()
    if lsm then
        local ok, list = pcall(lsm.List, lsm, "font")
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                items[#items + 1] = { text = name, value = name }
            end
        end
    end
    return items
end

------------------------------------------------------------
-- 職業色
--
-- ⚠ classFile 在 12.1 可能是秘密值。查表前一律先擋——
--   RAID_CLASS_COLORS[secret] 會丟 "cannot be indexed with secret keys"。
--   拿不到就回 nil，讓呼叫端自己決定退什麼色（不要在這裡偷偷退成盜賊黃）。
------------------------------------------------------------
local issecret = issecretvalue or function() return false end
M.IsSecret = issecret

function M.ClassColor(classFile)
    if not classFile or classFile == "" or issecret(classFile) then return nil end
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
        or RAID_CLASS_COLORS[classFile]
    if not c then return nil end
    return c.r, c.g, c.b
end

-- 玩家自己的職業色 = 這支插件的強調色（跟 MiliUIWidgets 的 Env.Accent 同一個來源）
local ar, ag, ab = 0.7, 0.7, 0.7
do
    local r, g, b = M.ClassColor(ns.playerClass)
    if r then ar, ag, ab = r, g, b end
end

function M.Accent()
    return ar, ag, ab
end

-- 自訂職業色插件（例如 Cell）在載入後會改 CUSTOM_CLASS_COLORS；重新取一次
-- 並通知各視窗重畫，玩家不必 /reload
function M.RefreshAccent()
    local r, g, b = M.ClassColor(ns.playerClass)
    if r then ar, ag, ab = r, g, b end
    ns.Fire("ColorsChanged")
end
