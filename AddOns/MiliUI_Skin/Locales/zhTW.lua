local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱與分頁
L["MiliUI Skin"] = "米利的介面外觀"
L["General"] = "一般"

-- 設定頁
L["Enable the skin"] = "啟用介面外觀"
L["Repaints Blizzard's windows in the MiliUI settings-window look."] = "把暴雪原生視窗重畫成米利UI的設定視窗皮：不透明灰底、1 像素純黑硬邊、白字、直角。"
L["This addon only repaints. It never moves, resizes or rebuilds anything Blizzard owns."] = "這支插件只重畫，不會搬動、縮放或重組任何暴雪自己的東西。"
L["Windows"] = "視窗"
L["Changes take effect after a UI reload."] = "變更需要重新載入介面才會生效。"
L["Changes take effect after a UI reload. Reload now?"] = "變更需要重新載入介面才會生效。現在重新載入嗎？"
L["Reload UI"] = "重新載入介面"
L["Show status"] = "列出套用狀態"

-- 視窗名稱（用暴雪官方詞彙）
L["Gossip"] = "對話"
L["Character Info"] = "角色資訊"
L["Achievements"] = "成就"

-- 暴雪「選項 > 插件」入口頁
L["Use /mskin to open options"] = "使用 /mskin 開啟設定"
L["Version: %s"] = "版本: %s"
L["Open options"] = "開啟設定"

-- /mskin debug 的狀態
L["Applied"] = "已套用"
L["Waiting for the Blizzard addon to load"] = "等待暴雪插件載入"
L["Waiting to leave combat"] = "等待脫離戰鬥"
L["Disabled"] = "已停用"
L["Error"] = "出錯"
L["Not applied yet"] = "尚未套用"
L["Regions neutralized:"] = "已中和的區域:"
L["Overlays:"] = "已建立的覆蓋層:"
L["Regions not found (Blizzard may have renamed them):"] = "找不到的區域（暴雪可能改名了）:"
L["Skipped because the frame is protected:"] = "因為是保護框而跳過:"
L["Skipped because the object is forbidden:"] = "因為物件被禁止存取而跳過:"
L["No errors recorded"] = "沒有記錄到錯誤"
