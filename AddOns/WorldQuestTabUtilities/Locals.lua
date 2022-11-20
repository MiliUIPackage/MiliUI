local addonName, addon = ...

local L = {}
local locale = GetLocale();

L["IS_AZIAN_CLIENT"]	= false

L["TALLIES"] = "Tallies"
L["UTILITY_SETTINGS"] = "Utility Settings"
L["DIRECTION_LINE"] = "Direction line"
L["DIRECTION_LINE_TT"] = "Add a line to the map showing the direction your charater is facing."
L["WHATS_NEW"] = "What's New (Utils)";
L["WHATS_NEW_TT"] = "View World Quest Tab Utilities patch notes."
L["REWARD_GRAPH"] = "Reward Graph"
L["REWARD_GRAPH_TT"] = "View a 14 day graph of rewards obtained through world quests."

L["BOTH_FACTIONS"] = "Both Factions"
L["ACCOUNT"] = "Account"
L["REALM"] = "Realm"


if locale == "zhCN" then
L["IS_AZIAN_CLIENT"]	= true
end

if locale == "zhTW" then
L["IS_AZIAN_CLIENT"]	= true

L["TALLIES"] = "數量統計"
L["UTILITY_SETTINGS"] = "小工具設定"
L["DIRECTION_LINE"] = "方向指示線"
L["DIRECTION_LINE_TT"] = "在地圖上加入一條直線，顯示角色面向的方向。"
L["WHATS_NEW"] = "更新資訊 (小工具)";
L["WHATS_NEW_TT"] = "觀看世界任務標籤頁小工具的改版內容。"
L["REWARD_GRAPH"] = "獎勵圖表"
L["REWARD_GRAPH_TT"] = "觀看 14 天內透過世界任務獲得獎勵的圖表。"

L["BOTH_FACTIONS"] = "雙方陣營"
L["ACCOUNT"] = "帳號"
L["REALM"] = "伺服器"
end

addon.L = L;