------------------------------------------------------------
-- 媒體：在地化字型與強調色
--
-- 零資產檔：設定介面的字型走暴雪內建路徑。這支插件沒有任何「玩家自選字型」的
-- 設定（商品格的字是暴雪自己畫的），所以不必接 LibSharedMedia。
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

-- 共用層只會用無參數的形式；留著 token 參數是為了跟其他插件的 Env 契約同形
function M.Font(_token)
    return DEFAULT_FONT
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
