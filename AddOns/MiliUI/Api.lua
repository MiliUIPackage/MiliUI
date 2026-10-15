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

-- 跨插件入口：開本體設定視窗並切到指定分頁（tabId 省略＝預設頁）。
-- 給外掛分頁的插件用（MiliUI_QoL 的 /mqol、選單項目都走這裡開「便利功能」頁）。
-- 同樣走中繼框、下一幀再開，理由同上。分頁不存在就退回預設頁（Options.Open 處理）。
local openRelay = CreateFrame("Frame")
openRelay:Hide()
openRelay:SetScript("OnUpdate", function(self)
    self:Hide()
    local tabId = self.pendingTab
    self.pendingTab = nil
    ns.OpenOptions(tabId)
end)
function MiliUI.OpenOptions(tabId)
    openRelay.pendingTab = type(tabId) == "string" and tabId or nil
    openRelay:Show()
end

-- 跨插件入口：往本體設定視窗掛一個分頁（例：MiliUI_QoL 的「便利功能」）。
--
--   MiliUI.RegisterOptionsTab({
--       id = "qol", label = "便利功能", order = 20,
--       readOnly = false,                -- true 時戰鬥遮罩不蓋這一頁
--       build  = function(container, width) ... return refresh end,  -- 第一次切進來才呼叫
--       onShow = function() end,         -- 每次切進來
--       onHide = function() end,         -- 每次切走或關窗
--   })
--
-- container 是本體建的分頁框（錨在 banner 底下、蓋滿其餘的視窗），width 是視窗寬。
-- 標題與捲軸由呼叫端自己建，這樣它自己的獨立視窗跟這一頁長得一模一樣。
-- 回傳 true＝註冊成功；欄位不對或 id 已存在回傳 false。
-- 靜態分頁的 order：插件總覽 10、插件強化 30、效能監控 40、預設值匯入 50、關於 90。
function MiliUI.RegisterOptionsTab(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == ""
            or type(def.label) ~= "string" or type(def.build) ~= "function" then
        return false
    end
    if def.order ~= nil and type(def.order) ~= "number" then return false end
    return ns.Options.RegisterTab(def)
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
    elseif msg:match("^debug%s") then
        -- 除錯模式（Enhance/DebugMode.lua）：/miliui debug on|off
        ns.DebugMode.Command(msg:match("^debug%s*(.*)$"))
    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION)
        if #ns.errors == 0 then
            print("  沒有記錄到錯誤")
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end
        print("  |cff808080/miliui debug on：除錯模式（只留套組本體與 BugSack）；/miliui debug off：還原|r")
    else
        ns.OpenOptions()
    end
end
