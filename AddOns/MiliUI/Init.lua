------------------------------------------------------------
-- MiliUI 本體命名空間骨架
--
-- 本體歷來全走全域 MiliUI.*（Style / Menu / Version）——那些照舊；
-- 這裡補的是自製設定視窗（MiliUIWidgets）需要的 addon 私有表 ns：
-- 語系表、版本號、錯誤收集、視窗位置存取。
------------------------------------------------------------
local ADDON, ns = ...

-- 永恆版（WoW Forever，遊戲型別 camelot）：WOW_PROJECT_CAMELOT 只在永恆載入時才定義，
-- 正式服是 nil。詳見 .claude/notes/wow-forever-vs-retail-api.md
ns.IS_FOREVER = (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
    or (WOW_PROJECT_FOREVER ~= nil and WOW_PROJECT_ID == WOW_PROJECT_FOREVER) or false

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

-- 套組金色（標題用）；聊天訊息前綴沿用本體既有的綠色
ns.PREFIX_COLOR = "|cffffe00a"

-- 本體介面全部直接寫繁中，語系表只補共用層（Widgets/Controls）要查的那四個 key，
-- 其餘 key 原樣返回 —— 這樣共用層照契約查 L 也不會炸
ns.L = setmetatable({
    ["Apply"]  = "套用",
    ["Okay"]   = "確定",
    ["Cancel"] = "取消",
    ["Can't change settings during combat"] = "戰鬥中無法調整設定",
}, { __index = function(_, k) return k end })

function ns.Print(...)
    print("|cff00ff00[MiliUI]|r", ...)
end

-- Midnight 12.1：首領戰進行中／M+ 計時中／PvP 戰場中會封鎖插件通訊。
--
-- 任何 SendAddonMessage 之前都要先問這個，不要去賭受限時是回傳失敗碼還是直接報錯。
-- 判斷本身抄自 Cell `Comm/Comm.lua` 的同名函式（它匯出成 `F.IsCommRestricted()`）。
--
-- 放 Init.lua 而不是各 Enhance 檔各寫一份：這條規則是 12.1 才長出來的，之後很可能
-- 再加情境（2026-08-28 體檢時發現 Enhance/PartyKeystone.lua 就是漏掉的那一份）。
-- ⚠ Init.lua 在 TOC 排在所有 Enhance 之前，所以那些檔在**檔案層**就抓得到它。
-- 跨插件的那幾份（MiliUI_CharacterNotes/Modules/Comm.lua、MiliUI_Focus/Modules/Sync.lua）
-- 是各自獨立發佈的插件，不能依賴這裡，維持自己那一份。
function ns.IsCommRestricted()
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    if C_MythicPlus and C_MythicPlus.IsRunActive and C_MythicPlus.IsRunActive() then return true end
    if C_PvP and C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield() then return true end
    return false
end

-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua（TOC 排在本檔之前）
--
--   ns.ReportError  xpcall 的訊息處理器：Callbacks 與設定視窗的逐項隔離不能變成黑洞——
--                   記進 ns.errors 供 /miliui debug 印出，同時照常轉給全域 errorhandler
--                   （BugSack 有裝就進 BugSack）。三道守衛（防遞迴、err 本身可能是秘密字串、
--                   下游 handler 包 pcall）；原本這裡自己寫的那份是裸的 tostring(err)，
--                   呼叫堆疊上有秘密值時處理器自己會炸。
--   封鎖動作攔截    ADDON_ACTION_FORBIDDEN／BLOCKED 不是 Lua error、pcall 攔不住，
--                   但事件會點名是哪個函式；一律記進 ns.errors（/miliui debug 看得到）。
--                   ⚠ 聊天框只在除錯模式（/miliui debug on）才印：本體掛勾的暴雪與第三方框
--                   比其他自製插件多，平常印出來對玩家只是雜訊。同一個函式名只有一次
--                   印的機會 —— 平常被擋過的，開除錯模式後（那會重載）才會再印。
ns.Errors.Install(function(line)
    local dm = ns.DebugMode   -- Enhance/DebugMode.lua，載入順序在後面，事件進來時才查
    if not (dm and dm.IsActive()) then return end
    ns.Print("|cffff5555" .. line .. "|r")
end)

-- 設定視窗位置。舊 DB 沒有這一格，所以每次都自己補、不假設結構存在
function ns.WindowPos()
    if not MiliUI_DB then MiliUI_DB = {} end
    if type(MiliUI_DB.optionsWindow) ~= "table" then
        MiliUI_DB.optionsWindow = { x = 0, y = 0 }
    end
    return MiliUI_DB.optionsWindow
end
