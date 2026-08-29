------------------------------------------------------------
-- 媒體：在地化字型、字型清單、強調色
--
-- 零資產檔：設定介面的字型走暴雪內建路徑，有裝 LibSharedMedia 就多開放玩家
-- 自己的字型給追蹤器文字用。
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

-- token → 字型路徑；nil / "default" = 在地化字型（設定介面自己的文字走這條）
--
-- 解出來的路徑記一份：追蹤器每次重排都會問一次。**只快取問到的**，問不到不記
-- —— 註冊那支字型的插件可能比我們晚載入，記了 nil 就永遠退成預設字型。
local fontCache = {}

function M.Font(token)
    if not token or token == "" or token == "default" or token == "DEFAULT" then
        return DEFAULT_FONT
    end
    local cached = fontCache[token]
    if cached then return cached end
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
-- 追蹤器文字用的字型解析
--
-- ⚠ 空值語意跟 M.Font 不一樣，不要共用：這裡的「空」是**沿用暴雪原本的字型**，
--   所以回 nil 讓呼叫端自己填，不能偷偷退成在地化預設字型。
--   追蹤器的每個 FontString 原本的字型不見得一樣（標題／目標／進度條各有各的），
--   退成同一個預設等於在玩家沒要求的情況下把版面全改掉。
------------------------------------------------------------
function M.OptionalFont(token)
    if not token or token == "" then return nil end
    if token:find("[\\/]") then return token end
    return M.Font(token)
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
    local items = { { text = ns.L["Use Blizzard's font"], value = "" } }
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
local issecret = ns.Secret.IsSecret

local ar, ag, ab = 0.7, 0.7, 0.7
do
    local cls = ns.playerClass
    if cls and cls ~= "" and not issecret(cls) then
        local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[cls]) or RAID_CLASS_COLORS[cls]
        if c then ar, ag, ab = c.r, c.g, c.b end
    end
end

function M.Accent()
    return ar, ag, ab
end
