local name, addon = ...

-- fix from MiliUI (中文化): 上游沒有語系檔，Core.lua／Tooltips.lua 的字串都是就地寫死的。
-- 這張表讓它們改走 L["英文原句"] 取字；沒翻的 key 退回原句，所以英文客戶端照舊。
-- 重套腳本：.claude/patches/TrueStatValues-zhTW.py
local L = setmetatable({}, { __index = function(_, key) return key end })
addon.L = L

if GetLocale() == "zhTW" then
    -- 設定面板
    L["True Stat Values"] = "真實屬性數值"
    L["Options"] = "選項"
    L["True Stat Value Settings"] = "真實屬性數值設定"
    L["Stat Tooltips"] = "屬性滑鼠提示"
    L["When checked, displays True Stat Rating information on Secondary-Stat tooltips."] = "勾選後，角色面板的次要屬性滑鼠提示會顯示扣除遞減後的真實數值、損失量，以及目前遞減區間的進度。"
    L["Item Tooltips"] = "物品滑鼠提示"
    L["When checked, displays True Stat Rating information on Item tooltips."] = "勾選後，物品滑鼠提示的屬性數值後面會標出扣除遞減後的實際增加量。"
    L["Font Color"] = "文字顏色"
    -- 滑鼠提示
    L["True Rating:"] = "真實數值："
    L["Lost Rating:"] = "遞減損失："
    L[" [%s penalty]"] = " [遞減 %s]"
end
