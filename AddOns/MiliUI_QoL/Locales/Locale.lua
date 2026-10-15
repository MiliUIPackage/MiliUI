------------------------------------------------------------
-- 翻譯表
--
-- 跟套組本體同一個做法：介面字串直接寫繁中（這支的功能是從本體搬出來的，原本就是
-- 繁中寫死），語系表只補共用層（Libs/MiliUIWidgets）要查的那四個 key，
-- 其餘 key 原樣返回 —— 這樣共用層照契約查 L 也不會炸。
-- ⚠ 不要往這裡擴充 key：共用層的語系契約只有這四個。
------------------------------------------------------------
local _, ns = ...

local WIDGET_STRINGS = {
    zhTW = {
        ["Apply"]  = "套用",
        ["Okay"]   = "確定",
        ["Cancel"] = "取消",
        ["Can't change settings during combat"] = "戰鬥中無法調整設定",
    },
    zhCN = {
        ["Apply"]  = "应用",
        ["Okay"]   = "确定",
        ["Cancel"] = "取消",
        ["Can't change settings during combat"] = "战斗中无法调整设置",
    },
}

ns.L = setmetatable(WIDGET_STRINGS[GetLocale()] or {}, { __index = function(_, k) return k end })
