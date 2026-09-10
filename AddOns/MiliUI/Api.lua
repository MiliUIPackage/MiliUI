------------------------------------------------------------
-- 對外入口：/miliui 指令、米利UI選單的「套組本體」項目
------------------------------------------------------------
local _, ns = ...

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 跨插件入口：MiliUI_InfoBar 的 CPU／記憶體方塊點擊直達效能監控的對應子分頁
-- （sub = "cpu"／"ram"）。走全域不走相依宣告——那支插件沒裝本體也要能載入。
--
-- ⚠ 不直接在呼叫者的堆疊裡開窗，先經過一個**本體自己建的**中繼框、下一幀再開。
--   官方分析器的記帳是「誰建的框／計時器，之後它的 OnUpdate、callback 都算誰的」：
--   如果效能分頁的 frame 是在資訊列的點擊裡第一次建出來的，分頁每 5 秒那一下
--   UpdateAddOnMemoryUsage（全堆掃描，~90 毫秒）從此整場都記在資訊列頭上
--   （2026-09-06 實測：資訊列自己的 Lua 是 0.0 毫秒，官方卻每 5 秒算它 90 毫秒）。
--   中繼框在本體載入時建好，它的 OnUpdate 是本體的堆疊，在裡面建的東西才歸本體。
MiliUI = MiliUI or {}
local perfRelay = CreateFrame("Frame")
perfRelay:Hide()
perfRelay:SetScript("OnUpdate", function(self)
    self:Hide()
    local sub = self.pendingSub
    self.pendingSub = nil
    ns.OpenPerfPage(sub)
end)
function MiliUI.OpenPerf(sub)
    perfRelay.pendingSub = sub
    perfRelay:Show()
end

-- 刻意不往 MiliUI_MenuEntries 塞「套組」項目：ESC 那顆「米利UI設定」按鈕
-- 點下去開的就是本體設定，選單裡再列一次是重複入口。

SLASH_MILIUIPACK1 = "/miliui"
SLASH_MILIUIPACK2 = "/mili"
SlashCmdList.MILIUIPACK = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "perf" or msg == "cpu" then
        ns.OpenOptions("perf")
    elseif msg == "lag" or msg:match("^lag%s") then
        ns.LagWatch.Command(msg:match("^lag%s*(.*)$"))
    elseif msg == "heap" or msg == "mem" then
        ns.HeapTrack.Report()
    elseif msg == "taint" or msg:match("^taint%s") then
        ns.TaintLog.Command(msg:match("^taint%s*(.*)$"))
    elseif msg == "check" then
        -- 逐筆報告「開啟設定」會走哪條路：指令有沒有真的註冊、分類找不找得到。
        -- 插件的指令壞掉（例如呼叫舊版 OpenToCategory）從外面看不出來，
        -- 這裡至少能分辨「解析不到」與「解析到了但那支自己沒反應」。
        ns.Print("插件設定入口檢查：")
        for _, entry in ipairs(ns.AddonRoster.entries) do
            local bits = {}
            if entry.slash then
                local found = ns.FindSlashHandler(entry.slash:match("^%S+"))
                bits[#bits + 1] = (found and "|cff33ff66指令 " or "|cffff5555指令✗ ") .. entry.slash .. "|r"
            end
            if entry.menuKey then bits[#bits + 1] = "選單 " .. entry.menuKey end
            local cat = ns.FindEntryCategory and ns.FindEntryCategory(entry)
            if cat then bits[#bits + 1] = "|cff33ff66分類|r" end
            local ok = ns.ResolveEntryOpen and ns.ResolveEntryOpen(entry)
            print(("  %s%s|r  %s"):format(ok and "|cff33ff66" or "|cffff5555", entry.key,
                #bits > 0 and table.concat(bits, "  ") or "|cff808080沒有定義入口|r"))
        end
    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION)
        if #ns.errors == 0 then
            print("  沒有記錄到錯誤")
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end
    else
        ns.OpenOptions()
    end
end
