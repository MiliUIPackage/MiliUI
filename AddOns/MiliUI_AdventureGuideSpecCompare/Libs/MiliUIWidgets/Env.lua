------------------------------------------------------------
-- 宿主接點 —— 這一包裡**唯一**要跟著插件改的檔案
--
-- 同資料夾的 Widgets.lua / ContextMenu.lua / PixelPerfect.lua 一律只認 ns.WidgetsEnv，
-- 複製到別的插件時一個字都不用動；重寫的只有這支。完整說明見 README.md。
-- 原始 source 在 MiliUI/Libs/MiliUIWidgets/（套組本體），改共用層請改那邊再同步過來。
--
-- 這支插件只帶三個模組（PixelPerfect／Widgets／ContextMenu）：它沒有設定視窗，
-- 共用層只拿來畫「米利UI」樣式的差異面板與開關鈕（AGSCDB.style = "miliui"）。
--
-- ⚠ 契約：下面全部欄位都要有，缺一個會在載入時炸。
------------------------------------------------------------
local _, ns = ...

ns.WidgetsEnv = {}
local Env = ns.WidgetsEnv

-- 全域命名前綴。⚠ 每個插件必須不同（CreateFont/具名 frame 撞名會互相蓋掉）
Env.NAMESPACE = "MiliUIAGSC"

-- 這支插件沒有語系系統（字串直接寫 zhTW），共用層只查這四個 key
Env.L = {
    ["Apply"]  = "套用",
    ["Okay"]   = "確定",
    ["Cancel"] = "取消",
    ["Can't change settings during combat"] = "戰鬥中無法變更設定",
}

Env.P = ns.P

-- 在地化字型：寫死 FRIZQT__ 在 zhTW / zhCN / koKR 會變成方框
local LOCALE_FONTS = {
    zhTW = "Fonts\\blei00d.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    koKR = "Fonts\\2002.TTF",
}
local DEFAULT_FONT = LOCALE_FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF"

function Env.Font()
    return DEFAULT_FONT
end

-- 強調色 = 玩家職業色（Widgets.lua 在檔案層就讀一次）
local ar, ag, ab = 0.7, 0.7, 0.7
do
    local _, cls = UnitClass("player")
    local secret = issecretvalue and cls and issecretvalue(cls)
    if cls and not secret and cls ~= "" then
        local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[cls]) or RAID_CLASS_COLORS[cls]
        if c then ar, ag, ab = c.r, c.g, c.b end
    end
end
function Env.Accent()
    return ar, ag, ab
end

-- 這支沒有用到確認彈窗；真的用到就掛在差異面板上
function Env.PopupParent()
    return _G.AGSCPanel or UIParent
end
