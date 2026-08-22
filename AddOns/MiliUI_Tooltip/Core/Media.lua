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
-- 血條材質：自帶 tuktex（跟 MiliUI_UnitFrames 同一張、同一套做法）
-- 解析先查自己的表、查不到才問 LSM；同時把自己的材質登記進 LSM，
-- 讓別的插件的材質選單也看得到。兩個方向都不依賴外人。
------------------------------------------------------------
local MEDIA_PATH = "Interface\\AddOns\\MiliUI_Tooltip\\Media\\"

M.TEXTURES = {
    tuktex = MEDIA_PATH .. "tuktex",
}

-- 登記到 LSM 的顯示名。⚠ LSM 撞名會被靜默拒絕——MiliUI_UnitFrames 也用這個名字
-- 登記同一張圖，誰先到誰贏，兩邊檔案相同所以無所謂；自己解析不走這個名字。
local LSM_NAME = "MiliUI TukTex"

local lsmDone = false
function M.RegisterSharedMedia()
    if lsmDone then return end
    local lsm = LSM()
    if not lsm then return end
    lsmDone = true
    pcall(lsm.Register, lsm, "statusbar", LSM_NAME, M.TEXTURES.tuktex)
end
M.RegisterSharedMedia()

function M.BarTexture(token)
    if type(token) ~= "string" or token == "" or token == "solid" then return M.WHITE8X8 end
    if M.TEXTURES[token] then return M.TEXTURES[token] end
    if token == LSM_NAME then return M.TEXTURES.tuktex end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch("statusbar", token, true)
        if path then return path end
    end
    return token
end

function M.BarTextureItems()
    M.RegisterSharedMedia()   -- LSM 若比我們晚載入，開選單時再補登一次
    local items = {
        { text = "MiliUI TukTex", value = "tuktex" },
        { text = L["Solid"], value = "solid" },
    }
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("statusbar")) do
            if name ~= LSM_NAME then
                items[#items + 1] = { text = name, value = name }
            end
        end
    end
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
