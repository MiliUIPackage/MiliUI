------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截（共用層）
--
-- 兩件每支插件都要、而且每支都寫過一次的事：
--
-- 1. **xpcall 的訊息處理器**。這個 repo 到處用 `xpcall(fn, ns.ReportError)` 做逐項
--    隔離（一個元件拋錯不能拖垮同迴圈的其他元件），但隔離不能變成黑洞 —— 錯誤要
--    記得下來（給 `/xxx debug` 看）也要照常轉給全域 errorhandler（進 BugSack）。
--
-- 2. **ADDON_ACTION_FORBIDDEN / BLOCKED 攔截**。那不是 Lua error、`pcall` 攔不住，
--    但事件會點名是哪個插件的哪個函式 —— taint 傳染第一時間就看得到兇手。
--
-- ⚠⚠ **處理器自己絕對不能拋錯。** 拋了的話錯誤會穿出 xpcall 的隔離，變成
--   「error in error handling」，比原本那個錯誤更難查。三道守衛缺一不可，
--   而且每一道都對應一個真的會發生的情況（見 MakeReporter 內的註解）。
--
--   2026-08-28 體檢時，套組裡 8 份 ReportError 只有 2 份有這三道守衛，其餘 6 份是
--   裸的 `tostring(err)` —— 而 `tostring(secret)` 是禁止操作，也就是說**那 6 支的
--   錯誤處理器在最需要它的時候（呼叫堆疊上有秘密值）自己會炸**。這包進共用層
--   主要就是為了這件事，不是為了省行數。
--
-- ⚠ 沒有相依（不讀 Env、不讀語系），排在 TOC 最前面那一區。
------------------------------------------------------------
local ADDON, ns = ...

ns.Errors = {}
local E = ns.Errors

local MAX = 10

------------------------------------------------------------
-- ns.Errors.MakeReporter(list) → reporter
--
-- list 是宿主自己的錯誤表（通常就是 ns.errors），只留最近 MAX 筆。
------------------------------------------------------------
function E.MakeReporter(list)
    local inReport = false
    local reporter

    reporter = function(err)
        -- (1) 防遞迴。有些插件會「包住前一個 handler 再呼叫」，錯誤有可能繞回這裡；
        --     沒有這道閘就是 stack overflow。代價是那一次的錯誤被丟掉，換一個 stack。
        if inReport then return end
        inReport = true

        -- (2) err 可能是**秘密字串**：只要呼叫堆疊上有秘密值參與，`debugstack()`
        --     就是秘密的，而 `tostring(secret)` 是禁止操作。
        local text
        if _G.issecretvalue and _G.issecretvalue(err) then
            text = "<secret error>"
        else
            local ok, str = pcall(tostring, err)
            text = ok and str or "<unprintable error>"
        end
        list[#list + 1] = text
        while #list > MAX do table.remove(list, 1) end

        -- (3) 下游的 handler 包 pcall：對方拋錯不能連坐。順便擋掉「handler 就是自己」
        --     （有插件把別人的 handler 抓去 seterrorhandler 就會這樣），那是無窮迴圈。
        local handler = geterrorhandler()
        if type(handler) == "function" and handler ~= reporter then
            pcall(handler, err)
        end

        inReport = false
    end

    return reporter
end

------------------------------------------------------------
-- ns.Errors.WatchForbidden(list, printer)
--
-- printer(line) 是宿主自己的印法（各插件的前綴色與名稱不同）。給 nil 就只記不印。
-- 同一個函式名只印一次 —— 這類事件常常是每幀一發，洗版會蓋掉真正有用的東西。
------------------------------------------------------------
function E.WatchForbidden(list, printer)
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
    local seen = {}
    watcher:SetScript("OnEvent", function(_, event, addonName, funcName)
        if addonName ~= ADDON then return end
        -- ⚠ 這裡連 `ns.trace` 一起印：ADDON_ACTION_FORBIDDEN 只會說是
        --   「Frame:RegisterEvent()」之類的函式名，不會說是哪個事件／哪個框。
        --   有留麵包屑的插件（單位框在註冊前會設 ns.trace）就指得出來。
        local line = ("%s: %s (combat=%s%s)"):format(
            event == "ADDON_ACTION_FORBIDDEN" and "FORBIDDEN" or "BLOCKED",
            tostring(funcName),
            tostring(InCombatLockdown() and true or false),
            ns.trace and (", " .. tostring(ns.trace)) or "")
        list[#list + 1] = line
        while #list > MAX do table.remove(list, 1) end
        local key = tostring(funcName)
        if not seen[key] and printer then
            seen[key] = true
            printer(line)
        end
    end)
    return watcher
end

------------------------------------------------------------
-- ns.Errors.Install(printer) → 一次做完最常見的那組
--
--   ns.errors        錯誤表
--   ns.ReportError   xpcall 的訊息處理器
--   ＋ 掛好封鎖動作攔截
--
-- 需要別的形狀（例如錯誤表要分兩份）就自己組 MakeReporter / WatchForbidden。
------------------------------------------------------------
function E.Install(printer)
    ns.errors = ns.errors or {}
    ns.ReportError = E.MakeReporter(ns.errors)
    E.WatchForbidden(ns.errors, printer)
    return ns.ReportError
end
