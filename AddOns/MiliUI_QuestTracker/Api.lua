------------------------------------------------------------
-- 對外入口：/mquest 指令、插件選單按鈕、米利UI選單那一筆
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIQuestTracker_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "questtracker",
    text    = L["MiliUI Quest Tracker"],
    icon    = "Interface\\Icons\\INV_Misc_Book_09",
    order   = 85,
    OnClick = function() ns.OpenOptions() end,
}

SLASH_MILIUIQUEST1 = "/mquest"
SLASH_MILIUIQUEST2 = "/miliuiquest"
SlashCmdList.MILIUIQUEST = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "fold" or msg == "toggle" then
        ns.Visibility.ToggleManualFold()

    elseif msg == "reset" then
        ns.DB.ResetAll()
        ns.Print(L["Restored the default settings."])

    elseif msg == "trace" then
        ns.AutoQuest.trace = not ns.AutoQuest.trace
        ns.AutoQuest.SetMessageCapture(ns.AutoQuest.trace)
        ns.Print(ns.AutoQuest.trace
            and "|cff88ccff" .. L["Quest automation trace ON — reproduce the problem, then paste the lines here."] .. "|r"
            or L["Quest automation trace off."])

    elseif msg:match("^slow") then
        -- 學到的「要先等一下」清單。清空是為了能重測 —— 同一條任務學會之後就不會
        -- 再失敗，不清就再也量不到了
        local db = ns.db.slowQuests
        if msg:match("clear") then
            wipe(db)
            ns.Print(L["Cleared the learned quest delays."])
        else
            local rows = {}
            for id, delay in pairs(db) do
                -- 清單在載入時就正規化成秒數了，這裡不再 `or 0` ——
                -- 那種寫法會把「值壞掉」顯示成「0.00 秒」，反而掩蓋問題
                rows[#rows + 1] = ("%d=%.2fs"):format(id, delay)
            end
            table.sort(rows)
            ns.Print(L["Quests that need a wait: %s"]
                :format(#rows > 0 and table.concat(rows, "  ") or "—"))
        end

    elseif msg:match("^delay") then
        -- 診斷用：把接受任務前的等待拉長，就能在插件動手之前自己手動點一次。
        -- session 內有效、不存檔
        local secs = tonumber(msg:match("^delay%s+([%d%.]+)$"))
        if secs and secs >= 0 and secs <= 10 then
            ns.AutoQuest.acceptDelay = secs
            ns.Print(L["Accept delay set to %.2fs (this session only)."]:format(secs))
        else
            ns.Print(L["Usage: /mquest delay <seconds 0-10>"]
                .. "  (" .. ("%.2f"):format(ns.AutoQuest.acceptDelay) .. ")")
        end

    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION
            .. "  folded=" .. tostring(ns.Visibility.IsFolded())
            .. "  protected=" .. tostring(ns.Tracker.OTF() and ns.Tracker.OTF():IsProtected()))
        for _, line in ipairs(ns.Chrome.Diagnose()) do print("  " .. line) end
        local conflict = ns.AutoQuest.LeatrixConflict()
        if conflict then
            print("  Leatrix Plus: accept=" .. tostring(conflict.accept)
                .. " turnIn=" .. tostring(conflict.turnIn))
        end
        if #ns.errors == 0 then
            print("  " .. L["No errors recorded"])
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end

    else
        ns.OpenOptions()
    end
end
