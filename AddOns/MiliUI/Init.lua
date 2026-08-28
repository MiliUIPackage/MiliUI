------------------------------------------------------------
-- MiliUI 本體命名空間骨架
--
-- 本體歷來全走全域 MiliUI.*（Style / Menu / Version）——那些照舊；
-- 這裡補的是自製設定視窗（MiliUIWidgets）需要的 addon 私有表 ns：
-- 語系表、版本號、錯誤收集、視窗位置存取。
------------------------------------------------------------
local ADDON, ns = ...

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

-- 錯誤收集：Callbacks 的 xpcall 隔離不能變成黑洞——記下最近的錯誤，
-- 同時照常轉給全域 errorhandler（BugSack 有裝就進 BugSack）
ns.errors = {}
function ns.ReportError(err)
    tinsert(ns.errors, tostring(err))
    if #ns.errors > 10 then tremove(ns.errors, 1) end
    local handler = geterrorhandler()
    if handler then handler(err) end
end

-- 設定視窗位置。舊 DB 沒有這一格，所以每次都自己補、不假設結構存在
function ns.WindowPos()
    if not MiliUI_DB then MiliUI_DB = {} end
    if type(MiliUI_DB.optionsWindow) ~= "table" then
        MiliUI_DB.optionsWindow = { x = 0, y = 0 }
    end
    return MiliUI_DB.optionsWindow
end
